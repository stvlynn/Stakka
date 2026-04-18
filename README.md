# Stakka

iOS astrophotography app combining light pollution maps and image stacking for stargazing enthusiasts.

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

### 🗺️ Light Pollution Map
Query light pollution levels based on location using an interactive map interface. Find the best dark sky observation sites near you.

### 📷 Stacking Camera
Capture multiple exposures with advanced controls inspired by professional camera systems:

- **Wheel Picker Controls** — iOS-native wheel pickers for precise value selection (exposure, shot count)
- **Expandable Advanced Menu** — Drag up to reveal aperture, shutter speed, zoom, and shooting mode controls
- **Configurable Parameters**:
  - Exposure duration: 0.1-30 seconds
  - Number of shots: 2-100 frames
  - Interval between shots: 0-10 seconds
- **Real-time Progress** — Live capture progress with breathing glow animations
- **Sequential Capture** — Automated multi-frame capture with async/await

### 📚 Library Stacking
Select existing photos from your library and stack them together:

- Multi-selection up to 100 images
- Same mean stacking algorithm as camera
- Save results back to photo library
- Minimal UI with icon-first design

### 🎨 灵动美学 Design System
Modern iOS design language with:

- **Continuous corner radii** — Smooth, native iOS curves throughout
- **Minimal text** — Icons and numbers preferred over verbose labels
- **Breathing animations** — Subtle pulsing glows on live elements
- **Dark space theme** — Deep blacks with cosmic blue accents
- **Monospaced digits** — Stable layouts during value updates

## Architecture

Stakka follows a clean, modular architecture:

```
Stakka/
├── App/                 # Application entry and tab navigation
├── Features/            # Self-contained feature modules
│   ├── Camera/          # Multi-exposure capture system
│   ├── LightPollution/  # Map-based pollution lookup
│   └── Library/         # Photo library stacking
└── Core/                # Shared utilities and algorithms
    ├── ImageStacking/   # Mean stacking algorithm (actor-isolated)
    ├── Models/          # Data models
    └── Utilities/       # Design system tokens and extensions
```

Each feature follows MVVM with `@MainActor` ViewModels and pure SwiftUI views. See [ARCHITECTURE.md](docs/overview/ARCHITECTURE.md) for details.

## Tech Stack

- **SwiftUI** — Declarative UI framework
- **AVFoundation** — Camera capture and session management
- **MapKit** — Interactive light pollution map
- **PhotosUI** — Multi-image selection from library
- **CoreImage + CoreGraphics** — Image processing pipeline
- **Swift Concurrency** — Async/await throughout, actor isolation for stacking

Zero third-party dependencies. Built entirely on Apple system frameworks.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

## Quick Start

```bash
# Install XcodeGen
brew install xcodegen

# Clone and setup
git clone https://github.com/stvlynn/Stakka.git
cd Stakka
xcodegen generate

# Open in Xcode
open Stakka.xcodeproj
```

Build and run (⌘R). Use a physical device for camera features — simulator shows a test pattern.

See [WORKFLOW.md](docs/development/WORKFLOW.md) for detailed development setup.

## Documentation

- **[AGENTS.md](AGENTS.md)** — AI coding agent guidelines
- **[docs/overview/ARCHITECTURE.md](docs/overview/ARCHITECTURE.md)** — System architecture and design philosophy
- **[docs/modules/](docs/modules/)** — Module-specific documentation
  - [camera.md](docs/modules/camera.md) — Camera capture system
  - [library-stacking.md](docs/modules/library-stacking.md) — Photo library workflow
  - [light-pollution.md](docs/modules/light-pollution.md) — Map integration
  - [image-stacking.md](docs/modules/image-stacking.md) — Stacking algorithm
  - [design-system.md](docs/modules/design-system.md) — Design tokens and patterns
- **[docs/development/WORKFLOW.md](docs/development/WORKFLOW.md)** — Development workflow and contribution guide

## Image Stacking Algorithm

Stakka uses **mean stacking** to reduce noise:

```
For each pixel (x, y):
    R_out = mean(R_1, R_2, ..., R_n)
    G_out = mean(G_1, G_2, ..., G_n)
    B_out = mean(B_1, B_2, ..., B_n)
```

