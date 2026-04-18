import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct StackFrameSectionView: View {
    let kind: StackFrameKind
    let frames: [StackFrame]
    let isWorking: Bool
    let referenceFrameID: UUID?
    let cometModeEnabled: Bool
    let cometAnnotations: [UUID: CometAnnotation]
    let onImport: ([PhotosPickerItem]) async -> Void
    let onImportFiles: ([URL]) async -> Void
    let onClear: () -> Void
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void
    let onSetReference: (UUID) -> Void
    let onEditComet: (UUID) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isPresentingFileImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(kind.title, systemImage: kind.symbolName)
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Text("\(frames.count)")
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cosmicBlue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.cosmicBlue.opacity(0.12))
                    .continuousCorners(CornerRadius.md)
                    .monospacedDigit()

                Spacer()

                PhotosPicker(selection: $selectedItems, matching: .images) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.starWhite)
                        .frame(width: 34, height: 34)
                        .background(Color.cosmicBlue)
                        .continuousCorners(CornerRadius.md)
                }
                .disabled(isWorking)

                Button {
                    isPresentingFileImporter = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.starWhite)
                        .frame(width: 34, height: 34)
                        .background(Color.spaceSurfaceElevated)
                        .continuousCorners(CornerRadius.md)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                if !frames.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.galaxyPink)
                            .frame(width: 34, height: 34)
                            .background(Color.galaxyPink.opacity(0.12))
                            .continuousCorners(CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
            }

            if frames.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(frames) { frame in
                            StackFrameThumbnailCard(
                                frame: frame,
                                isReference: referenceFrameID == frame.id,
                                showsReferenceButton: kind == .light,
                                cometAnnotation: cometAnnotations[frame.id],
                                showsCometButton: kind == .light && cometModeEnabled,
                                onToggle: { onToggle(frame.id) },
                                onRemove: { onRemove(frame.id) },
                                onSetReference: { onSetReference(frame.id) },
                                onEditComet: { onEditComet(frame.id) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Spacing.md)
        .glassCard()
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }

            let importedItems = newItems
            Task {
                await onImport(importedItems)
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
        .fileImporter(
            isPresented: $isPresentingFileImporter,
            allowedContentTypes: [.image, .tiff],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }

            Task {
                await onImportFiles(urls)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)

            Text("添加 \(kind.title)")
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .background(Color.spaceSurface.opacity(0.4))
        .continuousCorners(CornerRadius.lg)
    }
}

private struct StackFrameThumbnailCard: View {
    let frame: StackFrame
    let isReference: Bool
    let showsReferenceButton: Bool
    let cometAnnotation: CometAnnotation?
    let showsCometButton: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onSetReference: () -> Void
    let onEditComet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: frame.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 144, height: 144)
                    .continuousCorners(CornerRadius.lg)
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: 8) {
                            if showsCometButton {
                                Button(action: onEditComet) {
                                    Image(systemName: cometAnnotation?.requiresReview == false ? "moon.stars.fill" : "moon.stars")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(cometAnnotation?.requiresReview == false ? Color.starWhite : Color.textSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(cometAnnotation?.requiresReview == false ? Color.nebulaPurple : Color.spaceSurface.opacity(0.8))
                                        .continuousCorners(CornerRadius.md)
                                }
                                .buttonStyle(.plain)
                            }

                            if showsReferenceButton {
                                Button(action: onSetReference) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isReference ? Color.starWhite : Color.textSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(isReference ? Color.cosmicBlue : Color.spaceSurface.opacity(0.8))
                                        .continuousCorners(CornerRadius.md)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Spacing.sm)
                    }

                HStack(spacing: 6) {
                    Button(action: onToggle) {
                        Image(systemName: frame.isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(frame.isEnabled ? Color.cosmicBlue : Color.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.galaxyPink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.sm)
            }

            Text(frame.name)
                .font(.stakkaCaption)
                .foregroundStyle(Color.starWhite)
                .lineLimit(1)

            HStack(spacing: Spacing.xs) {
                metricChip(symbol: "sparkles", value: "\(frame.analysis?.starCount ?? 0)")
                metricChip(symbol: "speedometer", value: formatted(frame.analysis?.score))
            }

            if let registration = frame.registration {
                HStack(spacing: Spacing.xs) {
                    metricChip(symbol: "arrow.left.and.right", value: signed(registration.transform.translationX))
                    metricChip(symbol: "arrow.up.and.down", value: signed(registration.transform.translationY))
                }
            }
        }
        .frame(width: 144, alignment: .leading)
        .opacity(frame.isEnabled ? 1 : 0.48)
    }

    private func metricChip(symbol: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.spaceSurface.opacity(0.55))
        .continuousCorners(CornerRadius.sm)
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "0.0" }
        return String(format: "%.1f", value)
    }

    private func signed(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }
}
