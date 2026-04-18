import SwiftUI

struct CometModePickerView: View {
    let selectedMode: CometStackingMode?
    let onSelect: (CometStackingMode?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                modeButton(
                    title: "关闭",
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
            .background(isSelected ? Color.nebulaPurple.opacity(0.26) : Color.spaceSurface.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.nebulaPurple : Color.clear, lineWidth: 1)
            )
            .continuousCorners(CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}
