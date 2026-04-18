# Stakka Agent Guide

This file serves as the unified entry point for AI coding agents working on this repository.

## 1. Project Identity

Stakka is an iOS astrophotography application combining light pollution mapping and image stacking for stargazing enthusiasts. Built with SwiftUI and modern iOS frameworks.

Core product constraints:

1. Design system follows 灵动美学 (Dynamic Island aesthetic) with continuous corner radii.
2. Camera controls use wheel pickers and expandable menus, not traditional sliders.
3. Text is minimal — icons and numbers preferred over verbose labels.
4. All stacking operations are async/await with progress tracking.

## 2. Code Structure

```text
Stakka/
├── App/                        # Application entry
│   ├── StakkaApp.swift         # App lifecycle
│   └── ContentView.swift       # Tab navigation
├── Features/
│   ├── Camera/                 # Stacking camera capture
│   │   ├── CameraView.swift
│   │   ├── CameraViewModel.swift
│   │   ├── CameraControlsView.swift
│   │   ├── CameraSettingsView.swift
│   │   └── Components/
│   │       ├── WheelPickerView.swift
│   │       └── AdvancedControlsMenu.swift
│   ├── LightPollution/         # Light pollution map
│   │   └── LightPollutionMapView.swift
│   └── Library/                # Photo library stacking
│       ├── LibraryStackingView.swift
│       └── LibraryStackingViewModel.swift
└── Core/
    ├── ImageStacking/          # Stacking algorithms
    │   └── ImageStacker.swift
    ├── Models/                 # Data models
    │   └── Models.swift
    └── Utilities/              # Design system & extensions
        ├── DesignSystem.swift
        └── Extensions.swift
```

Rules:

- New design tokens go in `Core/Utilities/DesignSystem.swift`.
- New camera controls go in `Features/Camera/Components/`.
- All UI uses continuous corner radii via `.continuousCorners()` modifier.
- Numbers use `.monospacedDigit()` for consistent width.

## 3. Working Approach

### 3.1 Read Before Changing

Before structural changes, read:

1. `docs/README.md`
2. `docs/overview/ARCHITECTURE.md`
3. `docs/development/WORKFLOW.md`
4. Relevant module docs in `docs/modules/`

### 3.2 Change Boundaries

- Design system changes: Update `DesignSystem.swift` + all consuming views.
- Camera controls: Sync ViewModel published properties + UI bindings + picker overlays.
- Image stacking: Changes must preserve async/await pattern and progress reporting.
- Never add verbose text labels where icons suffice (see 灵动美学 principle).

### 3.3 Quality Baseline

Any committable change must pass:

- Xcode build (⌘B)
- No SwiftLint warnings
- Manual UI testing on simulator

For camera features, test:
- Wheel picker interactions
- Advanced menu drag gestures
- Capture sequence with progress

## 4. Documentation Navigation

- Overview: `docs/overview/`
- Module docs: `docs/modules/`
- Development workflow: `docs/development/`

When adding new features:

- Update relevant module doc in `docs/modules/`
- Add architecture notes to `docs/overview/ARCHITECTURE.md` if introducing new patterns
- Keep README.md feature list in sync

## 5. Development Workflow

1. Generate Xcode project: `xcodegen generate`
2. Open in Xcode: `open Stakka.xcodeproj`
3. Build and run on simulator (⌘R)
4. Test camera features on physical device for accurate AVFoundation behavior

## 6. Prohibited Actions

- Don't add traditional sliders for camera controls (use wheel pickers).
- Don't add verbose text labels (use icons + numbers).
- Don't use standard corner radii (always use continuous style).
- Don't introduce synchronous blocking operations in stacking pipeline.
- Don't modify design system tokens without updating all consuming views.
- Don't add English UI text without considering Chinese localization needs.

## 7. Key Design Patterns

### Wheel Picker Pattern
```swift
WheelPickerOverlay(
    title: "曝光时间",
    items: exposureOptions,
    selectedItem: viewModel.exposureTime,
    displayText: { "\(String(format: "%.1f", $0))s" },
    onSelect: { viewModel.exposureTime = $0 },
    onDismiss: { viewModel.showExposurePicker = false }
)
```

### Continuous Corners
```swift
.continuousCorners(CornerRadius.lg)
// NOT: .cornerRadius() or .clipShape(RoundedRectangle())
```

### Animation Presets
```swift
withAnimation(AnimationPreset.springBouncy) { ... }
// NOT: withAnimation(.spring(...))
```

### Minimal Text
```swift
// Good
VStack {
    Text("1.5")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .monospacedDigit()
    Image(systemName: "timer")
}

// Bad
VStack {
    Text("Exposure Time")
    Text("1.5 seconds")
}
```

## 8. Testing Checklist

Before submitting changes:

- [ ] Build succeeds in Xcode
- [ ] No SwiftLint warnings
- [ ] Camera controls respond to taps
- [ ] Wheel pickers scroll smoothly
- [ ] Advanced menu expands/collapses on drag
- [ ] Capture sequence completes with progress
- [ ] Stacking produces valid output image
- [ ] All numbers use monospaced digits
- [ ] All corners use continuous style
- [ ] No verbose text labels added

## 9. Common Pitfalls

1. **Forgetting `.monospacedDigit()`** — Numbers will jump width during updates
2. **Using standard corner radii** — Breaks 灵动美学 consistency
3. **Adding text labels** — Violates minimal text principle
4. **Blocking main thread** — Stacking must be async
5. **Hardcoding animation curves** — Use `AnimationPreset` constants

## 10. Getting Help

- Architecture questions: See `docs/overview/ARCHITECTURE.md`
- Module-specific questions: See `docs/modules/{module-name}.md`
- Development setup: See `docs/development/WORKFLOW.md`
- Design system: See `docs/modules/design-system.md`
