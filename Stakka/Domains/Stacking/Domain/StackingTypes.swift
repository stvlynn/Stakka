import UIKit

enum StackFrameKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case light
    case dark
    case flat
    case darkFlat
    case bias

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return L10n.Stacking.Frame.light
        case .dark:
            return L10n.Stacking.Frame.dark
        case .flat:
            return L10n.Stacking.Frame.flat
        case .darkFlat:
            return L10n.Stacking.Frame.darkFlat
        case .bias:
            return L10n.Stacking.Frame.bias
        }
    }

    var symbolName: String {
        switch self {
        case .light:
            return "sparkles"
        case .dark:
            return "moon.fill"
        case .flat:
            return "circle.lefthalf.filled"
        case .darkFlat:
            return "camera.metering.partial"
        case .bias:
            return "waveform.path.ecg"
        }
    }

    var shortLabel: String {
        switch self {
        case .light:
            return "L"
        case .dark:
            return "D"
        case .flat:
            return "F"
        case .darkFlat:
            return "DF"
        case .bias:
            return "B"
        }
    }
}

enum StackFrameSource: Equatable, Sendable {
    case photoLibrary(assetIdentifier: String?)
    case fileURL(URL)
    case capture(identifier: String)
}

enum StackingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case average
    case median
    case kappaSigma
    case medianKappaSigma

    var id: String { rawValue }

    var title: String {
        switch self {
        case .average:
            return L10n.Stacking.Mode.average
        case .median:
            return L10n.Stacking.Mode.median
        case .kappaSigma:
            return L10n.Stacking.Mode.kappa
        case .medianKappaSigma:
            return L10n.Stacking.Mode.medianKappa
        }
    }

    var symbolName: String {
        switch self {
        case .average:
            return "sum"
        case .median:
            return "slider.horizontal.3"
        case .kappaSigma:
            return "waveform.path"
        case .medianKappaSigma:
            return "dial.medium"
        }
    }
}

enum CometStackingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case standard
    case cometOnly
    case cometAndStars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return L10n.Stacking.Comet.standard
        case .cometOnly:
            return L10n.Stacking.Comet.cometOnly
        case .cometAndStars:
            return L10n.Stacking.Comet.cometAndStars
        }
    }

    var symbolName: String {
        switch self {
        case .standard:
            return "sparkles"
        case .cometOnly:
            return "moon.stars.fill"
        case .cometAndStars:
            return "sparkles.square.filled.on.square"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return L10n.Stacking.Comet.standardDescription
        case .cometOnly:
            return L10n.Stacking.Comet.cometOnlyDescription
        case .cometAndStars:
            return L10n.Stacking.Comet.cometAndStarsDescription
        }
    }
}

struct FrameAnalysis: Codable, Equatable, Sendable {
    let starCount: Int
    let background: Double
    let fwhm: Double
    let score: Double
}

struct PixelPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct PixelSize: Codable, Equatable, Sendable {
    let width: Double
    let height: Double
}

struct ProjectiveTransform: Codable, Equatable, Sendable {
    let m11: Double
    let m12: Double
    let m13: Double
    let m21: Double
    let m22: Double
    let m23: Double
    let m31: Double
    let m32: Double
    let m33: Double

    static let identity = ProjectiveTransform(
        m11: 1, m12: 0, m13: 0,
        m21: 0, m22: 1, m23: 0,
        m31: 0, m32: 0, m33: 1
    )

    var translationX: Double { m13 }
    var translationY: Double { m23 }
}

struct FrameRegistration: Codable, Equatable, Sendable {
    let transform: ProjectiveTransform
    let confidence: Double
    let method: String
}

struct CometAnnotation: Codable, Equatable, Sendable {
    let estimatedPoint: PixelPoint?
    let resolvedPoint: PixelPoint?
    let confidence: Double
    let isUserAdjusted: Bool
    let requiresReview: Bool
    let sourceFrameSize: PixelSize
}

struct StackFrame: Identifiable {
    let id: UUID
    let kind: StackFrameKind
    let name: String
    let source: StackFrameSource
    let image: UIImage
    var isEnabled: Bool
    var analysis: FrameAnalysis?
    var registration: FrameRegistration?

    init(
        id: UUID = UUID(),
        kind: StackFrameKind,
        name: String,
        source: StackFrameSource,
        image: UIImage,
        isEnabled: Bool = true,
        analysis: FrameAnalysis? = nil,
        registration: FrameRegistration? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.source = source
        self.image = image
        self.isEnabled = isEnabled
        self.analysis = analysis
        self.registration = registration
    }
}

struct StackingProject {
    let id: UUID
    var title: String
    var mode: StackingMode
    var cometMode: CometStackingMode?
    var referenceFrameID: UUID?
    var frames: [StackFrame]
    var cometAnnotations: [UUID: CometAnnotation]

    init(
        id: UUID = UUID(),
        title: String = L10n.Project.defaultTitle,
        mode: StackingMode = .average,
        cometMode: CometStackingMode? = nil,
        referenceFrameID: UUID? = nil,
        frames: [StackFrame] = [],
        cometAnnotations: [UUID: CometAnnotation] = [:]
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.cometMode = cometMode
        self.referenceFrameID = referenceFrameID
        self.frames = frames
        self.cometAnnotations = cometAnnotations
    }

    func frames(of kind: StackFrameKind) -> [StackFrame] {
        frames.filter { $0.kind == kind }
    }

    var enabledLightFrames: [StackFrame] {
        frames.filter { $0.kind == .light && $0.isEnabled }
    }

    func frame(id: UUID) -> StackFrame? {
        frames.first { $0.id == id }
    }

    var enabledFramesNeedingCometReview: [StackFrame] {
        guard cometMode != nil else { return [] }

        return enabledLightFrames.filter { frame in
            cometAnnotations[frame.id]?.requiresReview ?? true
        }
    }
}

struct StackingRecap: Sendable {
    let referenceFrameName: String
    let usedLightFrameCount: Int
    let darkFrameCount: Int
    let flatFrameCount: Int
    let darkFlatFrameCount: Int
    let biasFrameCount: Int
    let cometMode: CometStackingMode?
    let annotatedFrameCount: Int
    let manuallyAdjustedFrameCount: Int
}

struct StackingResult {
    let image: UIImage
    let tiffData: Data
    let frameCount: Int
    let mode: StackingMode
    let recap: StackingRecap
}

enum StackingError: Error, LocalizedError {
    case emptyInput
    case notEnoughLightFrames
    case missingReferenceFrame
    case cometAnnotationsRequired
    case incompatibleDimensions
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return L10n.Error.emptyInput
        case .notEnoughLightFrames:
            return L10n.Error.notEnoughLightFrames
        case .missingReferenceFrame:
            return L10n.Error.missingReferenceFrame
        case .cometAnnotationsRequired:
            return L10n.Error.cometAnnotationsRequired
        case .incompatibleDimensions:
            return L10n.Error.incompatibleDimensions
        case .processingFailed(let message):
            return message
        }
    }
}

protocol StackingProcessor {
    func analyze(_ project: StackingProject) async throws -> StackingProject
    func register(_ project: StackingProject) async throws -> StackingProject
    func stack(_ project: StackingProject) async throws -> StackingResult
}
