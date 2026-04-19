# Swift i18n Conventions

## Resource Choice

Prefer `Localizable.xcstrings` for modern Apple projects unless the repo already has a consistent `.strings` workflow. Keep `InfoPlist.strings` separate for permission and bundle metadata copy.

## Source Language

Pick one source language and keep it explicit. If the project uses English as the source language:

- make English the default value in wrappers and resources
- keep translations in target languages only
- avoid back-translating from an existing non-English UI during implementation without review

## Key Naming

Use semantic keys:

- `tab.map`
- `camera.title`
- `camera.recent-project.saved`
- `library.action.stack`
- `darksky.reading.level.title`

Rules:

- keep keys stable
- prefer domain grouping
- avoid sentence-as-key patterns
- avoid language suffixes inside keys
- prefer complete phrases over fragments

## Wrapper Design

Keep the wrapper thin.

Recommended:

- static entries return `LocalizedStringResource`
- parameterized entries return `String`
- shared value formatting lives in a formatter helper

Avoid:

- raw string keys scattered in view files
- large generated enums unless the repo already uses generation
- direct sentence concatenation in UI code

## Formatting Boundaries

Put locale-sensitive formatting in one place. Centralize:

- counts
- decimal values
- percentages
- durations
- coordinate displays
- progress displays

Keep view-specific styling outside the formatter:

- `.monospacedDigit()`
- fonts
- colors
- layout modifiers

## InfoPlist Localization

Localize permission strings in `InfoPlist.strings`, not in normal UI resources:

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSLocationWhenInUseUsageDescription`

Review them like product copy. They are part of the user experience.

## Migration Order

Recommended order:

1. tab labels and titles
2. primary actions and empty states
3. status and error copy
4. detail labels and secondary copy
5. accessibility labels and permission copy

## Review Checklist

- Is the source language explicit?
- Is the resource strategy consistent across the repo?
- Was the audit script pointed at the app source directory instead of a noisy monorepo root?
- Are there any remaining `Text("...")`, `Button("...")`, `Label("...")`, or `navigationTitle("...")` call sites with user-facing literals?
- Are dynamic phrases localized as complete templates?
- Are locale-sensitive values formatted centrally?
- Are permission strings localized separately?
- Does the UI still respect numeric layout requirements such as `.monospacedDigit()`?
