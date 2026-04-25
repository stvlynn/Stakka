# Design System

Stakka uses a centralized design system defined in `Platform/DesignSystem/DesignSystem.swift`.
The design system aligns feature UI with Apple's Human Interface
Guidelines first, then adds the app's astronomy theme through a small set
of semantic tokens. All UI components consume from this system. No
hardcoded values in views.

## File

```
Platform/DesignSystem/
├── DesignSystem.swift    # All tokens and modifiers
└── Extensions.swift      # Shared Swift / Combine helpers
```

## iOS Alignment Principles

Stakka UI should feel like an iOS app before it feels branded. Apply the
HIG principles in this order:

1. **Clarity** — use legible system typography, SF Symbols, concise copy,
   and obvious state changes.
2. **Deference** — let camera preview, stacked images, and map content
   lead; chrome should stay light and avoid nested surfaces.
3. **Depth** — use native iOS 26 Liquid Glass, system navigation, sheets,
   search, tab bars, and lists to communicate hierarchy.

### Native Component Rules

- Prefer `NavigationStack`, `TabView` with `Tab(...)`, `.searchable`,
  system sheets, `ProgressView`, `PhotosPicker`, and SwiftUI `Button`
  styles before building custom controls.
- Use `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` for
  tappable glass buttons where the system style fits.
- Use custom drawing only when the product needs a domain-specific
  control, such as the capture progress ring or camera wheel picker.
- When a custom control is necessary, keep it iOS-like: 44 pt minimum
  touch targets, SF Symbols, Dynamic Type-compatible text, clear
  accessibility labels, and system haptics.
- Do not recreate system search bars, tab bars, segmented controls,
  modal sheets, or loading indicators with ad hoc shapes.

## Color Palette

```swift
// Backgrounds
Color.spaceBackground       // #0F172A — deep space black
Color.spaceSurface          // #1E293B — elevated surface
Color.spaceSurfaceElevated  // #334155 — double-elevated surface

// Primary
Color.starWhite             // #F8FAFC — primary text and icons
Color.appAccent             // #22C55E — app-wide active / CTA / progress accent
Color.appAccentSoft         // #86EFAC — soft accent for secondary glow/rims
Color.appAccentDim          // #4ADE80 — dimmed accent

// Accents
Color.nebulaPurple          // #A78BFA — secondary accent
Color.galaxyPink            // #F472B6 — destructive / attention state
Color.moonGold              // #FACC15 — lunar preset accent
Color.meteorTeal            // #2DD4BF — meteor / timing accent
Color.trailAmber            // #F59E0B — star-trail preset accent

// Compatibility aliases
Color.cosmicBlue            // Alias of appAccent
Color.cameraAccent          // Alias of appAccent

// Text
Color.textPrimary           // #F8FAFC — same as starWhite
Color.textSecondary         // #CBD5E1 — supporting text
Color.textTertiary          // #94A3B8 — de-emphasized
```

### Usage Rules

- Use `textSecondary` for labels that support a primary value
- Use `textTertiary` for de-emphasized metadata and icons
- Use `galaxyPink` for stop/cancel/destructive actions
- Use `appAccent` for active state, progress, selected rows, map pins, Liquid Glass tinting, and primary CTAs
- Use `appAccentSoft` / `appAccentDim` only when a secondary shade of the same theme hue is needed
- Use `nebulaPurple` for secondary highlights and gradients
- Use `moonGold`, `meteorTeal`, and `trailAmber` only for domain-specific mode/category accents
- Do not use `cosmicBlue` or `cameraAccent` in new code; they exist only as compatibility aliases so the app keeps one accent system
- Data visualization palettes such as Bortle map colors are centralized tokens, but they are not theme accents

## Typography

```swift
Font.stakkaTitle       // 28pt, bold
Font.stakkaHeadline    // 20pt, semibold
Font.stakkaBody        // 16pt, regular
Font.stakkaCaption     // 14pt, medium
Font.stakkaSmall       // 12pt, regular
```

For numbers, always use rounded design + monospacedDigit:

```swift
.font(.system(size: 22, weight: .semibold, design: .rounded))
.monospacedDigit()
```

This prevents layout shifts as numbers change.

### iOS Typography Rules

- Use semantic text styles through the `Font.stakka*` tokens so Dynamic
  Type works by default.
- Use SF Pro / SF Rounded via SwiftUI system fonts; do not introduce
  custom typefaces unless a product decision explicitly requires one.
- Use `.monospacedDigit()` for changing numeric values, timers, exposure
  values, frame counts, and progress counters.
- Prefer `.foregroundStyle(.primary/.secondary)` for ordinary system
  text when a view does not need Stakka-specific contrast tokens.
- Keep labels short. If a value plus SF Symbol is clear, do not add a
  redundant sentence label.

## Spacing

```swift
Spacing.xs   // 4pt
Spacing.sm   // 8pt
Spacing.md   // 16pt
Spacing.lg   // 24pt
Spacing.xl   // 32pt
Spacing.xxl  // 48pt
```

