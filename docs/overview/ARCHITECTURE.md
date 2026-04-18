# Architecture

## Project Identity

Stakka is an iOS astrophotography application designed for stargazing enthusiasts. It combines three core capabilities:

1. **Light pollution mapping** — Find dark sky locations
2. **Multi-exposure capture** — Automated stacking photography
3. **Library stacking** — Process existing photos

The app follows 灵动美学 (Dynamic Island aesthetic) — minimal text, continuous curves, breathing animations, and icon-first interactions.

## Design Philosophy

### 1. Minimal Text, Maximum Clarity

Users are astronomy enthusiasts, not beginners. The UI assumes familiarity with photography concepts (aperture, shutter speed, ISO).

**Good:**
```
[1.5]  [●]  [10]
 ⏱️     ✨   📷
```

**Bad:**
```
Exposure Time: 1.5 seconds
Capture Button
Number of Shots: 10
```

### 2. Continuous Corners Everywhere

All UI elements use continuous corner radii (iOS 13+ style) for visual consistency.

```swift
// Always
.continuousCorners(CornerRadius.lg)

// Never
.cornerRadius(16)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

### 3. Wheel Pickers Over Sliders

Camera controls use iOS-native wheel pickers (like Clock app) instead of sliders. This provides:
- Precise value selection
- Familiar iOS interaction pattern
- Better accessibility
- Cleaner visual hierarchy

### 4. Async/Await Throughout

All long-running operations (capture, stacking, file I/O) use Swift concurrency:
- No completion handlers
- Structured concurrency with Task
- Actor isolation for image processing
- Progress reporting via @Published properties

## System Architecture

### Layer Separation

```
┌─────────────────────────────────────────────┐
│  App (StakkaApp, Root, Composition)         │
├─────────────────────────────────────────────┤
│  Domains/*/Presentation                     │
├─────────────────────────────────────────────┤
│  Domains/*/Application                      │
├─────────────────────────────────────────────┤
│  Domains/*/Domain                           │
├─────────────────────────────────────────────┤
│  Domains/*/Infrastructure + Platform/*      │
└─────────────────────────────────────────────┘
```

**App Layer**
- Tab navigation
- Dependency composition via `AppContainer`
- Dark mode enforcement

**Domain Layer**
- Business capabilities are grouped by domain: `DarkSky`, `Capture`, `Stacking`, `Library`, `Session`
- Each domain can contain `Presentation`, `Application`, `Domain`, and `Infrastructure`
- Shared business capabilities (for example stacking) are reused through use cases and protocols instead of direct feature-to-feature calls

**Platform Layer**
- Design system tokens and shared view modifiers
- Shared lightweight utility types
- Cross-domain support services

### Domain Module Pattern

Each business domain follows this shape:

```
Domains/{Domain}/
├── Presentation/                # SwiftUI views + view models
├── Application/                 # Use cases / orchestration
├── Domain/                      # Entities, value objects, protocols
└── Infrastructure/              # Framework adapters / platform IO
```

Presentation:
- `View` and `ViewModel`
- UI state and transitions
- No direct platform framework setup beyond rendering

Application:
- Coordinates domain operations
- Exposes task-oriented entry points such as `RunStackingUseCase`

Domain:
- Stable business models and protocols
- Avoids view concerns

Infrastructure:
- AVFoundation, CoreImage, PhotoKit, CoreLocation, MapKit integration
- Concrete implementations for domain protocols

## Directory Structure

```
Stakka/
├── App/
│   ├── StakkaApp.swift
│   ├── Root/
│   │   └── ContentView.swift        # Tab navigation
│   └── Composition/
│       └── AppContainer.swift       # Dependency wiring
│
├── Domains/
│   ├── Capture/                     # Camera session, capture flow
│   ├── DarkSky/                     # Map + light pollution
│   ├── Library/                     # Photo import/export
│   ├── Session/                     # Capture session persistence
│   └── Stacking/                    # Shared stacking pipeline
│
└── Platform/
    ├── DesignSystem/
    │   ├── DesignSystem.swift
    │   └── Extensions.swift
    └── SharedKernel/
        ├── AppError.swift
        └── ProgressValue.swift
```

## Core Subsystems

### 1. Camera Capture System

**Components:**
- `CameraViewModel` — AVFoundation session management
- `CameraView` — Preview layer + controls overlay
- `CameraControlsView` — Orchestrates pickers and menu
- `AdvancedControlsMenu` — Drag-to-expand advanced settings
- `WheelPickerView` — Generic wheel picker overlay

**Flow:**
1. User taps exposure/shots button → Wheel picker appears
2. User drags menu up → Advanced controls expand (aperture, shutter, zoom, mode)
3. User taps capture → Sequential capture begins
4. Progress updates via `@Published captureProgress`
5. Captured images stored in `capturedImages` array
6. Auto-stack on completion (future feature)

**Key Constraints:**
- Camera permission required (AVCaptureDevice.requestAccess)
- Capture session runs on background queue
- UI updates on main actor
- Exposure time: 0.1-30s
- Shot count: 2-100

### 2. Image Stacking Algorithm

**Implementation:**
- Actor-isolated for thread safety
- Mean stacking (pixel-wise RGB averaging)
- CoreImage + CoreGraphics pipeline
- Async/await for non-blocking execution

**Algorithm:**
```
For each pixel (x, y):
    R_out = mean(R_1, R_2, ..., R_n)
    G_out = mean(G_1, G_2, ..., G_n)
    B_out = mean(B_1, B_2, ..., B_n)
```

**Performance:**
- Processes images in batches
- Uses CGContext for pixel access
- Returns UIImage for display/save

### 3. Design System

**Tokens:**
- Colors: Space theme (deep blacks, cosmic blues, nebula purples)
- Typography: SF Pro with rounded variant for numbers
- Spacing: 4/8/16/24/32/48pt scale
- Corner radii: 6/10/16/20/28/36pt (continuous style)
- Animations: Spring/smooth/quick presets

**Key Modifiers:**
- `.continuousCorners(_:)` — Continuous corner radii
- `.glassCard()` — Frosted glass effect
- `.glow(color:radius:)` — Static glow
- `.breathingGlow(color:radius:)` — Animated glow

**Animation Presets:**
```swift
AnimationPreset.spring        // 0.4s, 75% damping
AnimationPreset.springBouncy  // 0.5s, 65% damping
AnimationPreset.smooth        // 0.35s ease in/out
AnimationPreset.quick         // 0.2s ease out
AnimationPreset.gentle        // 0.5s ease in/out
```

### 4. Light Pollution Map

**Components:**
- MapKit integration
- Location services
- Pollution level classification (9 levels)
- Interactive markers

**Data Source:**
- Mock data currently
- Future: Light Pollution Map API integration

## State Management

### ViewModel Pattern

All ViewModels follow this structure:

```swift
@MainActor
class FeatureViewModel: ObservableObject {
    // Published state
    @Published var property: Type = defaultValue
    
    // Private dependencies
    private let dependency: Dependency
    
    // Public commands
    func performAction() async {
        // Business logic
    }
}
```

### State Flow

```
User Interaction
    ↓
View calls ViewModel method
    ↓
ViewModel updates @Published properties
    ↓
SwiftUI re-renders affected views
```

No global state. No singletons. Each feature owns its state.

## Dependency Management

### Current: Zero Dependencies

Stakka uses only iOS system frameworks:
- SwiftUI
- AVFoundation
- MapKit
- PhotosUI
- CoreImage
- CoreGraphics

### Future Considerations

If adding dependencies:
- Use Swift Package Manager
- Prefer Apple frameworks over third-party
- Justify each dependency in PR description
- Keep dependency count minimal

## Testing Strategy

### Current State

Manual testing on simulator and device.

### Future Testing

- Unit tests for ImageStacker algorithm
- UI tests for camera capture flow
- Snapshot tests for design system components
- Performance tests for stacking large image sets

## Build System

### XcodeGen

Project file is generated from `project.yml`:

```bash
xcodegen generate
```

Benefits:
- No merge conflicts in .xcodeproj
- Declarative project structure
- Easy to review changes

### Build Configurations

- Debug: Development builds
- Release: App Store builds

## Performance Considerations

### Image Stacking

- Processes images asynchronously
- Uses actor isolation to prevent data races
- Memory-efficient (processes one pixel at a time)
- Scales to 100+ images

### Camera Capture

- AVFoundation session runs on background queue
- UI updates throttled to 60fps
- Preview layer uses hardware acceleration

### UI Rendering

- SwiftUI automatic optimization
- Lazy loading for image grids
- Continuous corner radii use Metal acceleration

## Security & Privacy

### Permissions Required

- Camera access (AVCaptureDevice)
- Photo library access (PhotosPicker)
- Location access (MapKit, optional)

### Data Storage

- No cloud storage
- All data local to device
- No analytics or tracking
- No third-party SDKs

## Localization

### Current State

UI text is minimal and primarily Chinese.

### Future Localization

- Extract strings to Localizable.strings
- Support English, Chinese (Simplified/Traditional)
- Use SF Symbols (language-agnostic)

## Accessibility

### Current State

- System font scaling supported
- VoiceOver labels on interactive elements
- High contrast colors (space theme)

### Future Improvements

- VoiceOver testing
- Dynamic Type support
- Reduce Motion support for animations

## Known Limitations

1. **Light pollution data** — Currently mock data, needs API integration
2. **Auto-stacking** — Camera captures images but doesn't auto-stack yet
3. **Export options** — Limited to saving to photo library
4. **Advanced camera controls** — Aperture/shutter/ISO are UI-only (not wired to AVFoundation)

## Future Architecture Considerations

### Potential Additions

1. **Core Data** — If adding saved locations or capture presets
2. **Combine** — If adding reactive data streams beyond @Published
3. **WidgetKit** — For home screen light pollution widget
4. **CloudKit** — For syncing favorite locations across devices

### Architectural Principles to Maintain

- Keep features independent
- Maintain zero third-party dependencies if possible
- Preserve async/await throughout
- Continue minimal text philosophy
- Maintain design system consistency

## References

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [AVFoundation Programming Guide](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/)
- [Light Pollution Map](https://github.com/cgettings/Light-Pollution-Map)
