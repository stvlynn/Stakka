# Camera Module

The camera module handles multi-exposure stacking photography. It manages AVFoundation sessions, exposes a rich interactive control system, and coordinates the capture sequence.

## Surface Treatment

Every chrome surface on the camera page — cards, pills, buttons,
panels — is rendered through the project's Liquid Glass helpers
(`.liquidGlass(...)`, `.liquidGlassCard(...)`, `.liquidGlassPill(...)`),
which delegate to the native iOS 26 `glassEffect(_:in:)` API.

Active states pass a `tint:` argument so selected controls (e.g. an
active inline picker button) pick up the accent color (`cosmicBlue`)
on the rim and reflection. Tappable surfaces pass
`isInteractive: true` so the system applies its dynamic light response
on touch.

Three regions on the page wrap their adjacent glass surfaces in a
single `GlassEffectContainer` so the surfaces share a sampling region:

1. **Top bar** — `PRO` badge, `LIVE` status pill, settings button.
2. **Idle bottom stack** — mode selector card (with its inner title
   pill) + the inline horizontal wheel + the drawer card and all the
   control buttons inside it.
3. **Settings panel** — the panel surface + the preset mode rows,
   readout grid, and interval stepper card inside it.

See `docs/modules/design-system.md` for the helper API and
`Glass`-level configuration.

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
│       ├── CameraCaptureButton.swift  # shared capture/stop disc + ring
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
    
    // Inline horizontal wheel state — only one parameter is editable at a
    // time. `nil` means the wheel is collapsed and the live preview is
    // unobstructed.
    @Published var activeInlineControl: CameraInlineControl?
    
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

The bottom camera deck. The default presentation is intentionally
minimal — only the drawer with the primary capture controls is shown,
keeping the live preview as the focus while the user composes the
shot. Dragging the drawer up reveals two extra layers stacked above
it: the `AstroModeSelectorView` (preset rail) and the drawer's own
secondary advanced control buttons. Both fade and slide in together
under `AnimationPreset.springBouncy`. Releasing into the collapsed
state hides the selector again.

### Star Mode Selector

The screenshot-inspired film rail is implemented as astrophotography
presets. It is **only visible when the drawer is expanded** — switching
astro mode is a deliberate, occasional action, not part of the framing
loop.

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
│   曝光时间                            1.5s   │  ← inline horizontal wheel
│   …  1.0  1.5  2.0  3.0 …                   │     (only when a control
│                │  ← center indicator         │      is activated)
├─────────────────────────────────────────────┤
│  ────────                                   │  ← drag indicator
│  [1.5]    [⏺ ring]    [10]                  │
│   ⏱️      5/24         📷                    │  ← tap toggles inline wheel
└─────────────────────────────────────────────┘
```

- Left button: Exposure time → toggles inline `HorizontalWheelPicker`
  with 0.1-30s options above the drawer
- Center button: `CameraCaptureButton`, see "CameraCaptureButton" below.
- Right button: Shot count → toggles inline wheel with 2-100 options

### Secondary Level (drag up to expand)

```
┌─────────────────────────────────────────────┐
│   光圈                              f/1.8   │  ← inline wheel switches
│   …  f/1.8  f/2.0  f/2.8 …                  │     to whichever advanced
│                │                             │     control is active
├─────────────────────────────────────────────┤
│  ────────                                   │
│  [📷 光圈] [⏱️ 快门]                         │  ← tap toggles inline wheel
│  [🔍 倍数] [🎛️ 档位]                        │     for that control
│  ──────────────────────────                 │
│  [1.5]    [⏺]    [10]                       │
│   ⏱️       ✨     📷                         │
└─────────────────────────────────────────────┘
```

Drag threshold: 50pt vertical movement triggers expand/collapse.

A single `activeInlineControl` enum drives the wheel — tapping the same
button toggles it off; tapping a different control switches focus
without an extra dismiss step. The full-screen modal `WheelPickerOverlay`
has been retired in favor of this in-place editing model.

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

## CameraCaptureButton

Shared disc-shaped capture / stop button used in two places:

- **Inline** at the center of the `AdvancedControlsMenu` while idle,
  acting as the primary CTA.
- **Floating** as the only on-screen control while a capture sequence is
  running, so the live preview reads fullscreen.

Visual states:

| State      | Inner glyph                                                          | Outer ring                                                 |
| ---------- | -------------------------------------------------------------------- | ---------------------------------------------------------- |
| Idle       | `sparkles` icon over an `auroraGreen → ctaAccent` gradient disc     | Static `ctaAccent` stroke with a soft glow                 |
| Capturing  | Rounded stop square + monospaced `current/total` caption             | `starWhite` track + animated `cosmicBlue` progress arc     |

Tapping the button calls `viewModel.startStackingCapture()` or
`viewModel.stopStackingCapture()` depending on the current state. The
button shrinks slightly while capturing (`scaleEffect(0.92)`) and fires
a selection haptic on every transition.

## HorizontalWheelPicker

Generic in-place editor that snaps the closest item to a center
indicator. Lives directly above the controls drawer so the live
preview is never occluded.

```swift
HorizontalWheelPicker(
    title: "曝光时间",
    items: exposureOptions,
    selection: viewModel.exposureTime,
    displayText: { "\(String(format: "%.1f", $0))s" },
    valueText: { L10nFormat.exposure($0) },
    onSelect: { viewModel.updateExposureTime($0) },
    onDismiss: { viewModel.dismissInlineControl() }
)
```

### Layout

```
┌──────────────────────────────────────────┐
│  曝光时间                          1.5s    │  ← title + active value
│                                          │
│   …   1.0   1.5   2.0   3.0   …          │  ← horizontal wheel
│                  │                        │  ← center indicator
└──────────────────────────────────────────┘
```

Implementation notes:

- Uses iOS 17 `scrollPosition(id:)` + `scrollTargetBehavior(.viewAligned)`
  for momentum + snap.
- `contentMargins(.horizontal, sideInset, for: .scrollContent)` centers
  the first/last item.
- A symmetric `LinearGradient` mask fades the edges so the wheel reads
  as a continuous strip.
- Per-item `visualEffect` fades and scales items based on their
  distance from the scroll-view center for a continuous-rotation feel.
- `sensoryFeedback(.selection, trigger: scrollPositionID)` fires a
  light haptic on each snap.

`Item` only needs to conform to `Hashable`; the value itself is used
as the SwiftUI identity for snapping.

## CameraSettingsView

Settings panel (presented inside the camera preview, not as a sheet). The panel follows the screenshot-style dark overlay with a compact header and close action. Contains:

- **预设 (Preset)** — Milky Way / Star Trails / Moon / Meteor rows
- **Readouts** — exposure, shot count, interval, and zoom
- **Interval stepper** — icon-only plus/minus controls for timing tweaks

No traditional sliders are used. Detailed numeric changes still use wheel pickers or icon steppers.

## CameraView

Root view. Layers (from bottom to top):

```
ZStack
├── Space background
├── CameraPreviewView (edge-to-edge AVCaptureVideoPreviewLayer with a
│       top↘bottom darkening gradient overlay so chrome stays legible)
├── Overlay chrome (top bar + HUD/settings panel + bottom feedback)
└── CameraControlsView
    ├── Idle state
    │   ├── AstroModeSelectorView          ← only when the drawer is
    │   │                                    expanded (drag-up reveal)
    │   └── AdvancedControlsMenu
    │       ├── HorizontalWheelPicker (when activeInlineControl != nil)
    │       └── menu card (drag-to-expand drawer + CameraCaptureButton)
    └── Capturing state
        └── Floating CameraCaptureButton (stop square + progress ring),
            no drawer, no mode selector
