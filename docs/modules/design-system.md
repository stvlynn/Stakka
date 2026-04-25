# Design System

Stakka uses a centralized design system defined in `Core/Utilities/DesignSystem.swift`. All UI components consume from this system. No hardcoded values in views.

## File

```
Platform/DesignSystem/
├── DesignSystem.swift    # All tokens and modifiers
└── Extensions.swift      # Shared Swift / Combine helpers
```

## Color Palette

```swift
// Backgrounds
Color.spaceBackground       // #0B0B10 — deep space black
Color.spaceSurface          // #18181B — elevated surface
Color.spaceSurfaceElevated  // #27272A — double-elevated surface

// Primary
Color.starWhite             // #F8FAFC — primary text and icons
Color.cosmicBlue            // #3B82F6 — primary accent
Color.cosmicBlueDim         // #60A5FA — dimmed accent

// Accents
Color.nebulaPurple          // #A78BFA — secondary accent
Color.galaxyPink            // #F472B6 — destructive / active
Color.auroraGreen           // #86EFAC — camera CTA highlight
Color.moonGold              // #FACC15 — lunar preset accent
Color.meteorTeal            // #2DD4BF — meteor / timing accent
Color.trailAmber            // #F59E0B — star-trail preset accent

// Text
Color.textPrimary           // #F8FAFC — same as starWhite
Color.textSecondary         // #94A3B8 — supporting text
Color.textTertiary          // #64748B — de-emphasized
```

### Usage Rules

- Use `textSecondary` for labels that support a primary value
- Use `textTertiary` for de-emphasized metadata and icons
- Use `galaxyPink` for stop/cancel/destructive actions
- Use `cosmicBlue` for active state, progress, and primary CTAs
- Use `nebulaPurple` for secondary highlights and gradients
- Use `auroraGreen`, `moonGold`, `meteorTeal`, and `trailAmber` for camera mode accents only unless a new module explicitly adopts them

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

## Corner Radii

All radii use `.continuous` style. This is non-negotiable — it defines the 灵动美学 identity.

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

### `.continuousCorners(_:)`

Clips a view with continuous corner radii.

```swift
.continuousCorners(CornerRadius.lg)

// Equivalent to:
.clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
```

### `.glassCard()`

Frosted glass card effect. Used for control panels and information
cards on non-camera surfaces (library, dark sky, permission primer,
etc.).

```swift
.glassCard()

// Applies:
// 1. spaceSurface 60% opacity fill
// 2. starWhite 10% opacity 1pt border
// 3. ultraThinMaterial background blur
// All with continuous CornerRadius.lg
```

### Liquid Glass — `.liquidGlass(...)` / `.liquidGlassCard(...)` / `.liquidGlassPill(...)`

The Liquid Glass surface treatment is the iOS 26 visual language
introduced at WWDC25 (session 323). The Stakka deployment target is
iOS 26.0, so these helpers delegate directly to the native
`glassEffect(_:in:)` API.

```swift
.liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
.liquidGlassCard(cornerRadius: CornerRadius.xxl, tint: .cosmicBlue)
.liquidGlassPill(tint: .auroraGreen, isInteractive: true)
```

Arguments:

| Argument         | Meaning                                                                          |
| ---------------- | -------------------------------------------------------------------------------- |
| `in shape:`      | Clip + sample shape — typically a `RoundedRectangle`, `Capsule`, or `Circle`.    |
| `tint:`          | Optional accent color picked up by the rim + reflection (`Glass.tint(_:)`).      |
| `isInteractive:` | Opts the surface into the system's dynamic light response (`Glass.interactive`). |

Apple's `Glass` type only exposes `.regular`, `.clear`, and `.identity`
variants — there is no system-provided "prominent" surface. Visual
prominence is achieved through `tint:` (e.g. an active control button
taking on `cosmicBlue`, a capturing pill turning `galaxyPink`) or, for
buttons specifically, by switching to `.buttonStyle(.glassProminent)`.

#### `GlassEffectContainer`

Adjacent Liquid Glass surfaces should be wrapped in a single
`GlassEffectContainer(spacing:)` so they share a sampling region —
**glass cannot sample other glass.** Without the container, nested or
neighboring glass surfaces produce inconsistent rim highlights.

The camera page wraps three groups:

1. The top bar's three pills (`PRO` / `LIVE` / settings).
2. The bottom idle stack (mode selector card + drawer + inline wheel
   picker, plus all the buttons within them).
3. The settings panel + its preset rows, readout grid, and interval
   stepper.

The camera page is the canonical Liquid Glass adopter — every card,
pill, button, and panel on it routes through these helpers.

### `.glow(color:radius:)`

Static glow shadow. For icons and interactive elements at rest.

```swift
.glow(color: .cosmicBlue, radius: 8)

// Applies two shadows:
// shadow(color: 60% opacity, radius: r)
// shadow(color: 30% opacity, radius: r×2)
```

### `.breathingGlow(color:radius:)`

Animated glow that pulses with a 2-second cycle. For "live" state indicators.

```swift
.breathingGlow(color: .cosmicBlue, radius: 4)

// Uses easeInOut(duration: 2).repeatForever(autoreverses: true)
// Opacity oscillates 40%→70% on inner shadow, 20%→40% on outer
```

Use `.breathingGlow` for:
- Active capture progress indicators
- "Live" stacking numbers
- Completion confirmation icons

Use `.glow` for:
- Static accent icons
- Navigation indicators

## Color Initialization

`Color` extension supports hex string initialization:

```swift
Color(hex: "#3B82F6")
Color(hex: "#3B82F6CC")  // with alpha
Color(hex: "F6F")        // 3-digit shorthand
```

## GlassCardStyle Detail

The glass card effect uses two separate `.background()` modifiers for proper layering:

```swift
// Outer: colored tinted surface + border
.background(
    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
        .fill(Color.spaceSurface.opacity(0.6))
        .overlay(border stroke)
)
// Inner: material blur
.background(
    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
        .fill(.ultraThinMaterial)
)
```

Order matters — the colored tint sits on top of the blur.

## LiquidGlassModifier Detail

`LiquidGlassModifier` is a thin pass-through to the iOS 26
`glassEffect(_:in:)` API:

```swift
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content.glassEffect(resolvedGlass, in: shape)
    }

    private var resolvedGlass: Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if isInteractive { glass = glass.interactive() }
        return glass
    }
}
```

All visual fidelity (depth, refraction, specular response, dynamic
adaptation to underlying content, animated morphing during state
transitions) is delegated to the system. The helpers exist mainly to:

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

## Design Decisions

### Why continuous corners?

iOS uses continuous (quintic) corner curves for its own UI (Dynamic Island, Springboard, etc.). Using `.continuous` makes the app feel native rather than designed.

### Why breathing glow on live elements?

Stars twinkle. Breathing glow on active elements reinforces the astronomy metaphor while providing clear "live" state indication without color changes.

### Why wheel pickers over sliders?

Sliders require precise thumb placement. Wheel pickers use iOS's familiar scroll momentum (same as Date Picker, Time Zone selector). For photography parameters (exposure time, ISO) with specific meaningful values, a picker better matches mental models than a continuous slider.

### Why monospaced digits?

Camera controls update frequently (during capture, progress). Non-monospaced digits cause layout shifts as numbers change width. `.monospacedDigit()` keeps layouts stable.
