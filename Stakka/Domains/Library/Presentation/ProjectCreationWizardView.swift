import PhotosUI
import SwiftUI

struct ProjectCreationWizardView: View {
    let onCreate: (_ mode: StackingMode, _ frames: [WizardFrameGroup]) async -> Void
    let onCancel: () -> Void

    @State private var currentStep = 0
    @State private var selectedMode: StackingMode = .average
    @State private var lightItems: [PhotosPickerItem] = []
    @State private var darkItems: [PhotosPickerItem] = []
    @State private var flatItems: [PhotosPickerItem] = []
    @State private var darkFlatItems: [PhotosPickerItem] = []
    @State private var biasItems: [PhotosPickerItem] = []
    @State private var activeExplainer: StackFrameKind?
    /// Tracks whether any thumbnail is currently being dragged. When true the
    /// wizard reveals a bottom drop-to-delete zone in place of the nav
    /// buttons.
    @State private var isDragging: Bool = false
    /// Background task used to auto-clear `isDragging` if the system never
    /// fires the drop callback (e.g. user drags off-screen and releases).
    @State private var dragTimeoutTask: Task<Void, Never>?

    // 5-step flow: Mode → Light → Dark → Calibration (Flat+DarkFlat+Bias) → Review.
    // Splitting Light/Dark/Calibration reduces the cognitive load of the old
    // single-page importer (five photo pickers stacked together) and lets
    // beginners focus on one concept at a time.
    private let totalSteps = 5

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    stepIndicator
                        .padding(.top, Spacing.md)

