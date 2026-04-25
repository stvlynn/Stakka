import SwiftUI

struct CometModePickerView: View {
    let selectedMode: CometStackingMode?
    let onSelect: (CometStackingMode?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                modeButton(
                    title: L10n.Common.off,
                    symbol: "moonphase.waning.crescent",
                    isSelected: selectedMode == nil
                ) {
                    onSelect(nil)
                }

                ForEach(CometStackingMode.allCases) { mode in
                    modeButton(
                        title: mode.title,
                        symbol: mode.symbolName,
                        isSelected: selectedMode == mode
                    ) {
                        onSelect(mode)
                    }
                }
            }
        }
    }

    private func modeButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.stakkaCaption)
            .fontWeight(.semibold)
            .foregroundStyle(isSelected ? Color.starWhite : Color.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
            .liquidGlassCard(
                cornerRadius: CornerRadius.md,
                tint: isSelected ? Color.nebulaPurple : nil,
                isInteractive: true
            )
        }
        .buttonStyle(.plain)
    }
}
