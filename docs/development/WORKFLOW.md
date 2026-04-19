# Development Workflow

## Prerequisites

- macOS 14+
- Xcode 15+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

## First-Time Setup

```bash
git clone https://github.com/stvlynn/Stakka.git
cd Stakka
xcodegen generate
open Stakka.xcodeproj
```

The `.xcodeproj` is generated. Regenerate it whenever `project.yml` or source layout changes.

## Daily Commands

### Regenerate Project

```bash
xcodegen generate
```

### Build

```bash
xcodebuild \
  -project Stakka.xcodeproj \
  -scheme Stakka \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

If that simulator is not installed, use any available iPhone simulator or a concrete simulator identifier.

### Run Tests

```bash
xcodebuild \
  -project Stakka.xcodeproj \
  -scheme StakkaTests \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  test
```

### Open in Xcode

```bash
open Stakka.xcodeproj
```

## Project Navigation

Current high-value entry points:

| Task | Start Here |
|---|---|
| App wiring | `App/Composition/AppContainer.swift` |
| Root tabs | `App/Root/ContentView.swift` |
| Library project workflow | `Domains/Library/Presentation/LibraryStackingView.swift` |
| Stacking project state | `Domains/Library/Presentation/LibraryStackingViewModel.swift` |
| Stacking core | `Domains/Stacking/Infrastructure/CoreImage/ImageStacker.swift` |
| Project persistence | `Domains/Stacking/Infrastructure/Storage/LocalStackProjectRepository.swift` |
| Camera capture | `Domains/Capture/Presentation/CameraViewModel.swift` |
| Light-pollution map | `Domains/DarkSky/Presentation/DarkSkyMapView.swift` |
| Design tokens | `Platform/DesignSystem/DesignSystem.swift` |
| Localization copy | `Platform/SharedKernel/L10n.swift` + `Stakka/zh-Hans.lproj/Localizable.strings` |

## Adding Files

1. Create the file under `Stakka/` or `StakkaTests/`
2. Run `xcodegen generate`
3. Rebuild

XcodeGen picks up files by directory inclusion. Missing files in Xcode usually mean the project was not regenerated.

For localization work:

- UI copy should route through `Platform/SharedKernel/L10n.swift`
- Locale-sensitive formatting should route through `Platform/SharedKernel/L10nFormat.swift`
- Translations belong in `*.lproj/Localizable.strings`
- Permission copy belongs in `*.lproj/InfoPlist.strings`

## Quality Gates

Before merging behavior changes:

- App builds
- Tests pass
- Module docs are updated
- Architecture or workflow docs are updated if the change affects system shape

### Manual Smoke Checklist

#### Library / Stacking

- Create a new project
- Open an existing project from the browser
- Duplicate and delete a project
- Import frames from Photos
- Import frames from Files
- Analyze, register, and stack a project
- Export TIFF
- Save result to Photos

#### Comet Mode

- Enable each comet mode
- Run registration so comet estimation appears
- Open the comet review flow
- Adjust a comet point manually
- Verify stack is blocked when review is incomplete

#### Camera

- Camera session starts
- Exposure and shot-count pickers open and close correctly
- Capture sequence runs
- Captured sequence overwrites the recent stacking project

#### Light Pollution

- App can center on current location
- Marker and info card update
- Mock reading renders correctly

## Common Issues

### `xcodegen` not found

```bash
brew install xcodegen
```

### New files do not appear in Xcode

```bash
xcodegen generate
```

### Simulator destination not found

List available devices in Xcode or use a concrete simulator ID in `xcodebuild`.

### Camera behavior differs on simulator

This is expected. AVFoundation camera behavior must be validated on a physical device.

## Documentation Expectations

When behavior changes:

- Update the relevant file in `docs/modules/`
- Update `docs/overview/ARCHITECTURE.md` if architecture or system shape changed
- Update `docs/roadmap.md` if priorities or sequence changed
- Update `README.md` if public-facing project capabilities changed