                    TabView(selection: $currentStep) {
                        modeStep.tag(0)
                        lightStep.tag(1)
                        darkStep.tag(2)
                        calibrationStep.tag(3)
                        reviewStep.tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(AnimationPreset.smooth, value: currentStep)

                    // Bottom dock: shares the slot between the wizard's nav
                    // buttons and the red drop-to-delete zone. Sharing the
                    // slot (rather than overlaying) avoids the layering bug
                    // where the drop zone would disappear behind the
                    // navigation chrome as the user dragged towards it.
                    bottomDock
                        .padding(Spacing.md)
                        .animation(AnimationPreset.springBouncy, value: isDragging)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.starWhite)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(L10n.Common.done)
                    .accessibilityIdentifier("wizard.cancel")
                }
            }
            .sheet(item: $activeExplainer) { kind in
                FrameExplainerSheet(kind: kind)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .progressViewStyle(.linear)
                .tint(Color.appAccent)

            Text(L10n.Wizard.stepIndicator(current: currentStep + 1, total: totalSteps))
                .font(.stakkaSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Step 1: Mode Selection

    private var modeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepMode,
                    explanation: L10n.Wizard.stepModeExplanation
                )

                VStack(spacing: 0) {
                    ForEach(Array(StackingMode.manualSelectionCases.enumerated()), id: \.element.id) { index, mode in
                        modeRowButton(mode)

                        if index < StackingMode.manualSelectionCases.count - 1 {
                            Divider()
                                .overlay(Color.starWhite.opacity(0.10))
                                .padding(.leading, 58)
                        }
                    }
                }
                .systemGlassCard(cornerRadius: CornerRadius.lg)
            }
            .padding(Spacing.md)
        }
    }

    private func modeRowButton(_ mode: StackingMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            selectedMode = mode
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appAccent : Color.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.stakkaCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.starWhite)

                    Text(modeHint(for: mode))
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityValue(modeHint(for: mode))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func modeHint(for mode: StackingMode) -> String {
        switch mode {
        case .average:
            return L10n.Wizard.modeAverageHint
        case .median:
            return L10n.Wizard.modeMedianHint
        case .kappaSigma:
            return L10n.Wizard.modeKappaHint
        case .medianKappaSigma:
            return L10n.Wizard.modeMedianKappaHint
        case .maximum:
            return L10n.Wizard.modeMaximumHint
        }
    }

    // MARK: - Step 2: Light Frames (required)

    private var lightStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepLight,
                    explanation: L10n.Wizard.stepLightExplanation
                )

                frameImportSection(
                    kind: .light,
                    items: $lightItems,
                    isRequired: true
                )

                if lightItems.count < 2 {
                    requiredHint
                }
            }
            .padding(Spacing.md)
        }
    }

    private var requiredHint: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.appAccent)
            Text(L10n.Wizard.lightFramesRequired)
                .font(.stakkaSmall)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .systemGlassCard(cornerRadius: CornerRadius.lg, tint: .appAccent)
    }

    // MARK: - Step 3: Dark Frames (optional)

    private var darkStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepDark,
                    explanation: L10n.Wizard.stepDarkExplanation
                )

                frameImportSection(
                    kind: .dark,
                    items: $darkItems,
                    isRequired: false
                )
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Step 4: Calibration Frames (Flat + DarkFlat + Bias, all optional)

    private var calibrationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepCalibration,
                    explanation: L10n.Wizard.stepCalibrationExplanation
                )

                frameImportSection(
                    kind: .flat,
                    items: $flatItems,
                    isRequired: false
                )

                frameImportSection(
                    kind: .darkFlat,
                    items: $darkFlatItems,
                    isRequired: false
                )

                frameImportSection(
                    kind: .bias,
                    items: $biasItems,
                    isRequired: false
                )
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Frame Import Section

    private func frameImportSection(
        kind: StackFrameKind,
        items: Binding<[PhotosPickerItem]>,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(Color.appAccent)
                Text(kind.title)
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)

                if isRequired {
                    Text("*")
                        .foregroundStyle(Color.galaxyPink)
                } else {
                    Text(L10n.Wizard.optional)
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .systemGlassPill()
                }

                // "?" icon opens an explainer sheet. Keeps the page visually
                // calm while still teaching newcomers what each frame is for.
                Button {
                    activeExplainer = kind
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(L10n.Wizard.learnMore)

                Spacer()

                if !items.wrappedValue.isEmpty {
                    Text("\(items.wrappedValue.count)")
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.appAccent)
                        .monospacedDigit()
                }
            }

            PhotosPicker(
                selection: items,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text(L10n.Library.addFrame(kind: kind.title))
                        .font(.stakkaSmall)
                }
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Spacing.touchTarget)
            }
            .buttonStyle(.glass)
            .tint(Color.appAccent)

            // Once the user has imported photos, show a horizontally
            // scrollable strip of 64pt thumbnails. Each tile is draggable
            // (long-press) — releasing on the bottom delete zone removes it.
            WizardThumbnailStrip(
                kind: kind,
                items: items,
                onDragBegan: beginDragging
            )
        }
        .padding(Spacing.md)
        .systemGlassCard(cornerRadius: CornerRadius.lg)
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepReview,
                    explanation: L10n.Wizard.stepReviewExplanation
                )

                VStack(spacing: Spacing.sm) {
                    reviewRow(symbol: "dial.medium", label: L10n.Wizard.stepMode, value: selectedMode.title)
                    reviewRow(symbol: "sparkles", label: StackFrameKind.light.title, value: "\(lightItems.count)")
                    if !darkItems.isEmpty {
                        reviewRow(symbol: "moon.fill", label: StackFrameKind.dark.title, value: "\(darkItems.count)")
                    }
                    if !flatItems.isEmpty {
                        reviewRow(symbol: "circle.lefthalf.filled", label: StackFrameKind.flat.title, value: "\(flatItems.count)")
                    }
                    if !darkFlatItems.isEmpty {
                        reviewRow(symbol: "camera.metering.partial", label: StackFrameKind.darkFlat.title, value: "\(darkFlatItems.count)")
                    }
                    if !biasItems.isEmpty {
                        reviewRow(symbol: "waveform.path.ecg", label: StackFrameKind.bias.title, value: "\(biasItems.count)")
                    }
                }
                .padding(Spacing.md)
                .systemGlassCard(cornerRadius: CornerRadius.lg)
            }
            .padding(Spacing.md)
        }
    }

    private func reviewRow(symbol: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(Color.appAccent)
                .frame(width: 24)
            Text(label)
                .font(.stakkaCaption)
                .foregroundStyle(Color.starWhite)
            Spacer()
            Text(value)
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
        }
    }

    // MARK: - Navigation Buttons

    /// Switches the bottom dock between the standard wizard buttons and the
    /// red "drop here to remove" zone. Sharing the slot avoids the layering
    /// problem we hit before, where a separately layered drop zone could be
    /// hidden behind the safe-area chrome / nav buttons.
    @ViewBuilder
    private var bottomDock: some View {
        if isDragging {
            WizardDropToDeleteOverlay(
                onDrop: handleDropDelete,
                onDragEnded: endDragging
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            navigationButtons
                .transition(.opacity)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: Spacing.md) {
            if currentStep > 0 {
                Button {
                    withAnimation(AnimationPreset.smooth) {
                        currentStep -= 1
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(L10n.Wizard.back)
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    // Ghost / secondary style — de-emphasises "Back" so the
                    // primary forward action stays visually dominant.
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Spacing.touchTarget)
                }
                .buttonStyle(.glass)
            }

            if currentStep < totalSteps - 1 {
                Button {
                    withAnimation(AnimationPreset.smooth) {
                        currentStep += 1
                    }
                } label: {
                    HStack {
                        Text(L10n.Wizard.next)
                        Image(systemName: "chevron.right")
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Spacing.touchTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(canAdvanceFromCurrentStep ? Color.appAccent : Color.textMuted)
                .disabled(!canAdvanceFromCurrentStep)
            } else {
                Button {
                    let frames = collectFrameGroups()
                    Task {
                        await onCreate(selectedMode, frames)
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(L10n.Wizard.startStacking)
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Spacing.touchTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(canCreate ? Color.appAccent : Color.textMuted)
                .disabled(!canCreate)
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        lightItems.count >= 2
    }

    /// Only the Light step enforces a minimum count. All other optional steps
    /// let the user move forward freely.
    private var canAdvanceFromCurrentStep: Bool {
        switch currentStep {
        case 1: return lightItems.count >= 2
        default: return true
        }
    }

    private func collectFrameGroups() -> [WizardFrameGroup] {
        var groups: [WizardFrameGroup] = []
        if !lightItems.isEmpty { groups.append(WizardFrameGroup(kind: .light, items: lightItems)) }
        if !darkItems.isEmpty { groups.append(WizardFrameGroup(kind: .dark, items: darkItems)) }
        if !flatItems.isEmpty { groups.append(WizardFrameGroup(kind: .flat, items: flatItems)) }
        if !darkFlatItems.isEmpty { groups.append(WizardFrameGroup(kind: .darkFlat, items: darkFlatItems)) }
        if !biasItems.isEmpty { groups.append(WizardFrameGroup(kind: .bias, items: biasItems)) }
        return groups
    }

    /// Resolves a drag payload back to the matching items array and removes
    /// the dropped photo. Provides haptic feedback so the deletion feels
    /// tangible even though it happens off-screen.
    private func handleDropDelete(_ ref: WizardFrameItemRef) {
        guard let kind = StackFrameKind(rawValue: ref.kindRaw) else {
            endDragging()
            return
        }
        let removed: Bool
        switch kind {
        case .light: removed = removeItem(matching: ref.itemKey, from: &lightItems)
        case .dark: removed = removeItem(matching: ref.itemKey, from: &darkItems)
        case .flat: removed = removeItem(matching: ref.itemKey, from: &flatItems)
        case .darkFlat: removed = removeItem(matching: ref.itemKey, from: &darkFlatItems)
        case .bias: removed = removeItem(matching: ref.itemKey, from: &biasItems)
        }
        if removed {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        endDragging()
    }

    private func removeItem(matching key: String, from items: inout [PhotosPickerItem]) -> Bool {
        guard let index = items.firstIndex(where: { WizardThumbnailLoader.cacheKey(for: $0) == key }) else {
            return false
        }
        items.remove(at: index)
        return true
    }

    /// Called by each thumbnail when its drag preview appears. Flips the
    /// shared `isDragging` flag and arms a safety timer that auto-clears
    /// the flag if the OS never fires a drop / cancel callback (typical
    /// when the user drags off-screen).
    private func beginDragging() {
        isDragging = true
        dragTimeoutTask?.cancel()
        dragTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000) // 6s safety net
            if !Task.isCancelled { isDragging = false }
        }
    }

    private func endDragging() {
        dragTimeoutTask?.cancel()
        dragTimeoutTask = nil
        isDragging = false
    }

    private func stepHeader(title: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            Text(explanation)
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(3)
        }
    }
}

// MARK: - Explainer Sheet

private struct FrameExplainerSheet: View {
    let kind: StackFrameKind

    var body: some View {
        ZStack {
            Color.spaceBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: kind.symbolName)
                        .font(.title2)
                        .foregroundStyle(Color.appAccent)
                    Text(kind.title)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)
                }

                Text(explainer)
                    .font(.stakkaBody)
                    .foregroundStyle(Color.textSecondary)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationBackground(Color.spaceBackground)
    }

    private var explainer: String {
        switch kind {
        case .light: return L10n.Wizard.lightExplainer
        case .dark: return L10n.Wizard.darkExplainer
        case .flat: return L10n.Wizard.flatExplainer
        case .darkFlat: return L10n.Wizard.darkFlatExplainer
        case .bias: return L10n.Wizard.biasExplainer
        }
    }
}

// MARK: - Supporting Types

struct WizardFrameGroup {
    let kind: StackFrameKind
    let items: [PhotosPickerItem]
}
