# Swift i18n And Skill Design

## Summary

Stakka should standardize on Xcode String Catalog localization with English as the source language and a thin Swift wrapper layer for stable call sites. The app currently embeds user-facing Chinese strings directly in SwiftUI views, which makes English-first development, translation management, and localization review inconsistent.

This design introduces:

- one app-level localization resource strategy based on `Localizable.xcstrings`
- one code-level access layer under `Platform/Localization/`
- one formatting layer for locale-aware numbers and astrophotography-specific display values
- one migration workflow for existing hardcoded strings
- one reusable Codex skill for Swift and SwiftUI localization work

The first supported languages are:

- `en` as source language
- `zh-Hans`
- `zh-Hant`

## Goals

- Make English the single source of truth for user-facing text.
- Eliminate direct hardcoded UI copy in SwiftUI views.
- Keep localization call sites readable in SwiftUI.
- Localize dynamic phrases, not only static labels.
- Keep number and unit formatting locale-aware.
- Make permission strings and other bundle metadata localizable.
- Create a reusable skill that can guide future i18n work in Swift and SwiftUI projects.

## Non-Goals

- Introduce a third-party localization library or code generator.
- Add remote translation management.
- Localize internal developer logs.
- Automatically translate copy without review.
- Rewrite non-user-facing domain model identifiers.

## Current State

The repo already declares `developmentLanguage: en` in `project.yml`, but the app UI mostly uses inline Chinese strings in SwiftUI views. Examples include tab labels, navigation titles, action buttons, empty states, and status messages in files such as:

- `Stakka/App/Root/ContentView.swift`
- `Stakka/Domains/Capture/Presentation/CameraView.swift`
- `Stakka/Domains/Library/Presentation/LibraryStackingView.swift`

There is no dedicated localization module, no string catalog, and no documented rule for key naming or dynamic formatting.

## Decision

Adopt approach 2:

- Xcode String Catalog via `Localizable.xcstrings`
- a thin `L10n` wrapper for stable access points
- a thin formatting utility for locale-aware values

This is the best fit for the current stack because the project is already on Xcode 15 and iOS 17, relies on native Apple frameworks, and does not currently benefit enough from the complexity of code generation.

## App Localization Architecture

### Resource Structure

Add localization resources under the app target:

- `Stakka/Resources/Localization/Localizable.xcstrings`
- `Stakka/Resources/Localization/en.lproj/InfoPlist.strings`
- `Stakka/Resources/Localization/zh-Hans.lproj/InfoPlist.strings`
- `Stakka/Resources/Localization/zh-Hant.lproj/InfoPlist.strings`

Resource rules:

- Use `Localizable.xcstrings` for all normal UI strings.
- Use `InfoPlist.strings` only for permission and bundle metadata strings.
- Keep one main catalog until there is a proven need to split by module.

### Code Structure

Add a new module-level location:

- `Stakka/Platform/Localization/L10n.swift`
- `Stakka/Platform/Localization/L10nFormat.swift`

Responsibilities:

- `L10n.swift` exposes stable accessors for user-facing strings.
- `L10nFormat.swift` centralizes locale-aware formatting for numbers, durations, coordinates, counts, percentages, and progress text.

This keeps view code declarative while preventing direct key scattering across the app.

Type rules:

- Static entries in `L10n` should return `LocalizedStringResource`.
- Parameterized entries in `L10n` should return `String` produced through Apple-native localization APIs such as `String(localized:)`.
- Views may pass static resources directly into `Text`.
- Views may pass parameterized results into `Text` as plain `String`.

### Access Pattern

Static strings:

```swift
Text(L10n.Tab.map)
Text(L10n.Camera.title)
```

Parameterized strings:

```swift
Text(L10n.Library.captureProgress(current: current, total: total))
Text(L10n.Library.addFrame(kind: localizedKind))
```

Formatting-only values:

```swift
Text(L10nFormat.exposureDuration(seconds))
Text(L10nFormat.coordinate(latitude))
```

Rules:

- Do not concatenate sentence fragments in views.
- Do not build user-facing copy with string interpolation directly in UI code unless it is routed through `L10n`.
- Do not use raw localized keys inline in views.
- Prefer `LocalizedStringResource` over `LocalizedStringKey` in the wrapper layer for compile-time clarity on modern Apple toolchains.
- Allow purely symbolic or numeric UI to stay text-light, but still format numbers through locale-aware APIs.

## Key Naming Convention

Keys should be semantic and domain-oriented, not sentence-oriented.

Pattern:

- `{domain}.{feature}.{item}`
- `{domain}.{feature}.{state}.{item}` when additional scope is needed

Examples:

- `tab.map`
- `tab.camera`
- `tab.stack`
- `camera.title`
- `camera.recent-project.saved`
- `camera.settings.shot-count`
- `library.title`
- `library.intro.title`
- `library.intro.subtitle`
- `library.action.analyze`
- `library.action.register`
- `library.action.stack`
- `library.project.empty`
- `darksky.reading.level.title`

Rules:

- Keep keys stable even if English copy changes.
- Do not encode language into keys.
- Do not use full English sentences as keys.
- Prefer one complete phrase per key over composable fragments.
- Keep frame-kind labels as separate keys if they are user-visible.

## Formatting Strategy

Locale-sensitive formatting must be centralized because this app displays values where formatting affects correctness and legibility.

Initial helpers should cover:

- integer counts
- decimal coordinates
- exposure duration in seconds
- progress display such as `3/10`
- percentages
- optional unit-bearing values that may grow later, such as intervals

Implementation rules:

