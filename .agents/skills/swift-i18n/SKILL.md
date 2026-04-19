---
name: swift-i18n
description: Design, migrate, audit, and review localization in Swift and SwiftUI codebases using Apple-native localization resources. Use when adding i18n or l10n to an iOS or macOS app, moving hardcoded UI strings into String Catalog or Localizable.strings, localizing Info.plist permission copy, setting English source strings with Chinese translations, or checking locale-aware formatting and localization quality in Swift views.
---

# Swift i18n

Localize Swift and SwiftUI apps with Apple-native tooling first. Prefer `String Catalog` on modern toolchains, keep `InfoPlist.strings` separate for bundle metadata, and stop user-facing copy from being scattered through views.

## Quick Start

1. Inspect the repo for current localization patterns before changing anything.
2. Confirm source language and target languages.
3. Stay consistent with the existing project if it already has a working localization system.
4. Prefer `Localizable.xcstrings` plus a thin wrapper layer when the project is on modern Apple toolchains and has no strong prior convention.
5. Read [references/conventions.md](./references/conventions.md) before designing keys or writing wrappers.
6. Run [scripts/audit_localization.sh](./scripts/audit_localization.sh) before and after migration to find likely hardcoded UI strings.

## Workflow

### 1. Inspect Current State

Check for:

- `*.xcstrings`
- `Localizable.strings`
- `InfoPlist.strings`
- `NSLocalizedString`
- `String(localized:)`
- `LocalizedStringResource`
- direct SwiftUI literals such as `Text("...")`

Decide whether to preserve an existing localization convention or introduce a new one. Do not force `String Catalog` into a mature codebase that is already standardized on `.strings` unless the user asked for migration.

### 2. Choose The Resource Strategy

Preferred order:

1. `String Catalog` for modern SwiftUI-first apps on Xcode 15 or newer
2. Existing `.strings` or `.stringsdict` system when the repo is already built around it
3. Mixed mode only when migrating incrementally and the repo cannot switch in one pass

Use `InfoPlist.strings` for permission strings and bundle metadata. Do not keep those strings only in build configuration long term.

### 3. Define The Call-Site Strategy

Use a thin wrapper layer instead of scattering raw keys through views.

Recommended pattern:

- static entries return `LocalizedStringResource`
- parameterized entries return `String` from `String(localized:)`
- locale-sensitive value formatting lives in a separate formatter helper

Example:

```swift
enum L10n {
    enum Tab {
        static let map = LocalizedStringResource("tab.map", defaultValue: "Map")
    }

    enum Camera {
        static func captureProgress(current: Int, total: Int) -> String {
            String(
                localized: "camera.capture.progress",
                defaultValue: "\(current)/\(total)",
                table: "Localizable"
            )
        }
    }
}
```

Keep view code simple:

```swift
Text(L10n.Tab.map)
Text(L10n.Camera.captureProgress(current: current, total: total))
```

Do not compose user-facing phrases from fragments in views.

### 4. Centralize Formatting

Move locale-sensitive formatting into one helper such as `L10nFormat`.

Centralize:

- counts
- percentages
- coordinates
- durations
- intervals
- values that appear in progress or status UI

Keep visual styling such as `.monospacedDigit()` at the view layer.

### 5. Migrate In Visibility Order

Migrate in this order unless the user asks for a different slice:

1. tab labels and navigation titles
2. primary buttons and empty states
3. inline status and error copy
4. feature-detail labels
5. accessibility labels and permission copy

This keeps the first pass easy to verify and avoids half-localized primary screens.

### 6. Validate

Run:

- build validation
- manual language smoke tests
- the audit script again

Smoke test at least the source language plus every newly added target language. Check truncation, plural logic, units, and number formatting.

## Rules

- Prefer semantic keys such as `camera.title` or `library.action.stack`.
- Keep keys stable even if English copy changes.
- Prefer complete-phrase keys over composable fragments.
- Do not hardcode user-facing strings directly in SwiftUI views.
- Do not expose raw framework error strings directly to users without review.
- Do not mix permission strings into normal UI catalogs.
- Do not introduce a third-party localization library unless the user explicitly wants one.

## When To Read References

Read [references/conventions.md](./references/conventions.md) when you need:

- key naming rules
- wrapper design rules
- formatter boundaries
- `InfoPlist.strings` guidance
- migration sequencing
- review checklist

## When To Run The Script

Run [scripts/audit_localization.sh](./scripts/audit_localization.sh) when you need a quick static pass over Swift files to find likely hardcoded UI literals. Treat its output as review input, not as a perfect source of truth.

Example:

```bash
bash skills/swift-i18n/scripts/audit_localization.sh Stakka
```

## Deliverables

When implementing localization work, try to leave behind:

- a documented source language
- a consistent resource strategy
- a thin wrapper for localized strings
- a shared formatter helper when values are locale-sensitive
- localized `InfoPlist.strings` when permissions are involved
- a summary of remaining untranslated or suspicious call sites
