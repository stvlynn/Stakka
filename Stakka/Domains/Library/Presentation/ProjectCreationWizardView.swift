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

    private let totalSteps = 3

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
                        framesStep.tag(1)
                        reviewStep.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(AnimationPreset.smooth, value: currentStep)

                    navigationButtons
                        .padding(Spacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.starWhite)
                    }
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.cosmicBlue : Color.spaceSurfaceElevated)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, Spacing.md)

            Text(L10n.Wizard.stepIndicator(current: currentStep + 1, total: totalSteps))
                .font(.stakkaSmall)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Step 1: Mode Selection

    private var modeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepMode,
                    explanation: L10n.Wizard.stepModeExplanation
                )

                VStack(spacing: Spacing.sm) {
                    ForEach(StackingMode.allCases) { mode in
                        modeCard(mode)
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func modeCard(_ mode: StackingMode) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedMode == mode ? Color.cosmicBlue : Color.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
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

                if selectedMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.cosmicBlue)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.spaceSurface.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                            .stroke(
                                selectedMode == mode ? Color.cosmicBlue.opacity(0.6) : Color.starWhite.opacity(0.08),
                                lineWidth: selectedMode == mode ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
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
        }
    }

    // MARK: - Step 2: Import Frames

    private var framesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepHeader(
                    title: L10n.Wizard.stepFrames,
                    explanation: L10n.Wizard.stepFramesExplanation
                )

                frameImportSection(
                    kind: .light,
                    items: $lightItems,
                    isRequired: true
                )

                frameImportSection(
                    kind: .dark,
                    items: $darkItems,
                    isRequired: false
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

                if lightItems.count < 2 {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.cosmicBlue)
                        Text(L10n.Wizard.lightFramesRequired)
                            .font(.stakkaSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cosmicBlue.opacity(0.08))
                    .continuousCorners(CornerRadius.md)
                }
            }
            .padding(Spacing.md)
        }
    }

    private func frameImportSection(
        kind: StackFrameKind,
        items: Binding<[PhotosPickerItem]>,
        isRequired: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(Color.cosmicBlue)
                Text(kind.title)
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)

                if isRequired {
                    Text("*")
                        .foregroundStyle(Color.galaxyPink)
                }

                Spacer()

                if !items.wrappedValue.isEmpty {
                    Text("\(items.wrappedValue.count)")
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.cosmicBlue)
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
                .foregroundStyle(Color.cosmicBlue)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Spacing.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(Color.cosmicBlue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    // MARK: - Step 3: Review

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
                .glassCard()
            }
            .padding(Spacing.md)
        }
    }

    private func reviewRow(symbol: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(Color.cosmicBlue)
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
                    .foregroundStyle(Color.starWhite)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Spacing.touchTarget)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.spaceSurfaceElevated)
                    )
                }
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
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.cosmicBlue)
                    )
                }
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
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(canCreate ? Color.cosmicBlue : Color.spaceSurfaceElevated)
                    )
                }
                .disabled(!canCreate)
            }
        }
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        lightItems.count >= 2
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

struct WizardFrameGroup {
    let kind: StackFrameKind
    let items: [PhotosPickerItem]
}