```

`CameraPreviewView` is always rendered fullscreen with `.ignoresSafeArea()`
so the live preview reads as the canvas. The differences between idle
and capturing modes are entirely in the overlay layer:

| Surface              | Idle                                                                 | Capturing                                                |
| -------------------- | -------------------------------------------------------------------- | -------------------------------------------------------- |
| Top bar              | PRO pill + live status pill + settings button                        | Hidden (slides up + fades out)                           |
| HUD strip            | Aperture · shutter · ISO · zoom (or settings panel when toggled)     | Same HUD; settings panel is suppressed                   |
| Live stack card      | Shown only when a previous stack snapshot exists                     | Always shown above the floating capture button          |
| Bottom controls deck | Drawer + inline `CameraCaptureButton`. Astro mode cards reveal only when the drawer is dragged up. | Replaced by a floating `CameraCaptureButton` only        |
| Bottom safe area pad | `318 pt` reserves space for the deck                                 | `132 pt` lets the preview run almost edge-to-edge        |

The navigation bar is hidden for the camera tab so the in-view chrome
can match the Dynamic Island-style reference. State changes between
idle and capturing animate with `AnimationPreset.smooth`.

## Data Flow

```
User tap (exposure button)
    → AdvancedControlsMenu.toggle(.exposure)
    → withAnimation(AnimationPreset.springBouncy)
    → viewModel.toggleInlineControl(.exposure)
    → activeInlineControl flips to .exposure (or nil if already active)
    → HorizontalWheelPicker mounts above the drawer

User drags / taps an item on the wheel
    → scrollPositionID snaps to the closest item
    → onChange(scrollPositionID) calls viewModel.updateExposureTime(...)
    → CameraHUDView, advancedControlButton readouts, and the
      preset code chip refresh from @Published state

User taps the same control again, or the wheel’s × button
    → viewModel.dismissInlineControl()
    → activeInlineControl = nil
    → wheel transitions out

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

1. Add a `@Published` property to `CameraViewModel` for the new value.
2. Add a case to the `CameraInlineControl` enum at the bottom of
   `CameraViewModel.swift`.
3. Add the option array as a `static let` in the
   `extension AdvancedControlsMenu` at the bottom of
   `AdvancedControlsMenu.swift`.
4. Add a `case` in `AdvancedControlsMenu.wheel(for:)` that mounts a
   `HorizontalWheelPicker` bound to the new property.
5. Add a `controlButton` (primary row) or `advancedControlButton`
   (secondary row) entry that calls `toggle(.<yourCase>)`.
6. Wire the value into any HUD readouts or the device repository.

The capture/stop button itself does not need to change — both the
inline drawer composition and the fullscreen capture composition share
`CameraCaptureButton`.

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
