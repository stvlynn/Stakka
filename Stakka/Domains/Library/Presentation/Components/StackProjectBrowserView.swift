import SwiftUI

struct StackProjectBrowserView: View {
    let currentProjectID: UUID
    let summaries: [StackProjectSummary]
    let onOpen: (UUID) -> Void
    let onDuplicate: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onCreate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                if summaries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            ForEach(summaries) { summary in
                                projectCard(summary)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .navigationTitle(L10n.Library.browserTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Common.new) {
                        onCreate()
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)

            Text(L10n.Library.browserEmpty)
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            Button(L10n.Library.createProject) {
                onCreate()
                dismiss()
            }
            .buttonStyle(.glassProminent)
            .tint(.appAccent)
        }
        .padding(Spacing.xl)
    }

    private func projectCard(_ summary: StackProjectSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)

                    Text(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                if currentProjectID == summary.id {
                    Text(L10n.Common.current)
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .liquidGlassPill(tint: .appAccent)
                }
            }

            HStack(spacing: Spacing.sm) {
                badge(symbol: "square.stack.3d.up.fill", value: "\(summary.totalFrameCount)")
                badge(symbol: "sparkles", value: "\(summary.lightFrameCount)")
                if let cometMode = summary.cometMode {
                    badge(symbol: cometMode.symbolName, value: cometMode.title)
                }
            }

            HStack(spacing: Spacing.sm) {
                Button(L10n.Common.open) {
                    onOpen(summary.id)
                    dismiss()
                }
                .buttonStyle(.glassProminent)
                .tint(.appAccent)

                Button(L10n.Common.duplicate) {
                    onDuplicate(summary.id)
                    dismiss()
                }
                .buttonStyle(.glass)

                Button(L10n.Common.delete) {
                    onDelete(summary.id)
                }
                .buttonStyle(.glass)
                .tint(.galaxyPink)
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private func badge(symbol: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(value)
                .monospacedDigit()
        }
        .font(.stakkaSmall)
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .liquidGlassPill()
    }
}
