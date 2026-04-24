# Library Stacking Module

The library stacking module is now a project-based workflow instead of a single-shot photo picker. Users build a stacking project with five frame groups, analyze the project, register enabled light frames, then run stacking.

## Files

```
Domains/Library/
├── Presentation/
│   ├── LibraryStackingView.swift
│   ├── LibraryStackingViewModel.swift
│   └── Components/
│       ├── StackProjectBrowserView.swift
│       ├── StackFrameSectionView.swift
│       ├── StackProjectSummaryCard.swift
│       ├── StackingModePickerView.swift
│       ├── ProcessingStatusCard.swift
│       └── StackedResultCard.swift
├── Application/
│   ├── ImportPhotosUseCase.swift
│   └── ExportStackedImageUseCase.swift
├── Domain/
│   └── PhotoLibraryRepository.swift
└── Infrastructure/
    └── PhotoKit/
        └── SystemPhotoLibraryRepository.swift
```

## Workflow

The module exposes a DSS-style sequence:

1. Create or open a stacking project
2. Import frames into `Light / Dark / Flat / Dark Flat / Bias` from Photos or Files
3. Pick a stacking mode
4. Run `分析`
5. Run `配准`
6. Run `堆栈`
7. Save the final image or export a TIFF file

The gallery creation wizard combines the first three steps for new projects. Its final action imports the selected frames, opens the created project, and starts the registration + stacking operation immediately.

The current iOS implementation supports Photos imports and file-based image imports. Each imported frame is normalized and downscaled for on-device processing. Projects are stored in a local project catalog and one project is marked as the current recent project.

Successful pipeline runs persist both the updated project state and `result.png` immediately, then refresh gallery summaries so the completed stack appears as a preview tile without waiting for the debounced autosave loop.

## View Model

`LibraryStackingViewModel` owns a single `StackingProject` plus transient UI state:

```swift
@Published private(set) var project: StackingProject
@Published private(set) var phase: ProcessingPhase
@Published private(set) var result: StackingResult?
@Published private(set) var errorMessage: String?
```

Important commands:

```swift
func importFrames(from items: [PhotosPickerItem], kind: StackFrameKind) async
func setReferenceFrame(_ frameID: UUID)
func analyze()
func register()
func stack()
func saveResult()
```

Any frame mutation invalidates cached analysis, registration, and the previous stack result.

## UI Structure

`LibraryStackingView` is a vertically stacked engineering surface:

- `StackProjectBrowserView` — open, duplicate, delete, or create projects
- `StackProjectSummaryCard` — project title, reference frame, enabled-frame counts
- `StackingModePickerView` — `average / median / kappaSigma / medianKappaSigma`, with `maximum` shown only when opening a project that already uses it
- `CometModePickerView` — off, standard, comet-only, comet+stars
- `CometReviewStatusCard` — comet review progress and review entry
- `ProcessingStatusCard` — active phase
- five `StackFrameSectionView` sections
- action panel for `分析 / 配准 / 堆栈`
- `StackedResultCard` — final image plus recap badges

Each frame section supports:

- importing additional images into that group
- importing file-based images into that group
- clearing the group
- toggling a frame enabled/disabled
- removing a frame
- marking a `Light` frame as the reference frame
- opening a `Light` frame directly in the comet-review flow when comet mode is enabled

## Comet Review Flow

When comet mode is enabled:

1. the user runs `配准`
2. the stacker auto-estimates one comet point per enabled `Light` frame
3. frames with low confidence are marked as needing review
4. the user opens the comet review sheet
5. the user taps on each frame to override the comet core position where needed

The review sheet supports:

- per-frame navigation
- zoom and pan on the current frame
- tap-to-place comet point
- restoring the automatically estimated point

Stacking is blocked while any enabled `Light` frame still requires comet review.

## Current Constraints

- Camera capture can overwrite the recent project with a live-stacked capture-origin light-frame project
- Camera-origin star-trail and meteor projects may use `maximum` stacking so bright traces survive final combine
- The file importer currently targets standard raster images and TIFF; RAW/FITS are not wired yet
- TIFF export covers the final stacked image only
- Intermediate calibrated/registered frame export is still missing

## Next Useful Extensions

- Add FITS import and RAW decode
- Export final TIFF and calibrated/registered intermediates
- Add batch project execution
