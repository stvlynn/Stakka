<p align="center">
  <img src="./icon.png" alt="Stakka app icon" width="128" height="128">
</p>

<h1 align="center">Stakka</h1>

<p align="center">
  iOS astrophotography for dark-sky discovery, capture sequencing, and frame stacking.
</p>

<p align="center">
  <a href="https://developer.apple.com/ios/"><img alt="iOS" src="https://img.shields.io/badge/iOS-17.0+-blue.svg"></a>
  <a href="https://swift.org"><img alt="Swift" src="https://img.shields.io/badge/Swift-5.9+-orange.svg"></a>
  <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-green.svg"></a>
</p>

## Overview

Stakka combines three product areas:

- **Library stacking** with project-based workflows, grouped calibration frames, TIFF export, and DSS-style comet modes
- **Capture sequencing** with wheel-picker camera controls and handoff into the stacking project system
- **Dark-sky exploration** with MapKit-based location readings and a light-pollution surface

The current codebase is beyond the original prototype, but still mid-transition. RAW/FITS import, intermediate exports, live stacking, and real light-pollution data are still in progress.

## Current Capabilities

### Library Projects

- Create, open, duplicate, and delete local stacking projects
- Organize `Light / Dark / Flat / Dark Flat / Bias` frame groups
- Import frames from Photos or Files
- Run `analyze -> register -> stack`
- Save the final result to Photos or export TIFF

### Comet Modes

- `standard`: stars frozen, comet trails
- `cometOnly`: comet frozen, stars trail
- `cometAndStars`: comet and stars both frozen
- Automatic comet estimation after registration
- Full-screen per-frame comet review and manual correction

### Camera

- Sequential multi-frame capture
- Wheel-picker controls for exposure and shot count
- Expandable advanced controls
- Capture-to-project handoff into the recent stacking project

### Light Pollution

- MapKit-based dark-sky exploration
- Current-location centering
- Bortle-style mock readings

## Architecture

Stakka uses a domain-oriented structure:

```text
Stakka/
├── App/
├── Domains/
│   ├── Capture/
│   ├── DarkSky/
│   ├── Library/
│   ├── Session/
│   └── Stacking/
└── Platform/
```

Core rules:

- `App` wires dependencies and root navigation
- `Domains/*/Presentation` owns SwiftUI views and view models
- `Domains/*/Application` owns orchestration and use cases
- `Domains/*/Domain` holds business models and protocols
- `Domains/*/Infrastructure` holds framework adapters and storage

Start with [docs/overview/ARCHITECTURE.md](docs/overview/ARCHITECTURE.md) for the full system guide.

## Tech Stack

- SwiftUI
- AVFoundation
- MapKit
- PhotosUI
- CoreImage + CoreGraphics
- Vision
- Swift Concurrency
- XcodeGen

## Quick Start

```bash
brew install xcodegen
git clone https://github.com/stvlynn/Stakka.git
cd Stakka
xcodegen generate
open Stakka.xcodeproj
```

Build from the command line:

```bash
xcodebuild \
  -project Stakka.xcodeproj \
  -scheme Stakka \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

If that simulator is unavailable, use any installed iPhone simulator or a concrete simulator identifier.

## Docs

### Start Here

- [docs/README.md](docs/README.md)
- [docs/overview/ARCHITECTURE.md](docs/overview/ARCHITECTURE.md)
- [docs/development/WORKFLOW.md](docs/development/WORKFLOW.md)

### Module Docs

- [docs/modules/library-stacking.md](docs/modules/library-stacking.md)
- [docs/modules/image-stacking.md](docs/modules/image-stacking.md)
- [docs/modules/camera.md](docs/modules/camera.md)
- [docs/modules/light-pollution.md](docs/modules/light-pollution.md)
- [docs/modules/design-system.md](docs/modules/design-system.md)

### Guides

- [docs/guides/project-catalog.md](docs/guides/project-catalog.md)
- [docs/guides/library-workflow.md](docs/guides/library-workflow.md)
- [docs/guides/comet-mode.md](docs/guides/comet-mode.md)
- [docs/guides/capture-handoff.md](docs/guides/capture-handoff.md)

### Planning

- [docs/roadmap.md](docs/roadmap.md)

## Known Gaps

- No RAW/FITS import yet
- No calibrated or registered intermediate export yet
- No live stacking yet
- No background calibration, channel alignment, or cosmetic correction yet
- Advanced camera controls are not fully wired to device hardware
- Light-pollution data is still mocked

## License

MIT. See [LICENSE](LICENSE).
