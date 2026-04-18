# Development Workflow

## Prerequisites

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

## First-Time Setup

```bash
# 1. Clone the repository
git clone https://github.com/stvlynn/Stakka.git
cd Stakka

# 2. Generate the Xcode project
xcodegen generate

# 3. Open in Xcode
open Stakka.xcodeproj
```

The `.xcodeproj` is not committed. Always regenerate it after pulling changes that modify `project.yml`.

## Daily Workflow

### After pulling changes

```bash
xcodegen generate
```

If project.yml hasn't changed, regenerating is fast and idempotent.

### Build

```bash
# Build for simulator
xcodebuild \
  -project Stakka.xcodeproj \
  -scheme Stakka \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build

# Or simply ⌘B in Xcode
```

### Run

Use Xcode (⌘R). Select an iPhone 15 Pro simulator for the most accurate layout preview.

### Test Camera Features

The camera requires a physical device:

1. Connect iPhone (iOS 17.0+)
2. Select your device in Xcode's device selector
3. Run (⌘R)
4. Trust developer certificate on device if prompted

Simulator supports AVFoundation APIs but shows a static test pattern instead of live camera.

## Project Structure Navigation

See [ARCHITECTURE.md](../overview/ARCHITECTURE.md) for full structure. Key entry points:

| Task | Start Here |
|------|-----------|
| Add new camera control | `Features/Camera/Components/` |
| Modify stacking algorithm | `Core/ImageStacking/ImageStacker.swift` |
| Change design tokens | `Core/Utilities/DesignSystem.swift` |
| Add new feature tab | `App/ContentView.swift` + new `Features/` directory |

## Adding New Files

XcodeGen manages project membership. To add a new Swift file:

1. Create the file in the correct directory
2. Run `xcodegen generate`
3. The file is automatically added to the project

No need to manually add files in Xcode. Files in `Stakka/` are picked up automatically.

### project.yml Reference

```yaml
# All .swift files under Sources are included automatically
targets:
  Stakka:
    sources:
      - Stakka
```

If a file isn't showing up in Xcode, check:
1. Is the file in a directory under `Stakka/`?
2. Has `xcodegen generate` been run?
3. Does the file extension match (`.swift`)?

## Quality Gates

### Build Check

Must pass before any PR:

```bash
xcodebuild \
  -project Stakka.xcodeproj \
  -scheme Stakka \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build 2>&1 | tail -20
```

No warnings promoted to errors in current configuration, but zero warnings is the goal.

### Manual UI Testing Checklist

Before submitting a camera-related PR:

- [ ] Exposure wheel picker opens and closes cleanly
- [ ] Shot count wheel picker opens and closes cleanly
- [ ] Advanced menu expands on upward drag (50pt threshold)
- [ ] Advanced menu collapses on downward drag
- [ ] Each advanced control button opens correct picker
- [ ] Capture button starts sequence
- [ ] Progress updates during capture
- [ ] Stop button cancels capture

Before submitting a library stacking PR:

- [ ] PhotosPicker opens and allows multi-selection
- [ ] Thumbnails render in grid
- [ ] Stack button triggers processing
- [ ] Progress spinner shows during stacking
- [ ] Result image renders with gradient border
- [ ] Save saves to photo library

## Common Issues

### `xcodegen` command not found

```bash
brew install xcodegen
```

### Build fails after pull

```bash
xcodegen generate
```

Then clean build folder in Xcode (⇧⌘K) and rebuild.

### Simulator camera shows black

This is normal. AVFoundation returns a test pattern on simulator. Use physical device for camera testing.

### "Cannot find X in scope" errors

This usually means a new file hasn't been added to the project. Run:

```bash
xcodegen generate
```

### Permissions denied on device

Ensure `project.yml` has the correct entitlements. Check:
- `NSCameraUsageDescription` in Info.plist
- `NSPhotoLibraryUsageDescription`
- `NSLocationWhenInUseUsageDescription`

## Branching

```bash
# Feature branches
git checkout -b feature/your-feature-name

# Bug fix
git checkout -b fix/description-of-bug
```

PR against `main`. Keep PRs focused — one feature per PR.

## Commit Style

```
feat: add median stacking mode to ImageStacker
fix: wheel picker doesn't dismiss on iPad
docs: update camera module docs with new controls
style: apply breathingGlow to capture progress
```

Prefix: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.

## Dependency Management

No external dependencies currently. If adding a package:

1. Add to `project.yml`:
```yaml
packages:
  PackageName:
    url: https://github.com/org/repo
    version: 1.0.0
```

2. Reference in target:
```yaml
targets:
  Stakka:
    dependencies:
      - package: PackageName
```

3. Run `xcodegen generate`

Prefer Apple system frameworks. Each added dependency requires PR discussion.

## Release Process

1. Update version in `project.yml`
2. Run `xcodegen generate`
3. Archive in Xcode (Product → Archive)
4. Upload to App Store Connect via Xcode Organizer

## Getting Help

- Architecture questions: `docs/overview/ARCHITECTURE.md`
- Module specifics: `docs/modules/{module}.md`
- AI agent guidelines: `AGENTS.md`
- Open an issue on GitHub for bugs and feature requests
