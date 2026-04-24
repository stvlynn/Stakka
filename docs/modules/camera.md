# Camera Module

The camera module handles multi-exposure stacking photography. It manages AVFoundation sessions, exposes a rich interactive control system, and coordinates the capture sequence.

## Components

```
Domains/Capture/
├── Presentation/
│   ├── CameraView.swift
│   ├── CameraViewModel.swift
│   ├── CameraControlsView.swift
│   ├── CameraSettingsView.swift     # in-preview settings panel
│   └── Components/
│       ├── AdvancedControlsMenu.swift
│       └── WheelPickerView.swift
├── Application/
│   ├── PrepareCameraSessionUseCase.swift
│   ├── StartCaptureSequenceUseCase.swift
│   └── StopCaptureSequenceUseCase.swift
├── Domain/
│   └── CaptureTypes.swift
└── Infrastructure/
    └── AVFoundation/
        ├── AVCaptureSessionRepository.swift
        └── CameraPermissionService.swift
```

## CameraViewModel

The single source of truth for all camera state.

```swift
@MainActor
class CameraViewModel: ObservableObject {
    // Session
    @Published var captureSession: AVCaptureSession
    
    // Capture state
    @Published var isCapturing: Bool
    @Published var captureProgress: Double      // 0.0 - 1.0
    @Published var capturedImages: [UIImage]
    @Published var liveStackedImage: UIImage?
    @Published var liveStackedFrameCount: Int
    @Published var liveRejectedFrameCount: Int
    @Published var liveStackedExposure: Double
    @Published var liveStackingPhase: LiveStackingPhase
    
    // Primary settings
    @Published var exposureTime: Double         // 0.1 - 30.0 seconds
    @Published var numberOfShots: Int           // 2 - 100
    @Published var intervalBetweenShots: Double // 0.0 - 10.0 seconds
    
    // Picker visibility state
    @Published var showExposurePicker: Bool
    @Published var showShotsPicker: Bool
    @Published var showAperturePicker: Bool
    @Published var showShutterPicker: Bool
    @Published var showZoomPicker: Bool
    @Published var showModePicker: Bool
    
    // Advanced settings
    @Published var astroMode: AstroCaptureMode  // Milky Way | Star Trails | Moon | Meteor
    @Published var aperture: String             // e.g. "f/1.8"
    @Published var shutterSpeed: String         // e.g. "1/60"
    @Published var zoomLevel: String            // e.g. "1×"
    @Published var shootingMode: String         // "A" | "M" | "P" | "S"
}
```

### Capture Sequence

```
CameraViewModel.startStackingCapture()
    → LiveStackingProcessor.reset(configuration:)
    → starts an AsyncStream live-frame consumer
    → StartCaptureSequenceUseCase.execute(settings:)
        → CameraDeviceRepository.capturePhoto(settings:)
        → AVCaptureSessionRepository applies zoom + custom exposure where supported
        → emits CaptureFrame into the live-frame stream without awaiting stacking
        → updates liveStackedImage / frame counts / exposure
        → updates captureProgress
        → sleeps intervalBetweenShots
    → live-frame consumer drains LiveStackingProcessor.addFrame(...)
    → ReplaceRecentStackProjectWithCapturedFramesUseCase.execute(project:)
    → PersistSessionUseCase.execute()
```

`CaptureFrame.exposureDuration` stores the actual exposure duration returned from the repository. Live-stack exposure totals are summed from accepted frame durations, falling back to the requested preset duration only when a frame lacks device timing.

### Device Control Coverage

`AVCaptureSessionRepository.capturePhoto(settings:)` applies:

- custom exposure duration from `shutterSpeed` or `exposureTime`, clamped to the active device range
- zoom factor from `zoomLevel`, clamped to the active device range
- still capture through the configured `AVCapturePhotoOutput`

`aperture` and `shootingMode` remain preset/readout state because iPhone aperture is hardware-defined and AVFoundation does not expose DSLR-style A/M/P/S mode switching.

## CameraControlsView

The bottom camera deck. It combines a star-mode selector with the existing drag-to-expand capture control menu.

### Star Mode Selector

The screenshot-inspired film rail is implemented as astrophotography presets:

| Mode | UI label | Preset intent | Live stack strategy |
|---|---|---|---|
| `milkyWay` | 银河 / Milky Way | Wide-field stack, 15s frames | `deepSky` + registration + kappa-sigma |
| `starTrails` | 星轨 / Star Trails | Long sequence, 30s frames | fixed tripod + maximum blend |
| `moon` | 月亮 / Moon | Short exposure, 1/125-style shutter | `lunar` + registration + median kappa |
| `meteor` | 流星 / Meteor | Fast cadence, 20s frames | fixed tripod + maximum blend |

Selecting a mode calls `CameraViewModel.applyAstroMode(_:)`, updating exposure, shot count, interval, aperture, shutter, zoom, shooting mode UI state, and the `LiveStackingStrategy` used for the capture session. Supported AVFoundation device controls are applied during still capture.

The presets are implementation-backed:

- Milky Way uses 15s frames, registered deep-sky live stacking, and a `kappaSigma` saved project.
- Star Trails uses 30s frames, fixed-tripod live stacking, and `maximum` blending so bright traces accumulate.
- Moon uses a `1/125` shutter, registered lunar live stacking, and `medianKappaSigma`.
- Meteor uses 20s frames, fixed-tripod live stacking, and `maximum` blending for transient bright streaks.

## AdvancedControlsMenu

The capture control menu lives below the star mode selector. It supports drag-to-expand for secondary controls.

### Primary Level (always visible)

```
┌─────────────────────────────────────────────┐
│  ────────                                   │  ← drag indicator
│  [1.5]    [●]    [10]                       │
│   ⏱️      ✨      📷                         │  ← tap to open wheel pickers
└─────────────────────────────────────────────┘
```