This improves signal-to-noise ratio by √n. Doubling the frame count improves SNR by ~41%.

The algorithm is actor-isolated for thread safety and uses async/await for non-blocking execution. See [image-stacking.md](docs/modules/image-stacking.md) for implementation details.

## Design Philosophy

### Minimal Text, Maximum Clarity

Stakka assumes users are familiar with photography concepts. The UI uses icons and numbers instead of verbose labels:

```
Good:  [1.5]  [●]  [10]
        ⏱️    ✨   📷

Bad:   Exposure Time: 1.5 seconds
       Capture Button
       Number of Shots: 10
```

### Wheel Pickers Over Sliders

Camera controls use iOS-native wheel pickers (like the Clock app) for precise value selection. This provides better accessibility and matches user mental models for photography parameters.

### Continuous Corners Everywhere

All UI elements use continuous corner radii (iOS 13+ style) for visual consistency with Dynamic Island and modern iOS design language.

See [ARCHITECTURE.md](docs/overview/ARCHITECTURE.md) for full design philosophy.

## Project Structure

```
Stakka/
├── project.yml                      # XcodeGen configuration
├── AGENTS.md                        # AI agent guidelines
├── docs/                            # Documentation
│   ├── overview/ARCHITECTURE.md
│   ├── modules/                     # Module docs
│   └── development/WORKFLOW.md
└── Stakka/
    ├── App/
    │   ├── StakkaApp.swift          # App entry
    │   └── ContentView.swift        # Tab navigation
    ├── Features/
    │   ├── Camera/
    │   │   ├── CameraView.swift
    │   │   ├── CameraViewModel.swift
    │   │   ├── CameraControlsView.swift
    │   │   ├── CameraSettingsView.swift
    │   │   └── Components/
    │   │       ├── WheelPickerView.swift
    │   │       └── AdvancedControlsMenu.swift
    │   ├── LightPollution/
    │   │   └── LightPollutionMapView.swift
    │   └── Library/
    │       ├── LibraryStackingView.swift
    │       └── LibraryStackingViewModel.swift
    └── Core/
        ├── ImageStacking/
        │   └── ImageStacker.swift   # Mean stacking (actor)
        ├── Models/
        │   └── Models.swift
        └── Utilities/
            ├── DesignSystem.swift   # Design tokens
            └── Extensions.swift
```

## Contributing

Contributions welcome! Please:

1. Read [ARCHITECTURE.md](docs/overview/ARCHITECTURE.md) to understand the system
2. Check [WORKFLOW.md](docs/development/WORKFLOW.md) for development setup
3. Review [AGENTS.md](AGENTS.md) for coding guidelines
4. Keep PRs focused — one feature per PR
5. Update relevant module docs with your changes

### Before Submitting

- Build succeeds in Xcode (⌘B)
- Manual UI testing checklist passed (see [WORKFLOW.md](docs/development/WORKFLOW.md))
- Documentation updated if adding new features or patterns

## Known Limitations

- **Light pollution data** — Currently uses mock data, needs API integration
- **Advanced camera controls** — Aperture/shutter/ISO are UI placeholders (not wired to AVFoundation yet)
- **Auto-stacking** — Camera captures images but doesn't auto-stack on completion yet
- **Export options** — Limited to saving to photo library (no Files app export)

See individual module docs for detailed limitations and future work.

## Roadmap

- [ ] Real light pollution data integration (API or offline dataset)
- [ ] Wire advanced camera controls to AVFoundation
- [ ] Auto-stack after camera capture sequence
- [ ] Median and sigma-clipping stacking modes
- [ ] Image alignment before stacking (for handheld shots)
- [ ] Histogram display during capture
- [ ] Export to Files app
- [ ] Favorite locations persistence
- [ ] Weather data overlay (cloud cover, seeing conditions)

## References

- [Light Pollution Map](https://github.com/cgettings/Light-Pollution-Map) — Pollution data source reference
- [HoshinoWeaver](https://github.com/Designerspr/HoshinoWeaver) — Stacking algorithm reference
- [Mijick Camera](https://github.com/Mijick/Camera) — Camera implementation reference

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Built with inspiration from professional astrophotography workflows and iOS design language. Special thanks to the open-source astronomy and iOS development communities.
