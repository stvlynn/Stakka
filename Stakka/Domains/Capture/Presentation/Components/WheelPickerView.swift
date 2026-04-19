import SwiftUI

// MARK: - Wheel Picker Overlay
struct WheelPickerOverlay<T: Hashable>: View {
    let title: String
    let items: [T]
    let selectedItem: T
    let displayText: (T) -> String
    let onSelect: (T) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int

    init(
        title: String,
        items: [T],
        selectedItem: T,
        displayText: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedItem = selectedItem
        self.displayText = displayText
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self._selectedIndex = State(initialValue: items.firstIndex(of: selectedItem) ?? 0)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AnimationPreset.smooth) {
                        onDismiss()
                    }
                }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Spacing.md) {
                    HStack {
                        Text(title)
                            .font(.stakkaHeadline)
                            .foregroundStyle(Color.starWhite)

                        Spacer()

                        Button {
                            withAnimation(AnimationPreset.smooth) {
                                onDismiss()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .accessibilityLabel(L10n.Accessibility.dismissPicker)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)

                    Picker("", selection: $selectedIndex) {
                        ForEach(Array(items.enumerated()), id: \.element) { index, item in
                            Text(displayText(item))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.starWhite)
                                .tag(index)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)
                    .onChange(of: selectedIndex) { _, newValue in
                        onSelect(items[newValue])
                    }

                    Button {
                        withAnimation(AnimationPreset.smooth) {
                            onDismiss()
                        }
                    } label: {
                        Text(L10n.Common.confirm)
                            .font(.stakkaCaption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cosmicBlue)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
                }
                .padding(.vertical, Spacing.lg)
                .background(Color.spaceSurface)
                .continuousCorners(CornerRadius.xxl)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
