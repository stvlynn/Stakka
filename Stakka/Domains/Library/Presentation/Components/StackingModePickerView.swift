import SwiftUI

struct StackingModePickerView: View {
    let selectedMode: StackingMode
    let onSelect: (StackingMode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(StackingMode.allCases) { mode in
                    Button {
                        onSelect(mode)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.symbolName)
                            Text(mode.title)
                        }
                        .font(.stakkaCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedMode == mode ? Color.starWhite : Color.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 10)
                        .background(selectedMode == mode ? Color.cosmicBlue.opacity(0.28) : Color.spaceSurface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(selectedMode == mode ? Color.cosmicBlue : Color.clear, lineWidth: 1)
                        )
                        .continuousCorners(CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
