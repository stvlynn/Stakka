import simd
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
    case maximum

    var id: String { rawValue }

    static let manualSelectionCases: [StackingMode] = [
        .average,
        .median,
        .kappaSigma,
        .medianKappaSigma
    ]

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
        case .maximum:
            return L10n.Stacking.Mode.maximum
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
        case .maximum:
            return "arrow.up.to.line.compact"
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

    var simdMatrix: simd_double3x3 {
        simd_double3x3(rows: [
            SIMD3(m11, m12, m13),
            SIMD3(m21, m22, m23),
            SIMD3(m31, m32, m33)
        ])
    }

    var inverseMatrix: ProjectiveTransform {
        let matrix = simdMatrix
        let determinant = simd_determinant(matrix)

        guard determinant.isFinite, abs(determinant) > 0.000_001 else {
            return .identity
        }

        let inverse = matrix.inverse
        return ProjectiveTransform(
            m11: inverse[0, 0],
            m12: inverse[0, 1],
            m13: inverse[0, 2],
            m21: inverse[1, 0],
            m22: inverse[1, 1],
            m23: inverse[1, 2],
            m31: inverse[2, 0],
            m32: inverse[2, 1],
            m33: inverse[2, 2]
        )
    }

    func project(x: Double, y: Double) -> (x: Double, y: Double) {
        let vector = simdMatrix * SIMD3(x, y, 1)
        let w = vector.z == 0 ? 1 : vector.z
        return (vector.x / w, vector.y / w)
    }

    func project(point: PixelPoint) -> PixelPoint {
        let projected = project(x: point.x, y: point.y)
        return PixelPoint(x: projected.x, y: projected.y)
    }

    func scaled(
        sourceOriginalSize: PixelSize,
        sourceWorkingSize: PixelSize,
        destinationOriginalSize: PixelSize,
        destinationWorkingSize: PixelSize
    ) -> ProjectiveTransform {
        let sourceScale = simd_double3x3(rows: [
            SIMD3(sourceOriginalSize.width / sourceWorkingSize.width, 0, 0),
            SIMD3(0, sourceOriginalSize.height / sourceWorkingSize.height, 0),
            SIMD3(0, 0, 1)
        ])
        let destinationScale = simd_double3x3(rows: [
            SIMD3(destinationWorkingSize.width / destinationOriginalSize.width, 0, 0),
            SIMD3(0, destinationWorkingSize.height / destinationOriginalSize.height, 0),
            SIMD3(0, 0, 1)
        ])

        let scaledMatrix = destinationScale * simdMatrix * sourceScale
        return ProjectiveTransform(
            m11: scaledMatrix[0, 0],
            m12: scaledMatrix[0, 1],
            m13: scaledMatrix[0, 2],
            m21: scaledMatrix[1, 0],
            m22: scaledMatrix[1, 1],
            m23: scaledMatrix[1, 2],
            m31: scaledMatrix[2, 0],
            m32: scaledMatrix[2, 1],
            m33: scaledMatrix[2, 2]
        )
    }
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

struct StackFrame: Identifiable, Sendable {
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

struct StackingProject: Sendable {
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

struct StackingResult: Sendable {
    let image: UIImage
    let tiffData: Data
    let frameCount: Int
    let mode: StackingMode
    let recap: StackingRecap
}

enum LiveStackingStrategy: String, Sendable {
    case deepSky
    case starTrails
    case lunar
    case meteor

    var usesRegistration: Bool {
        switch self {
        case .deepSky, .lunar:
            return true
        case .starTrails, .meteor:
            return false
        }
    }

    var projectMode: StackingMode {
        switch self {
        case .deepSky:
            return .kappaSigma
        case .lunar:
            return .medianKappaSigma
        case .starTrails, .meteor:
            return .maximum
        }
    }

    var minimumFrameCount: Int { 2 }

    var maximumOffsetRatio: Double {
        switch self {
        case .deepSky:
            return 0.18
        case .lunar:
            return 0.28
        case .starTrails, .meteor:
            return .infinity
        }
    }

    var maximumAngleDegrees: Double {
        switch self {
        case .deepSky:
            return 5
        case .lunar:
            return 8
        case .starTrails, .meteor:
            return .infinity
        }
    }
}

struct LiveStackingConfiguration: Sendable {
    let strategy: LiveStackingStrategy
    let title: String
    let exposureTime: Double
}

enum LiveStackingPhase: Equatable, Sendable {
    case idle
    case waitingForFrames
    case stacking
    case failed
}

enum LiveStackingFrameStatus: Equatable, Sendable {
    case accepted
    case waitingForReference
    case rejected(String)
    case failed(String)
}

struct LiveStackingSnapshot: Sendable {
    let previewImage: UIImage?
    let acceptedFrameCount: Int
    let rejectedFrameCount: Int
    let totalFrameCount: Int
    let totalExposure: Double
    let phase: LiveStackingPhase
    let lastFrameStatus: LiveStackingFrameStatus
    let project: StackingProject?
}

protocol LiveStackingProcessor: Sendable {
    func reset(configuration: LiveStackingConfiguration) async
    func addFrame(
        image: UIImage,
        name: String,
        source: StackFrameSource,
        capturedAt: Date,
        exposureDuration: Double
    ) async -> LiveStackingSnapshot
    func currentProject() async -> StackingProject?
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

protocol StackingProcessor: Sendable {
    func analyze(_ project: StackingProject) async throws -> StackingProject
    func analyze(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject

    func register(_ project: StackingProject) async throws -> StackingProject
    func register(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject

    func stack(_ project: StackingProject) async throws -> StackingResult
    func stack(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingResult
}

// Default bridge: the new callback-aware methods stay optional for callers
// that don't care about progress. Implementations only need to override the
// callback variants; the no-arg overloads stay usable for compatibility.
extension StackingProcessor {
    func analyze(_ project: StackingProject) async throws -> StackingProject {
        try await analyze(project, progress: nil)
    }
    func register(_ project: StackingProject) async throws -> StackingProject {
        try await register(project, progress: nil)
    }
    func stack(_ project: StackingProject) async throws -> StackingResult {
        try await stack(project, progress: nil)
    }
}

/// Coarse-grained progress callback used to report per-frame work during
/// analyze / register / stack.
///
/// `completed` and `total` are in *frames*; call-sites should use frame
/// counts rather than derived percentages so the ViewModel can compute
/// throughput (frames/sec) and ETAs deterministically.
typealias StackingProgressReporter = @Sendable (_ stage: StackingProgressStage, _ completed: Int, _ total: Int) -> Void

enum StackingProgressStage: Sendable, Equatable {
    case analyzing
    case registering
    case stacking
}