- Use Swift `FormatStyle` and locale-aware APIs where possible.
- Keep formatter output free of duplicated units in translated strings.
- For display values used in minimal-text UI, prefer compact formatted values that preserve the current design language.
- Keep `.monospacedDigit()` in views for changing numbers; localization should not remove this design rule.

## Info.plist Localization

Localize these permission strings through `InfoPlist.strings`:

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSLocationWhenInUseUsageDescription`

Rules:

- Do not keep permission strings only in `project.yml` long term.
- Treat permission descriptions as user-facing copy with the same review standard as UI text.
- Keep tone concise and aligned with the product voice.

## Migration Plan

### Phase 1: High-Visibility UI

Migrate first:

- tab labels
- navigation titles
- primary action buttons
- empty states
- inline error messages
- top-level status cards

Primary target files:

- `Stakka/App/Root/ContentView.swift`
- `Stakka/Domains/Capture/Presentation/CameraView.swift`
- `Stakka/Domains/Library/Presentation/LibraryStackingView.swift`
- related top-level component views used by those screens

### Phase 2: Feature Detail UI

Migrate next:

- camera settings labels
- wheel picker confirmation text
- project browser labels
- comet review workflow strings
- stack result strings

### Phase 3: Completeness Pass

Finish with:

- accessibility labels and hints
- permission copy
- export and save messages
- any remaining inline supporting text

## Error Handling

Localization must not add business logic branches, but it should reduce copy inconsistency.

Rules:

- Domain errors should resolve to user-facing localized messages at the presentation boundary.
- Avoid passing raw error descriptions from framework APIs directly into UI.
- When an error includes variable data, localize the template and format the variable separately.

## Testing Strategy

### Build And Runtime Validation

- Regenerate the project if resources are added and XcodeGen requires it.
- Confirm the app builds after localization resources are added.
- Confirm string catalog resources are included in the app target.

### Manual Smoke Tests

Run the app in:

- English
- Simplified Chinese
- Traditional Chinese

Validate:

- tab labels
- navigation titles
- primary action buttons
- empty states
- project browser
- comet review flow
- permission dialogs
- dynamic values with `.monospacedDigit()`

### Static Audit

Add one repository script that scans for likely hardcoded user-facing strings in Swift files. This is a guardrail, not a perfect validator.

The script should:

- flag `Text("...")`, `Label("...")`, `Button("...")`, and similar direct literals
- ignore obvious test fixtures and non-user-facing literals where practical
- report likely violations for manual review

## Skill Design

### Skill Name

Use `swift-i18n`.

### Skill Location

Default to:

- `skills/swift-i18n` at the repository root
- concrete path for this repo: `/Users/steven/code/stakka/skills/swift-i18n`

This keeps the skill versioned with the project and allows the repository to carry its own SwiftUI and localization conventions. Because this is a project-local skill rather than a global user skill, agents should be given the explicit path when using it.

### Skill Purpose

The skill should help Codex design, migrate, audit, and review localization in Swift and SwiftUI codebases that use Apple-native localization tooling.

### Skill Contents

Required:

- `SKILL.md`

Recommended:

- `references/conventions.md`
- `scripts/audit_localization.sh`

No assets are required for v1.

### Skill Trigger Description

The skill should trigger when the user asks to:

- add i18n or l10n to a Swift or SwiftUI app
- migrate hardcoded strings to Apple localization resources
- review localization quality in an iOS app
- set up English source strings with Chinese translations
- add String Catalog based localization

### Skill Workflow

The skill should instruct Codex to:

1. inspect the existing project for hardcoded UI strings and current localization setup
2. confirm source language and target languages
3. prefer `String Catalog` plus Apple-native localization APIs
4. create or update a thin access layer instead of scattering raw keys
5. separate UI strings from `InfoPlist.strings`
6. migrate highest-visibility screens first
7. run static audit checks and build validation
8. summarize remaining untranslated or suspicious call sites

### Skill Reference File

`references/conventions.md` should cover:

- key naming rules
- call-site rules
- formatter boundaries
- `InfoPlist.strings` rules
- migration sequencing
- review checklist

### Skill Audit Script

`scripts/audit_localization.sh` should:

- use `rg` to scan Swift files for likely hardcoded UI literals
- print categorized findings with file paths and line numbers
- exit non-zero only for script failure, not for normal findings

This keeps the script useful in review workflows without making every finding fatal.

## Risks And Mitigations

### Risk: Fragment-Based Localization

If views compose copy from fragments, translations will become awkward or wrong.

Mitigation:

- enforce complete-phrase keys
- centralize dynamic templates in `L10n`

### Risk: Over-Engineering The Wrapper

A large generated or heavily abstracted localization layer would be expensive for a small app.

Mitigation:

- keep `L10n` thin
- use native localization resources
- avoid adding code generation in v1

### Risk: Locale Formatting Drift

Numbers may look inconsistent if each view formats them independently.

Mitigation:

- route shared display values through `L10nFormat`
- keep visual styling such as `.monospacedDigit()` at the view layer

### Risk: Permission Strings Stay English-Only

If permission copy remains only in project configuration, the localized app will feel incomplete.

Mitigation:

- add `InfoPlist.strings` in all target languages during the initial setup

## Rollout Recommendation

Implement the skill first, then use it to guide the repo-local i18n migration. This keeps the policy reusable and lets later localization work follow the same rules.

## Success Criteria

This design is successful when:

- the app has one English-first localization foundation
- new user-facing strings are added through `L10n` and catalog resources
- the main screens no longer contain hardcoded user-facing literals
- permission strings are localized
- a reusable `swift-i18n` skill exists and validates cleanly