### Usage Pattern

```swift
// Padding
.padding(Spacing.md)
.padding(.horizontal, Spacing.lg)
.padding(.vertical, Spacing.sm)

// Stack spacing
VStack(spacing: Spacing.md)
HStack(spacing: Spacing.lg)
```

### Touch Targets

Interactive controls must meet the iOS 44 pt minimum touch target.
Spacing should leave enough room for thumbs, especially near the bottom
tab bar and camera capture controls.

## Corner Radii

All custom rounded shapes use the iOS continuous corner style. This keeps
custom cards aligned with native iOS controls and Liquid Glass surfaces.

```swift
CornerRadius.xs    // 6pt
CornerRadius.sm    // 10pt
CornerRadius.md    // 16pt
CornerRadius.lg    // 20pt
CornerRadius.xl    // 28pt
CornerRadius.xxl   // 36pt

CornerRadius.continuous  // .continuous (the style value)
```

### Usage

```swift
// Always via modifier
.continuousCorners(CornerRadius.lg)

// In shapes that need explicit style
RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)

// Never
.cornerRadius(20)
.clipShape(RoundedRectangle(cornerRadius: 20))  // missing style: .continuous
```

## Animation Presets

```swift
AnimationPreset.spring        // response: 0.4, damping: 0.75 — standard spring
AnimationPreset.springBouncy  // response: 0.5, damping: 0.65 — playful, more bounce
AnimationPreset.smooth        // easeInOut 0.35s — content transitions
AnimationPreset.quick         // easeOut 0.2s — instant feedback
AnimationPreset.gentle        // easeInOut 0.5s — slow reveal
```

### Motion Rules

- Prefer native control animations and transitions.
- Keep custom motion purposeful: state changes, capture progress,
  picker open/close, and live feedback.
- Avoid decorative motion that competes with camera preview, map tiles,
  or stacked images.
- Respect accessibility. If a future feature introduces large continuous
  motion, it should react to Reduce Motion.

### When to Use Each

| Preset        | Use For                                            |
|---------------|----------------------------------------------------|
| spring        | Scale changes, button press feedback               |
| springBouncy  | Picker open/close, menu expand/collapse            |
| smooth        | Content reveal, card appearance                    |
| quick         | Toggle state change, immediate feedback            |
| gentle        | Ambient background effects                        |

```swift
// Button press
.scaleEffect(isActive ? 1.05 : 1.0)
.animation(AnimationPreset.spring, value: isActive)

// Picker appearance
withAnimation(AnimationPreset.springBouncy) {
    viewModel.showExposurePicker = true
}

// Content reveal
.transition(.move(edge: .bottom).combined(with: .opacity))
// wrapped in withAnimation(AnimationPreset.smooth)
```

## View Modifiers

Use modifiers to centralize iOS-native behavior, not to hide one-off
styling. New modifiers should either wrap a native SwiftUI capability,
encode a repeated HIG-aligned pattern, or protect a product invariant
such as continuous corner style.

### `.continuousCorners(_:)`

Clips a view with continuous corner radii.

```swift
.continuousCorners(CornerRadius.lg)

// Equivalent to:
.clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
```

### `.glassCard()`

Compatibility helper for app-wide content cards. It now routes directly
to `.liquidGlassCard(cornerRadius: CornerRadius.lg)`, so older library,
dark-sky, and permission-primer surfaces adopt the native iOS 26 Liquid
Glass treatment without keeping a separate material style.

```swift
.glassCard()

// Applies:
// liquidGlassCard(cornerRadius: CornerRadius.lg)
```

### Liquid Glass — `.liquidGlass(...)` / `.liquidGlassCard(...)` / `.liquidGlassPill(...)`

The Liquid Glass surface treatment is the iOS 26 visual language
introduced at WWDC25 (session 323). The Stakka deployment target is
iOS 26.0, so these helpers delegate directly to the native
`glassEffect(_:in:)` API.

```swift
.liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
.liquidGlassCard(cornerRadius: CornerRadius.xxl, tint: .appAccent)
.liquidGlassPill(tint: .appAccentSoft, isInteractive: true)
```

Use native glass in this order:

1. Native button styles: `.buttonStyle(.glass)` or
   `.buttonStyle(.glassProminent)`.
2. Pure system glass helpers: `.systemGlass*` for chrome that should look
   fully native.
3. Stakka glass helpers: `.liquidGlass*` for content surfaces that need
   the app's subtle rim/highlight layer.

Arguments:

| Argument         | Meaning                                                                          |
| ---------------- | -------------------------------------------------------------------------------- |
| `in shape:`      | Clip + sample shape — typically a `RoundedRectangle`, `Capsule`, or `Circle`.    |
| `tint:`          | Optional accent color picked up by the rim + reflection (`Glass.tint(_:)`).      |
| `isInteractive:` | Opts the surface into the system's dynamic light response (`Glass.interactive`). |

