import SwiftUI

// MARK: - Horizontal Wheel Picker

/// A compact horizontal wheel that snaps the closest item to its center
/// indicator. Designed to live directly above the controls drawer so the
/// camera preview is never occluded by a modal sheet.
///
/// Item type only needs to conform to `Hashable`; the value itself is used
/// as the SwiftUI identity for `scrollPosition` snapping.
struct HorizontalWheelPicker<Item: Hashable>: View {
    let title: String
    let items: [Item]
    let selection: Item
    let displayText: (Item) -> String
    let valueText: (Item) -> String
    let onSelect: (Item) -> Void
    let onDismiss: () -> Void

    @State private var scrollPositionID: Item?

    private let itemWidth: CGFloat = 64
    private let trackHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header

            wheel
                .frame(height: trackHeight)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .liquidGlassCard(cornerRadius: CornerRadius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityValue(valueText(selection))
        .onAppear {
            scrollPositionID = selection
        }
        .onChange(of: selection) { _, newValue in
            guard scrollPositionID != newValue else { return }
            withAnimation(AnimationPreset.smooth) {
                scrollPositionID = newValue
            }
        }
        .onChange(of: scrollPositionID) { _, newValue in
            guard let newValue, newValue != selection else { return }
            onSelect(newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(title)
                .font(.stakkaSmall)
                .fontWeight(.medium)
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.textTertiary)

            Spacer(minLength: 0)

            Text(valueText(selection))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.starWhite)

            Button {
                withAnimation(AnimationPreset.smooth) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .liquidGlass(in: Circle(), isInteractive: true)
            }
            .accessibilityLabel(L10n.Accessibility.dismissPicker)
        }
    }

    private var wheel: some View {
        GeometryReader { proxy in
            let sideInset = max(0, (proxy.size.width - itemWidth) / 2)

            ZStack {
                // Center selection indicator: a thin vertical bar that
                // anchors the eye to the snapped value.
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.cosmicBlue)
                    .frame(width: 2, height: 26)
                    .glow(color: .cosmicBlue, radius: 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(items, id: \.self) { item in
                            wheelItem(for: item)
                                .frame(width: itemWidth, height: trackHeight)
                                .id(item)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollPositionID, anchor: .center)
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.16),
                            .init(color: .black, location: 0.84),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .sensoryFeedback(.selection, trigger: scrollPositionID)
            }
        }
    }

    private func wheelItem(for item: Item) -> some View {
        let isSelected = (scrollPositionID ?? selection) == item

        return Button {
            withAnimation(AnimationPreset.smooth) {
                scrollPositionID = item
            }
        } label: {
            Text(displayText(item))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.starWhite : Color.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { content, geometry in
                    let frame = geometry.frame(in: .scrollView(axis: .horizontal))
                    let bounds = geometry.bounds(of: .scrollView(axis: .horizontal)) ?? .zero
                    let centerX = bounds.midX
                    let itemCenterX = frame.midX
                    let halfWidth = max(1, bounds.width / 2)
                    let progress = min(abs(centerX - itemCenterX) / halfWidth, 1)
                    return content
                        .opacity(1.0 - progress * 0.55)
                        .scaleEffect(1.0 - progress * 0.18)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayText(item))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
