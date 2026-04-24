# Image Stacking Module

The stacking module is a DSS-inspired pipeline shared by the library workflow and the camera live-stack workflow:

1. `analyze` — compute frame metrics and choose a reference frame
2. `register` — estimate per-frame offsets against the reference frame
3. `stack` — calibrate, align, and combine enabled light frames
4. `live` — accept camera frames one at a time and render an incremental preview

## Files

```
Domains/Stacking/
├── Application/
│   ├── AnalyzeStackProjectUseCase.swift
│   ├── RegisterStackProjectUseCase.swift
│   └── RunStackingUseCase.swift
├── Domain/
│   └── StackingTypes.swift
└── Infrastructure/
    └── CoreImage/
        ├── ImageStacker.swift
        └── ImageLiveStackingSession.swift
```

## Public Interface

```swift
protocol StackingProcessor {
    func analyze(_ project: StackingProject) async throws -> StackingProject
    func register(_ project: StackingProject) async throws -> StackingProject
    func stack(_ project: StackingProject) async throws -> StackingResult
}

protocol LiveStackingProcessor {
    func reset(configuration: LiveStackingConfiguration) async
    func addFrame(
        image: UIImage,
        name: String,
        source: StackFrameSource,
        capturedAt: Date,
        exposureDuration: Double
    ) async -> LiveStackingSnapshot
    func currentProject() async -> StackingProject?
}
```

The domain now models:

- `StackFrameKind`
- `StackFrame`
- `StackingProject`
- `FrameAnalysis`
- `FrameRegistration`
- `StackingMode`
- `StackingRecap`
- `LiveStackingStrategy`
- `LiveStackingConfiguration`
- `LiveStackingSnapshot`

## Analysis

`ImageStacker.analyze(_:)` computes lightweight astronomy-oriented heuristics per frame:

- star count
- background level
- approximate FWHM
- frame score

If the user has not chosen a reference frame, the highest-scoring enabled `Light` frame becomes the project reference.

## Registration

Registration uses Apple Vision image registration APIs. Phase 1 attempts homographic registration first and falls back to translational alignment when Vision cannot resolve a stable homography. Registration is stored as a projective transform with method and confidence.

The output of registration is fed back into the project model so the UI can display offsets before stacking.

## Comet Stacking

The stacking module now supports three DSS-style comet modes:

- `standard` — stars frozen, comet trails
- `cometOnly` — comet frozen, stars trail
- `cometAndStars` — comet and stars both frozen

Comet mode is driven by `StackingProject.cometMode` and per-frame `CometAnnotation` data. Registration writes star alignment as before, then an additional comet-alignment pass shifts the already star-aligned buffers into a comet reference frame.

Automatic comet estimation runs after registration for enabled `Light` frames when comet mode is enabled. It:

1. warps each frame into the star-aligned reference grid
2. builds a median background field
3. extracts moving bright residuals
4. estimates one comet point per frame with confidence
5. interpolates weak/missing detections and flags low-confidence frames for review

The final `cometAndStars` result is produced by blending the comet-frozen composite back over the star-frozen composite in a local comet region.

## Calibration

Stacking supports the following calibration chain:

- master bias from enabled `Bias` frames
- master dark from enabled `Dark` frames, bias-calibrated when possible
- master dark flat from enabled `Dark Flat` frames
- normalized master flat from enabled `Flat` frames

Enabled `Light` frames are calibrated in this order:

```text
light
  - bias
  - dark
  / normalized flat
```

## Stacking Modes

Available light-frame combine modes:

- `average`
- `median`
- `kappaSigma`
- `medianKappaSigma`
- `maximum`

Manual library project creation exposes the first four modes. `maximum` is reserved for camera-origin star-trail and meteor projects, or for opening a project that already uses that mode.

Calibration masters are averaged in this phase even if the light-frame mode is different.

`maximum` mirrors DSS's maximum accumulator and keeps the brightest value per pixel. It is used by star-trail and meteor live capture so bright traces survive the final project stack.

## Live Stacking

`ImageLiveStackingSession` adapts the project stacker for capture-time use. It receives each `CaptureFrame` as soon as AVFoundation returns it, analyzes the frame, optionally registers it against the current reference, rejects unstable frames, and updates a downsampled incremental preview accumulator.

Camera modes map to stacking strategies:

| Camera mode | Strategy | Registration | Project mode |
|---|---|---|---|
| Milky Way | `deepSky` | Vision homography/translation | `kappaSigma` |
| Star Trails | `starTrails` | fixed tripod identity | `maximum` |
| Moon | `lunar` | Vision homography/translation | `medianKappaSigma` |
| Meteor | `meteor` | fixed tripod identity | `maximum` |

The live session remains async/await and actor-isolated. It returns `LiveStackingSnapshot` values so the camera UI can show accepted frames, rejected frames, total exposure, phase, and the latest preview. The camera view model queues frames through an `AsyncStream`, so capture cadence is not blocked by registration or preview work.

Live preview is intentionally lightweight:

- frames are downsampled to a bounded preview size
- registered modes warp the new frame into the reference preview grid
- `maximum` updates a per-pixel bright accumulator for star trails and meteors
- other modes use an incremental running average for preview responsiveness

The saved `StackingProject` still contains the accepted frames and mode-specific registrations. Final library stacking uses the full project pipeline and the exact selected combine mode rather than the lightweight preview accumulator.

## Implementation Notes

- `ImageStacker` remains actor-isolated
- `ImageLiveStackingSession` is actor-isolated and composes the shared stacker
- image buffers are converted into linear RGBA floats
- imported images are normalized and downscaled before processing
- aligned frames are warped into the reference frame grid before combining
- live camera frames are saved as a normal `StackingProject` so the library can continue analysis, registration, stacking, and export
- live snapshots sum actual accepted frame exposure durations when camera hardware reports them

## Current Constraints

- no RAW/FITS decode yet
- no calibrated/registered intermediate export yet
- live stacking currently uses camera-delivered `UIImage` frames; RAW sensor frames are not wired yet
- no background calibration, channel alignment, or cosmetic correction yet

## Test Priorities

- analysis returns stable metrics for known fixtures
- reference frame auto-selection is deterministic
- registration returns zero offset for the reference frame
- calibration chain behaves correctly with missing optional groups
- all five stacking modes return a valid image for matching light frames
- TIFF export data is generated for the final stack result
- all three comet modes return a valid image when comet annotations are present
- live sessions emit snapshots, reject unstable registered frames, and preserve strategy-specific project modes