Apple's `Glass` type only exposes `.regular`, `.clear`, and `.identity`
variants — there is no system-provided "prominent" surface. Visual
prominence is achieved through `tint:` (e.g. a selected control or
high-priority status surface) or, for buttons specifically, by switching
to `.buttonStyle(.glassProminent)`.

#### `GlassEffectContainer`

Adjacent Liquid Glass surfaces should be wrapped in a single
`GlassEffectContainer(spacing:)` so they share a sampling region —
**glass cannot sample other glass.** Without the container, nested or
neighboring glass surfaces produce inconsistent rim highlights.

The camera page wraps these adjacent groups:

1. The top controls bar (parameter HUD + settings button).
2. The bottom idle stack (mode selector rows + drawer + inline wheel
   picker, plus all the buttons within them).
3. The settings panel and its interval stepper.

All app-level content cards should route through `.glassCard()`,
`.systemGlassCard(...)`, or `.liquidGlassCard(...)`; do not reintroduce
`.ultraThinMaterial` card backgrounds for new UI.

### `.glow(color:radius:)`

Static glow shadow. Use sparingly for active/live state emphasis. Prefer
native tint, symbol weight, or checkmarks before adding glow.

```swift
.glow(color: .appAccent, radius: 8)

// Applies two shadows:
// shadow(color: 60% opacity, radius: r)
// shadow(color: 30% opacity, radius: r×2)
```

### `.breathingGlow(color:radius:)`

Animated glow that pulses with a 2-second cycle. Use only for live state
indicators where motion communicates ongoing work.

```swift
.breathingGlow(color: .appAccent, radius: 4)

// Uses easeInOut(duration: 2).repeatForever(autoreverses: true)
// Opacity oscillates 40%→70% on inner shadow, 20%→40% on outer
```

Use `.breathingGlow` for active capture or live stacking status only.
Use `.glow` for rare static accent icons. Do not use glow as a general
card or button treatment.

## Color Initialization

`Color` extension supports hex string initialization:

```swift
Color(hex: "#22C55E")
Color(hex: "#22C55ECC")  // with alpha
Color(hex: "F6F")        // 3-digit shorthand
```

## LiquidGlassModifier Detail

`LiquidGlassModifier` is centered on the iOS 26 `glassEffect(_:in:)`
API. Stakka adds only a very light optical rim and top-left highlight so
the surface remains legible over black camera preview and saturated map
tiles while the core refraction remains system-provided:

```swift
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content
            .background(shape.fill(lowOpacitySurface))
            .glassEffect(resolvedGlass, in: shape)
            .overlay(specularRim)
    }

    private var resolvedGlass: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if isInteractive { glass = glass.interactive() }
        return glass
    }
}
```

Depth, refraction, dynamic adaptation to underlying content, and glass
interaction behavior are delegated to the system. The helpers exist
mainly to:

1. Centralize the call site so future API tweaks land in one place.
2. Provide convenience wrappers for the most common shapes
   (`RoundedRectangle` for cards, `Capsule` for pills).
3. Document the camera page's intended Liquid Glass usage in a single
   discoverable file.

For morphing transitions between two glass surfaces, use
`@Namespace` + `glassEffectID(_:in:)` directly on the views — the
helpers don't currently wrap that, and morphing is rare on the
camera surface.

## Adding to the Design System

When adding new tokens:

1. **Colors**: Add to `extension Color` in `DesignSystem.swift`
2. **Fonts**: Add to `extension Font`
3. **Spacing**: Add to `enum Spacing`
4. **Corner radii**: Add to `enum CornerRadius`
5. **Animations**: Add to `enum AnimationPreset`
6. **Modifiers**: Create `struct XxxModifier: ViewModifier` + `extension View`

Do not hardcode values in views. Every magic number is a future maintenance burden.

Before adding a token or modifier, check whether SwiftUI already has a
native control, style, or environment value for the same job. If a native
API exists, document why Stakka still needs a wrapper.

## Design Decisions

### Why iOS-native first?

Users already understand iOS navigation, search, sheets, buttons,
pickers, lists, and tab bars. Matching those patterns lowers cognitive
load and lets astrophotography content stay primary.

### Why continuous corners?

iOS uses continuous corner curves across system UI. Using `.continuous`
keeps custom shapes visually compatible with native controls and Liquid
Glass.

### Why breathing glow on live elements?

Live capture and live stacking need a subtle ongoing-state signal.
Breathing glow is limited to those moments so motion remains useful
rather than decorative.

### Why wheel pickers over sliders?

Sliders require precise thumb placement. Wheel pickers use familiar iOS
scroll momentum. For photography parameters with specific meaningful
values, a snapping picker better matches the task than a continuous
slider.

### Why monospaced digits?

Camera controls update frequently (during capture, progress). Non-monospaced digits cause layout shifts as numbers change width. `.monospacedDigit()` keeps layouts stable.
