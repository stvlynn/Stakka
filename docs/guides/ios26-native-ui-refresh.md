# iOS 26 Native UI Refresh

This guide records the current UI modernization pass. It is a maintainer
reference for the iOS 26 Liquid Glass migration, camera-page redesign,
library wizard native refresh, theme color consolidation, and validation
commands that were run.

## Scope

The refresh covered four product areas:

- Camera capture UI: preview chrome, capture button, controls drawer,
inline pickers, HUD, settings panel, and live-stack card.
- Library project creation and stacking surfaces: creation wizard,
project browser, frame sections, result cards, action bars, and comet
review surfaces.
- Light pollution map: native search presentation, app-accent map pin,
and glass info-card treatment.
- Design system: iOS 26 Liquid Glass helpers and one app-wide accent
color family.

## SDK And Build Baseline

The project now targets the iOS 26 SDK:

- `project.yml` sets the iOS deployment target to `26.0`.
- Swift is configured for Swift 6.
- The UI uses native iOS 26 APIs such as `glassEffect(_:in:)`,
`GlassEffectContainer`, `.buttonStyle(.glass)`, and
`.buttonStyle(.glassProminent)`.
- Local simulator commands target `iPhone 17 Pro` by default through
the `Makefile`.

Validation command:

```bash
make sim-build
```

The current refresh build passed with `make sim-build`.

## Design System Results

The accent system is now centralized:

- `Color.appAccent` is the only app-wide active / CTA / progress /
selected-state accent.
- `Color.appAccentSoft` and `Color.appAccentDim` provide same-hue
secondary shades.
- `Color.cosmicBlue`, `Color.cameraAccent`, and related aliases remain
only for compatibility and resolve to the app-accent family.
- New code should use `appAccent` instead of historical blue or
camera-specific green names.
- Bortle map colors are centralized in `DesignSystem.swift` as data
visualization tokens rather than hardcoded RGB in map code.

The Liquid Glass helpers are:

- `.liquidGlass(...)`
- `.liquidGlassCard(...)`
- `.liquidGlassPill(...)`
- `.systemGlass(...)`
- `.systemGlassCard(...)`
- `.systemGlassPill(...)`

Use `systemGlass*` for UI that should read as native system chrome. Use
`liquidGlass*` for app content cards that need the Stakka rim/highlight
layer over the system glass effect.

The design standard is now HIG-first:

- native SwiftUI controls and presentation patterns come before custom
drawing
- Stakka tokens are theme values, not replacements for system behavior
- custom controls must preserve iOS touch targets, Dynamic Type,
accessibility labels, and SF Symbol conventions

## Camera UI Results

The camera page now treats the preview as the primary canvas:

- The bottom tab bar remains visible.
- The navigation bar is hidden inside the camera tab.
- The camera preview renders edge-to-edge.
- During capture, the drawer and mode selector are hidden; the floating
capture button remains as the primary control.
- The capture button changes from the idle sparkles glyph to a stop
square and uses a circular progress ring for capture progress.
- Exposure and shot count use inline horizontal wheels above the drawer
instead of modal picker overlays.
- Aperture, shutter, zoom, and shooting mode reuse the same inline
picker mechanism from the expanded drawer.
- The astro mode selector only appears when the drawer is expanded.
- Nested card structures were flattened, green decorative dots were
removed, and card corner radii were standardized.
- The former `PRO` and live-mode pills were removed from the top area.
The compact parameter HUD now occupies the top controls bar alongside
the settings button.
- The settings panel no longer repeats controls already visible in the
HUD or drawer. It currently keeps the interval stepper as the unique
expanded setting.

## Library UI Results

The library workflow now follows the same native glass and accent rules:

- Project creation wizard step progress uses native `ProgressView`.
- The wizard cancellation control uses native glass button styling.
- The stacking-mode selection step is presented as a grouped row list
instead of large custom blue selection cards.
- Selection uses a checkmark and `appAccent`, not a fully filled card.
- Photos import buttons use native glass button styling.
- Optional badges, review cards, result cards, project browser controls,
frame sections, and action bars use centralized Liquid Glass helpers
or system glass button styles.
- Save/export/create/open primary actions use `.glassProminent` tinted
with `appAccent` where appropriate.

## Light Pollution UI Results

The map module was aligned with native iOS behavior:

- Place lookup is presented through SwiftUI's native `.searchable`
modifier rather than a custom search field.
- Search suggestions are system-managed and backed by
`MKLocalSearchCompleter`.
- The selected map pin uses `appAccent` through `UIColor(Color.appAccent)`.
- Bortle display colors remain scientific/data colors, but their map
palette is centralized in the design system.

## Verification

After the latest pass:

- Swift lint diagnostics reported no errors for edited files.
- `make sim-build` succeeded.
- Swift app code no longer directly uses `cosmicBlue`, `cameraAccent`,
hardcoded `Color(red:...)`, or hardcoded `UIColor(red:...)` outside
design-system compatibility aliases and centralized data tokens.

## Maintenance Rules

- New UI accent usage should use `Color.appAccent`.
- New UI should start from iOS/HIG patterns: native navigation, tabs,
search, lists, sheets, progress, and buttons.
- New app surfaces should prefer native iOS 26 glass APIs through the
design-system helpers.
- Do not reintroduce custom card backgrounds, ad hoc strokes, or
hardcoded color literals in feature views.
- Keep data visualization palettes centralized in `DesignSystem.swift`.
- Update this guide when another broad visual refresh changes multiple
modules at once.

