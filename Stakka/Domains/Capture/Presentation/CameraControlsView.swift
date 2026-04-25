import SwiftUI

struct CameraControlsView: View {
    @ObservedObject var viewModel: CameraViewModel

    @State private var isMenuExpanded = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()

            if viewModel.isCapturing {
                floatingCaptureControl
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                idleControlStack
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .animation(AnimationPreset.smooth, value: viewModel.isCapturing)
    }

    /// Idle composition. The astro mode selector is intentionally tied to
    /// the drawer's `isMenuExpanded` state — it only reveals when the user
    /// drags the drawer up, keeping the live preview unobstructed during
    /// framing. Selecting a primary parameter (exposure / shot count) does
    /// not surface the selector; it stays a deliberate, secondary choice.
    ///
    /// All bottom-chrome glass surfaces (mode selector card + its inner
    /// title pill, the inline horizontal wheel above the drawer, the
    /// drawer card itself, and the control buttons inside the drawer)
    /// share one `GlassEffectContainer` so adjacent surfaces sample
    /// from a unified region. Without this wrap the rim highlights of
    /// nested glass elements would drift independently.
    private var idleControlStack: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            VStack(spacing: Spacing.sm) {
                if isMenuExpanded {
                    AstroModeSelectorView(
                        selectedMode: viewModel.astroMode,
                        isCapturing: viewModel.isCapturing,
                        onSelect: viewModel.applyAstroMode
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                AdvancedControlsMenu(viewModel: viewModel, isExpanded: $isMenuExpanded)
            }
        }
    }

    /// During an active capture sequence the entire drawer + mode selector
    /// is replaced by a single floating capture/stop button so the live
    /// preview reads as fullscreen with minimal chrome on top.
    private var floatingCaptureControl: some View {
        CameraCaptureButton(viewModel: viewModel)
            .padding(.bottom, Spacing.sm)
    }
}

private struct AstroModeSelectorView: View {
    let selectedMode: AstroCaptureMode
    let isCapturing: Bool
    let onSelect: (AstroCaptureMode) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            selectorTitle

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: Spacing.md) {
                        ForEach(AstroCaptureMode.allCases) { mode in
                            AstroModeCardView(
                                mode: mode,
                                isSelected: selectedMode == mode,
                                isDisabled: isCapturing
                            ) {
                                withAnimation(AnimationPreset.springBouncy) {
                                    onSelect(mode)
                                }
                            }
                            .id(mode.id)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.xs)
                }
                .onAppear {
                    proxy.scrollTo(selectedMode.id, anchor: .center)
                }
                .onChange(of: selectedMode) { _, newValue in
                    withAnimation(AnimationPreset.springBouncy) {
                        proxy.scrollTo(newValue.id, anchor: .center)
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity)
        .liquidGlassCard(cornerRadius: CornerRadius.xxl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Camera.modeSelector)
    }

    private var selectorTitle: some View {
        HStack {
            Spacer()

            Text(L10n.Camera.modeSelector)
                .font(.stakkaBodyMono)
                .foregroundStyle(Color.starWhite)
                .padding(.horizontal, Spacing.xl)
                .frame(height: 40)
                .liquidGlassPill()

            Spacer()
        }
    }
}

private struct AstroModeCardView: View {
    let mode: AstroCaptureMode
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: isSelected ? 24 : 18, weight: .bold))
                        .foregroundStyle(mode.cardForeground)
                        .accessibilityHidden(true)

                    Spacer()

                    if isSelected {
                        Circle()
                            .fill(mode.cardForeground)
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer(minLength: 0)

                Text(mode.localizedTitle)
                    .font(isSelected ? .stakkaHeadline : .stakkaCaption)
                    .foregroundStyle(mode.cardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(mode.presetCode)
                    .font(.system(size: isSelected ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(mode.cardForeground.opacity(0.92))
                    .monospacedDigit()

                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(mode.cardForeground.opacity(index < mode.intensityDots ? 0.95 : 0.22))
                            .frame(width: 10, height: 7)
                    }
                }
            }
            .padding(Spacing.sm)
            .frame(width: isSelected ? 104 : 82, height: isSelected ? 122 : 100)
            .background(
                LinearGradient(
                    colors: [
                        mode.accent,
                        mode.secondaryAccent.opacity(mode == .moon ? 0.86 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .continuousCorners(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.starWhite.opacity(0.85) : Color.starWhite.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? mode.accent.opacity(0.38) : .clear, radius: 10, y: 4)
            .opacity(isSelected ? 1 : 0.42)
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(AnimationPreset.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(L10n.Accessibility.selectAstroMode(mode.localizedTitle))
        .accessibilityValue(mode.localizedHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension AstroCaptureMode {
    var cardForeground: Color {
        switch self {
        case .moon, .starTrails:
            return .spaceBackground
        case .milkyWay, .meteor:
            return .starWhite
        }
    }

    var intensityDots: Int {
        switch self {
        case .milkyWay: return 4
        case .starTrails: return 5
        case .moon: return 2
        case .meteor: return 3
        }
    }
}
