import SwiftUI

// MARK: - Design System Colors
extension Color {
    // Space Theme - Deep Black Background (Enhanced contrast)
    static let spaceBackground = Color(hex: "#0F172A")  // Darker, better contrast
    static let spaceSurface = Color(hex: "#1E293B")     // Elevated surface
    static let spaceSurfaceElevated = Color(hex: "#334155")  // Higher elevation

    // Star White & App Accent (Improved accessibility)
    static let starWhite = Color(hex: "#F8FAFC")

    /// App-wide accent. Use for active state, progress, primary CTAs, selected
    /// rows, map pins, and Liquid Glass tinting.
    static let appAccent = Color(hex: "#22C55E")
    static let appAccentSoft = Color(hex: "#86EFAC")
    static let appAccentDim = Color(hex: "#4ADE80")

    /// Compatibility aliases. New call sites should prefer `appAccent` or
    /// `appAccentSoft` so the app does not drift into multiple accent systems.
    static let cosmicBlue = appAccent
    static let cosmicBlueDim = appAccentDim
    static let cameraAccent = appAccent
    static let cameraAccentSoft = appAccentSoft
    static let ctaAccent = appAccent

    // Accent Colors
    static let nebulaPurple = Color(hex: "#A78BFA")
    static let galaxyPink = Color(hex: "#F472B6")
    static let auroraGreen = appAccentSoft
    static let moonGold = Color(hex: "#FACC15")
    static let meteorTeal = Color(hex: "#2DD4BF")
    static let trailAmber = Color(hex: "#F59E0B")

    // Scientific / data visualization palettes. These are centralized here so
    // map layers can keep fixed domain colors without hardcoding RGB in views.
    static let bortleMapOne = Color(hex: "#00FF00")
    static let bortleMapTwo = Color(hex: "#40FF00")
    static let bortleMapThree = Color(hex: "#80FF00")
    static let bortleMapFour = Color(hex: "#FFFF00")
    static let bortleMapFive = Color(hex: "#FFD600")
    static let bortleMapSix = Color(hex: "#FFA600")
    static let bortleMapSeven = Color(hex: "#FF6B00")
    static let bortleMapEight = Color(hex: "#FF0000")
    static let bortleMapNine = Color(hex: "#FF1494")

    // Text (WCAG AA compliant on dark backgrounds)
    static let textPrimary = Color(hex: "#F8FAFC")      // 15.5:1 contrast
    static let textSecondary = Color(hex: "#CBD5E1")    // 9.8:1 contrast (improved from #94A3B8)
    static let textTertiary = Color(hex: "#94A3B8")     // 5.2:1 contrast
    static let textMuted = Color(hex: "#64748B")        // 3.2:1 for decorative

    // Liquid Glass optical layers. These are intentionally neutral and low
    // opacity: iOS 26 glass should reveal the camera preview, not behave like
    // an opaque black panel.
    static let liquidGlassSurface = Color.starWhite.opacity(0.045)
    static let liquidGlassSurfacePressed = Color.starWhite.opacity(0.075)
    static let liquidGlassRim = Color.starWhite.opacity(0.22)
    static let liquidGlassInnerRim = Color.starWhite.opacity(0.08)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
//
// Font strategy (post-review):
// - Titles use `.rounded` design to echo the "Dynamic Island" aesthetic.
// - Body / caption use the default SF Pro so Chinese glyphs render softer.
// - Numeric / technical readouts keep `.monospaced` + `.monospacedDigit()` so
//   values don't jitter while live-updating.
// - All tokens use semantic `Font.TextStyle`, enabling Dynamic Type out of the
//   box. Call-sites that need to cap the size for layout-critical screens
//   (e.g. the capture HUD) should apply `.dynamicTypeSize(...)` locally.
extension Font {
    // Titles (rounded, SF Pro)
    static let stakkaTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let stakkaHeadline = Font.system(.title2, design: .rounded).weight(.semibold)
    static let stakkaSectionTitle = Font.system(.headline, design: .rounded).weight(.semibold)

    // Body / caption (SF default — better for CJK)
    static let stakkaBody = Font.system(.body)
    static let stakkaCaption = Font.system(.subheadline).weight(.medium)
    static let stakkaSmall = Font.system(.footnote)

    // Explicit monospaced body for code / path / hex-style payloads.
    static let stakkaBodyMono = Font.system(.body, design: .monospaced)

    // Numeric display fonts with tabular spacing
    static let stakkaNumericSmall = Font.system(.subheadline, design: .monospaced)
        .monospacedDigit()
        .weight(.medium)
    static let stakkaNumeric = Font.system(.body, design: .monospaced)
        .monospacedDigit()
        .weight(.medium)
    static let stakkaNumericLarge = Font.system(.title, design: .monospaced)
        .monospacedDigit()
        .weight(.semibold)
}

// MARK: - Spacing (Enhanced for touch targets)
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    // Touch target minimum (44pt iOS guideline)
    static let touchTarget: CGFloat = 44
    static let touchTargetSpacing: CGFloat = 8  // Minimum gap between touch targets
}

