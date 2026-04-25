import SwiftUI

struct StackingModePickerView: View {
    let selectedMode: StackingMode
    let onSelect: (StackingMode) -> Void

    private var visibleModes: [StackingMode] {
        if StackingMode.manualSelectionCases.contains(selectedMode) {
            return StackingMode.manualSelectionCases
        }

        return [selectedMode] + StackingMode.manualSelectionCases
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(visibleModes) { mode in
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
                        .liquidGlassCard(
                            cornerRadius: CornerRadius.md,
                            tint: selectedMode == mode ? Color.appAccent : nil,
                            isInteractive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
