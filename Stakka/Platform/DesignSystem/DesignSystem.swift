import SwiftUI

// MARK: - Design System Colors
extension Color {
    // Space Theme - Deep Black Background (Enhanced contrast)
    static let spaceBackground = Color(hex: "#0F172A")  // Darker, better contrast
    static let spaceSurface = Color(hex: "#1E293B")     // Elevated surface
    static let spaceSurfaceElevated = Color(hex: "#334155")  // Higher elevation

    // Star White & Cosmic Blue (Improved accessibility)
    static let starWhite = Color(hex: "#F8FAFC")
    static let cosmicBlue = Color(hex: "#3B82F6")
    static let cosmicBlueDim = Color(hex: "#60A5FA")

    /// CTA accent green (#22C55E). Previously mis-named `cosmicBlueGlow`;
    /// renamed to match its actual hue and semantic role.
    static let ctaAccent = Color(hex: "#22C55E")

    // Accent Colors
    static let nebulaPurple = Color(hex: "#A78BFA")
    static let galaxyPink = Color(hex: "#F472B6")
    static let auroraGreen = Color(hex: "#86EFAC")
    static let moonGold = Color(hex: "#FACC15")
    static let meteorTeal = Color(hex: "#2DD4BF")
    static let trailAmber = Color(hex: "#F59E0B")

    // Text (WCAG AA compliant on dark backgrounds)
    static let textPrimary = Color(hex: "#F8FAFC")      // 15.5:1 contrast
    static let textSecondary = Color(hex: "#CBD5E1")    // 9.8:1 contrast (improved from #94A3B8)
    static let textTertiary = Color(hex: "#94A3B8")     // 5.2:1 contrast
    static let textMuted = Color(hex: "#64748B")        // 3.2:1 for decorative
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
    func glow(color: Color = .cosmicBlue, radius: CGFloat = 8) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Glass Card Style (Enhanced for better visibility)
struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.spaceSurface.opacity(0.8))  // Increased opacity for better visibility
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Color.starWhite.opacity(0.15), lineWidth: 1)  // Slightly more visible border
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCardStyle())
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

// MARK: - Continuous Corner Modifier
struct ContinuousCornerModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func continuousCorners(_ radius: CGFloat) -> some View {
        modifier(ContinuousCornerModifier(radius: radius))
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
    func breathingGlow(color: Color = .cosmicBlue, radius: CGFloat = 8) -> some View {
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