// MARK: - Corner Radius (灵动曲线)
enum CornerRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
    static let continuous: RoundedCornerStyle = .continuous
}

// MARK: - Glow Effect
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func glow(color: Color = .appAccent, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

extension View {
    nonisolated func glassCard() -> some View {
        liquidGlassCard(cornerRadius: CornerRadius.lg)
    }
}

// MARK: - Liquid Glass (iOS 26 visual language)
//
// Stakka's deployment target is iOS 26.0, so this modifier delegates
// directly to the native `glassEffect(_:in:)` API introduced at WWDC25
// (session 323). Optional `tint:` colors the rim with an accent, and
// `isInteractive:` opts into the system's dynamic light response on
// tappable surfaces.
//
// Apple's `Glass` type exposes `.regular`, `.clear`, and `.identity`
// only — there is no native "prominent" surface variant. Visual
// prominence is achieved through tinting and / or by switching the
// outermost button style to `GlassProminentButtonStyle`.
//
// Adjacent glass surfaces should be wrapped in a `GlassEffectContainer`
// so they share a sampling region — see `CameraView` and
// `CameraControlsView` for canonical examples.

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content
            .background(
                shape.fill(
                    tint.map { $0.opacity(isInteractive ? 0.10 : 0.07) }
                        ?? Color.liquidGlassSurface
                )
            )
            .overlay {
                shape
                    .stroke(Color.liquidGlassInnerRim, lineWidth: 1)
                    .padding(1)
            }
            .glassEffect(resolvedGlass, in: shape)
            .overlay(alignment: .topLeading) {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.starWhite.opacity(0.42),
                                Color.starWhite.opacity(0.08),
                                tint?.opacity(0.30) ?? Color.starWhite.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.starWhite.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            }
    }

    private var resolvedGlass: Glass {
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}

struct SystemGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content
            .glassEffect(resolvedGlass, in: shape)
    }

    private var resolvedGlass: Glass {
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}

extension View {
    /// Apply the Liquid Glass surface treatment, clipped to an arbitrary
    /// shape. Prefer the convenience helpers below for the common cases.
    nonisolated func liquidGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            shape: shape,
            tint: tint,
            isInteractive: isInteractive
        ))
    }

    /// Rounded-rectangle Liquid Glass card — used for floating panels,
    /// readouts, and content surfaces.
    nonisolated func liquidGlassCard(
        cornerRadius: CGFloat = CornerRadius.lg,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        liquidGlass(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            isInteractive: isInteractive
        )
    }

    /// Capsule-shaped Liquid Glass — used for status pills, badges, and
    /// pill-shaped buttons (PRO / LIVE / settings / etc.).
    nonisolated func liquidGlassPill(
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        liquidGlass(
            in: Capsule(style: .continuous),
            tint: tint,
            isInteractive: isInteractive
        )
    }

    /// Pure iOS 26 system glass with no extra Stakka rim or highlight layers.
    /// Use this on the camera page when an element should read like native
    /// system chrome rather than a branded content card.
    nonisolated func systemGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        modifier(SystemGlassModifier(
            shape: shape,
            tint: tint,
            isInteractive: isInteractive
        ))
    }

    nonisolated func systemGlassCard(
        cornerRadius: CGFloat = CornerRadius.lg,
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        systemGlass(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            isInteractive: isInteractive
        )
    }

    nonisolated func systemGlassPill(
        tint: Color? = nil,
        isInteractive: Bool = false
    ) -> some View {
        systemGlass(
            in: Capsule(style: .continuous),
            tint: tint,
            isInteractive: isInteractive
        )
    }
}

// MARK: - Animation Presets (Optimized for micro-interactions)
enum AnimationPreset {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    static let smooth = Animation.easeInOut(duration: 0.35)
    static let quick = Animation.easeOut(duration: 0.2)      // 200ms for micro-interactions
    static let gentle = Animation.easeInOut(duration: 0.5)
    static let microInteraction = Animation.easeOut(duration: 0.15)  // 150ms for button press
    static let transition = Animation.easeInOut(duration: 0.25)      // 250ms for state changes
}

extension View {
    nonisolated func continuousCorners(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Breathing Glow Effect
struct BreathingGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isAnimating ? 0.7 : 0.4), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(isAnimating ? 0.4 : 0.2), radius: radius * 2, x: 0, y: 0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func breathingGlow(color: Color = .appAccent, radius: CGFloat = 8) -> some View {
        modifier(BreathingGlowModifier(color: color, radius: radius))
    }

    // Enhanced button style with proper touch feedback
    func interactiveButton(isPressed: Bool = false) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(AnimationPreset.microInteraction, value: isPressed)
    }

    // Minimum touch target size enforcement
    func touchTarget(minSize: CGFloat = Spacing.touchTarget) -> some View {
        self.frame(minWidth: minSize, minHeight: minSize)
    }
}
