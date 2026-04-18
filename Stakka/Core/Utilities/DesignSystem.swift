import SwiftUI

// MARK: - Design System Colors
extension Color {
    // Space Theme - Deep Black Background
    static let spaceBackground = Color(hex: "#0B0B10")
    static let spaceSurface = Color(hex: "#18181B")
    static let spaceSurfaceElevated = Color(hex: "#27272A")

    // Star White & Cosmic Blue
    static let starWhite = Color(hex: "#F8FAFC")
    static let cosmicBlue = Color(hex: "#3B82F6")
    static let cosmicBlueDim = Color(hex: "#60A5FA")

    // Accent Colors
    static let nebulaPurple = Color(hex: "#A78BFA")
    static let galaxyPink = Color(hex: "#F472B6")

    // Text
    static let textPrimary = Color(hex: "#F8FAFC")
    static let textSecondary = Color(hex: "#94A3B8")
    static let textTertiary = Color(hex: "#64748B")
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
extension Font {
    static let stakkaTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let stakkaHeadline = Font.system(size: 20, weight: .semibold, design: .default)
    static let stakkaBody = Font.system(size: 16, weight: .regular, design: .default)
    static let stakkaCaption = Font.system(size: 14, weight: .medium, design: .default)
    static let stakkaSmall = Font.system(size: 12, weight: .regular, design: .default)
}

// MARK: - Spacing
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
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

// MARK: - Glass Card Style
struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.spaceSurface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(Color.starWhite.opacity(0.1), lineWidth: 1)
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

// MARK: - Animation Presets (灵动动画)
enum AnimationPreset {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.65, blendDuration: 0)
    static let smooth = Animation.easeInOut(duration: 0.35)
    static let quick = Animation.easeOut(duration: 0.2)
    static let gentle = Animation.easeInOut(duration: 0.5)
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
}