- Left button: Exposure time → opens `WheelPickerOverlay` with 0.1-30s options
- Center button: Capture / Stop
- Right button: Shot count → opens `WheelPickerOverlay` with 2-100 options

### Secondary Level (drag up to expand)

```
┌─────────────────────────────────────────────┐
│  ────────                                   │
│  [📷 光圈] [⏱️ 快门]                         │  ← tap each to open picker
│  [🔍 倍数] [🎛️ 档位]                        │
│  ──────────────────────────                 │
│  [1.5]    [●]    [10]                       │
│   ⏱️      ✨      📷                         │
└─────────────────────────────────────────────┘
```

Drag threshold: 50pt vertical movement triggers expand/collapse.

### Drag Gesture

```swift
DragGesture().onEnded { value in
    if value.translation.height < -50 {
        isExpanded = true   // drag up
    } else if value.translation.height > 50 {
        isExpanded = false  // drag down
    }
}
```

## WheelPickerView

Generic reusable overlay. Takes any `Hashable` type.

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

### Layout

```
┌─────────────────────────┐
│                         │  ← tap to dismiss
│  ┌───────────────────┐  │
│  │  曝光时间    [×]  │  │
│  │  ──────────────── │  │
│  │    0.9s           │  │
│  │  ► 1.0s           │  │  ← selected
│  │    1.1s           │  │
│  │  ──────────────── │  │
│  │  [     确认     ] │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

Presented using `ZStack` overlay within `CameraControlsView`. Transition: `.move(edge: .bottom).combined(with: .opacity)`.

## CameraSettingsView

Settings panel (presented inside the camera preview, not as a sheet). The panel follows the screenshot-style dark overlay with a compact header and close action. Contains:

- **预设 (Preset)** — Milky Way / Star Trails / Moon / Meteor rows
- **Readouts** — exposure, shot count, interval, and zoom
- **Interval stepper** — icon-only plus/minus controls for timing tweaks

No traditional sliders are used. Detailed numeric changes still use wheel pickers or icon steppers.

## CameraView

Root view. Layers:

```
ZStack
├── Space background
└── VStack
    ├── CameraTopBarView (PRO pill, live status, settings button)
    ├── CameraPreviewView (framed AVCaptureVideoPreviewLayer)
    │   ├── CameraHUDView
    │   ├── Live stack preview card
    │   └── CameraSettingsPanelView (when open)
    └── CameraControlsView
        ├── AstroModeSelectorView
        ├── captureProgressView (when capturing)
        ├── AdvancedControlsMenu
        └── WheelPickerOverlay layers
```

The navigation bar is hidden for the camera tab so the in-view chrome can match the Dynamic Island-style reference.

## Data Flow

```
User tap (exposure button)
    → AdvancedControlsMenu.controlButton(action:)
    → withAnimation(AnimationPreset.springBouncy)
    → viewModel.showExposurePicker = true
    → WheelPickerOverlay appears
    
User scrolls wheel
    → onChange(selectedIndex)
    → onSelect(items[newValue])
    → viewModel.updateExposureTime(newValue)
    
User taps confirm/dismiss
    → viewModel.showExposurePicker = false
    → WheelPickerOverlay disappears

User taps star mode
    → AstroModeSelectorView.Button
    → CameraViewModel.applyAstroMode(mode)
    → preset values update
    → HUD, settings panel, and capture settings refresh from @Published state

User starts capture
    → CameraViewModel.startStackingCapture()
    → LiveStackingProcessor.reset(configuration: mode-specific strategy)
    → StartCaptureSequenceUseCase emits each CaptureFrame through onFrameCaptured
    → ImageLiveStackingSession analyzes/registers/stacks the frame
    → CameraView displays the latest LiveStackingSnapshot
    → completed live project is saved as the recent library stacking project
```

## Picker Option Sets

```swift
exposureOptions: [Double]   = [0.1, 0.2, ..., 1.0, 2.0, ..., 30.0]
shotsOptions: [Int]          = [2, 3, ..., 100]
apertureOptions: [String]    = ["f/1.4", "f/1.8", "f/2.0", ..., "f/22"]
shutterOptions: [String]     = ["1/8000", ..., "1/60", ..., "30\""]
zoomOptions: [String]        = ["0.5×", "1×", "2×", "3×", "5×", "10×"]
modeOptions: [String]        = ["A", "M", "P", "S"]
astroModes: [AstroCaptureMode] = [.milkyWay, .starTrails, .moon, .meteor]
```

## Adding a New Control

1. Add `@Published` property + `showXxxPicker: Bool` to `CameraViewModel`
2. Add `WheelPickerOverlay` to `CameraControlsView`
3. Add option array to `CameraControlsView`
4. Add `advancedControlButton` entry in `AdvancedControlsMenu.advancedControls`
5. Wire to ViewModel property

## Future Work

- Wire aperture, shutter, zoom to AVFoundation `AVCaptureDevice`
- Implement ISO control
- Add direct navigation from capture completion into the project review flow
- Histogram display during capture
- Focus peaking overlay

## Current Integration

Completed capture sequences now overwrite the app's recent stacking project with the live-built capture project. The library tab restores that project and can continue with registration, comet review, stacking, and export using the same `StackingProject` model.

Relevant code:

- `Domains/Capture/Presentation/CameraViewModel.swift`
- `Domains/Stacking/Infrastructure/CoreImage/ImageLiveStackingSession.swift`
- `Domains/Stacking/Application/ReplaceRecentStackProjectWithCapturedFramesUseCase.swift`
- `Domains/Library/Presentation/LibraryStackingViewModel.swift`
