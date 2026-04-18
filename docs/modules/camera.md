# Camera Module

The camera module handles multi-exposure stacking photography. It manages AVFoundation sessions, exposes a rich interactive control system, and coordinates the capture sequence.

## Components

```
Domains/Capture/
├── Presentation/
│   ├── CameraView.swift
│   ├── CameraViewModel.swift
│   ├── CameraControlsView.swift
│   ├── CameraSettingsView.swift
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
    
    // Advanced settings (UI state, not yet wired to AVFoundation)
    @Published var aperture: String             // e.g. "f/1.8"
    @Published var shutterSpeed: String         // e.g. "1/60"
    @Published var zoomLevel: String            // e.g. "1×"
    @Published var shootingMode: String         // "A" | "M" | "P" | "S"
}
```

### Capture Sequence

```
CameraViewModel.startStackingCapture()
    → StartCaptureSequenceUseCase.execute(settings:)
        → CameraDeviceRepository.capturePhoto()
        → updates captureProgress
        → sleeps intervalBetweenShots
    → PersistSessionUseCase.execute()
```

### Known Limitations

Advanced settings (aperture, shutter, zoom, mode) update `@Published` state but are not yet wired to `AVCaptureDevice`. They represent UI placeholders for future integration.

## AdvancedControlsMenu

The main camera control bar. Lives at the bottom of the camera view. Supports drag-to-expand for secondary controls.

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

Settings sheet (presented via `.sheet`). Contains:

- **曝光 (Exposure)** — Slider for exposure duration
- **堆栈 (Stacking)** — Shot count stepper + interval slider
- **总览 (Summary)** — Total capture time + frame count

Summary section uses `breathingGlow` on key numbers.

## CameraView

Root view. Layers:

```
ZStack
├── CameraPreviewView (AVCaptureVideoPreviewLayer)
├── Gradient overlay (top dark + bottom dark)
└── VStack
    ├── Spacer
    └── CameraControlsView
        ├── captureProgressView (when capturing)
        ├── AdvancedControlsMenu
        └── Picker overlays (ZStack)
```

Navigation title: "堆栈拍摄"

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
    → viewModel.exposureTime = newValue
    
User taps confirm/dismiss
    → viewModel.showExposurePicker = false
    → WheelPickerOverlay disappears
```

## Picker Option Sets

```swift
exposureOptions: [Double]   = [0.1, 0.2, ..., 1.0, 2.0, ..., 30.0]
shotsOptions: [Int]          = [2, 3, ..., 100]
apertureOptions: [String]    = ["f/1.4", "f/1.8", "f/2.0", ..., "f/22"]
shutterOptions: [String]     = ["1/8000", ..., "1/60", ..., "30\""]
zoomOptions: [String]        = ["0.5×", "1×", "2×", "3×", "5×", "10×"]
modeOptions: [String]        = ["A", "M", "P", "S"]
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

Completed capture sequences now overwrite the app's recent stacking project with a new capture-origin `Light` frame set. The library tab restores that project and can continue with registration, comet review, stacking, and export using the same `StackingProject` model.

Relevant code:

- `Domains/Capture/Presentation/CameraViewModel.swift`
- `Domains/Stacking/Application/ReplaceRecentStackProjectWithCapturedFramesUseCase.swift`
- `Domains/Library/Presentation/LibraryStackingViewModel.swift`
