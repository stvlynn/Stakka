# Development Workflow

## Prerequisites

- macOS 26+ (Tahoe)
- Xcode 26+ — required because Stakka adopts iOS 26 Liquid Glass APIs
  (`glassEffect(_:in:)`, `GlassEffectContainer`, `Glass`,
  `.buttonStyle(.glass)`). Earlier Xcode releases (16.x / 17.x) do not
  ship the iOS 26 SDK and the project will not compile against them.
- Swift 6.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

If `xcodebuild -version` reports anything older than Xcode 26, install
the latest Xcode from the Mac App Store or
<https://developer.apple.com/download/applications/> and point the
command-line tools at it:

```bash
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version
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

Most day-to-day commands are wrapped in `Makefile`. The Makefile keeps
generated project files, simulator builds, installation, and launch
behavior consistent across local machines.

### Regenerate Project

```bash
make generate
```

### Build

```bash
make build-debug
```

`build-debug` uses a generic simulator destination and is the fastest
local compile check. Use `make sim-build` when you need an installable
`.app` for a concrete simulator.

### Run on Simulator

```bash
make run
```

`make run` performs the full simulator loop:

1. Generate `Stakka.xcodeproj`
2. Boot the configured simulator
3. Open Simulator.app
4. Build the Debug app for that simulator
5. Install `Stakka.app`
6. Terminate any existing Stakka process
7. Launch with `simctl launch --console-pty` so stdout/stderr stream in
   the terminal

Default simulator:

```bash
SIMULATOR ?= iPhone 17 Pro
```

Override it per command:

```bash
make run SIMULATOR='iPhone 17'
make run SIMULATOR='iPhone 17 Pro Max'
```

To see available devices:

```bash
make sim-list
```

For persistent local defaults, create `Makefile.local`:

```makefile
SIMULATOR := iPhone 17 Pro Max
```

`Makefile.local` is loaded automatically and should remain local to the
developer machine.

### Attach a Debugger

```bash
make debug
```

This builds and installs the app, then launches it with
`--wait-for-debugger`. In Xcode, use **Debug → Attach to Process** and
choose `Stakka`.

### Simulator Utilities

| Command | Use |
|---|---|
| `make sim-open` | Boot the configured simulator and open Simulator.app |
| `make sim-install` | Build and install without launching |
| `make sim-launch` | Launch the already-installed app |
| `make sim-stop` | Terminate the app on the configured simulator |
| `make sim-logs` | Stream simulator OS logs filtered to the Stakka process |
| `make sim-shutdown` | Shut down the configured simulator |
| `make sim-erase` | Erase content and settings for the configured simulator |

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
make open
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

- Camera session starts and the preview is rendered edge-to-edge
- Drawer in its collapsed state shows only the drag indicator and the
  primary controls row (no mode selector visible)
- Dragging the drawer up reveals both the astro mode selector and the
  secondary advanced control buttons; dragging down hides them again
- Exposure and shot-count inline horizontal wheels open, snap, update,
  and close correctly
- Expanded drawer controls switch the same inline wheel between
  aperture, shutter, zoom, and shooting mode
- Starting a capture sequence collapses the top controls bar, the mode
  selector, and the controls drawer; only a floating capture/stop
  button remains over the preview
- The capture button shows the stop square and animated progress ring
  with the `current/total` caption while capturing
- Stopping (or completing) a capture restores the full chrome with a
  smooth animated transition
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

```bash
make sim-list
make run SIMULATOR='iPhone 15 Pro'
```

Use any installed simulator name from `sim-list`. If builds still fail,
open Xcode once so it can finish simulator runtime setup.

### Camera behavior differs on simulator

This is expected. AVFoundation camera behavior must be validated on a physical device.

## Documentation Expectations

When behavior changes:

- Update the relevant file in `docs/modules/`
- Update `docs/overview/ARCHITECTURE.md` if architecture or system shape changed
- Update `docs/roadmap.md` if priorities or sequence changed
- Update `README.md` if public-facing project capabilities changed
