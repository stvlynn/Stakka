import CoreGraphics
import Foundation
import UIKit

actor ImageLiveStackingSession: LiveStackingProcessor {
    private let stacker: ImageStacker

    private var configuration: LiveStackingConfiguration?
    private var project: StackingProject?
    private var previewImage: UIImage?
    private var previewAccumulator: LiveStackPreviewAccumulator?
    private var exposureDurations: [UUID: Double] = [:]
    private var rejectedFrameCount = 0

    init(stacker: ImageStacker) {
        self.stacker = stacker
    }

    func reset(configuration: LiveStackingConfiguration) async {
        applyReset(configuration: configuration)
    }

    private func applyReset(configuration: LiveStackingConfiguration) {
        self.configuration = configuration
        project = StackingProject(
            title: configuration.title,
            mode: configuration.strategy.projectMode,
            cometMode: nil,
            referenceFrameID: nil,
            frames: []
        )
        previewImage = nil
        previewAccumulator = nil
        exposureDurations = [:]
        rejectedFrameCount = 0
    }

    func addFrame(
        image: UIImage,
        name: String,
        source: StackFrameSource,
        capturedAt _: Date,
        exposureDuration: Double
    ) async -> LiveStackingSnapshot {
        guard let configuration else {
            return snapshot(status: .failed("Live stacking session is not configured"), phase: .failed)
        }

        if project == nil {
            applyReset(configuration: configuration)
        }

        do {
            var frame = StackFrame(
                kind: .light,
                name: name,
                source: source,
                image: image,
                analysis: try await stacker.analyzeFrame(image)
            )

            if configuration.strategy.usesRegistration == false {
                frame.registration = FrameRegistration(transform: .identity, confidence: 1, method: "fixed-tripod")
            }

            project?.frames.append(frame)
            exposureDurations[frame.id] = exposureDuration
            previewImage = previewImage ?? image

            if configuration.strategy.usesRegistration {
                try await prepareRegisteredFramesIfNeeded(newFrameID: frame.id, configuration: configuration)
            } else if project?.referenceFrameID == nil {
                project?.referenceFrameID = frame.id
            }

            guard let project else {
                return snapshot(status: .failed("Live stacking project is unavailable"), phase: .failed)
            }
            let frameStatus: LiveStackingFrameStatus = project.frame(id: frame.id)?.isEnabled == false
                ? .rejected("registration")
                : .accepted

            guard project.enabledLightFrames.count >= configuration.strategy.minimumFrameCount else {
                return snapshot(
                    status: frameStatus == .accepted ? .waitingForReference : frameStatus,
                    phase: .waitingForFrames
                )
            }

            previewImage = try updateLivePreview(
                project: project,
                newFrameID: frame.id,
                configuration: configuration
            )
            return snapshot(status: frameStatus, phase: .stacking)
        } catch {
            return snapshot(status: .failed(error.localizedDescription), phase: .failed)
        }
    }

    func currentProject() async -> StackingProject? {
        project
    }
}

private extension ImageLiveStackingSession {
    func prepareRegisteredFramesIfNeeded(
        newFrameID: UUID,
        configuration: LiveStackingConfiguration
    ) async throws {
        guard var currentProject = project else { return }

        if currentProject.referenceFrameID == nil {
            guard currentProject.enabledLightFrames.count >= configuration.strategy.minimumFrameCount else {
                project = currentProject
                return
            }

            let referenceID = currentProject.enabledLightFrames
                .max { lhs, rhs in
                    (lhs.analysis?.score ?? .zero) < (rhs.analysis?.score ?? .zero)
                }?
                .id

            currentProject.referenceFrameID = referenceID
            project = currentProject
            try await registerAllEnabledFrames(configuration: configuration)
            return
        }

        try await registerFrame(id: newFrameID, configuration: configuration)
    }

    func registerAllEnabledFrames(configuration: LiveStackingConfiguration) async throws {
        guard let frameIDs = project?.enabledLightFrames.map(\.id) else { return }
        for frameID in frameIDs {
            try await registerFrame(id: frameID, configuration: configuration)
        }
    }

    func registerFrame(id frameID: UUID, configuration: LiveStackingConfiguration) async throws {
        guard var currentProject = project,
              let referenceID = currentProject.referenceFrameID,
              let index = currentProject.frames.firstIndex(where: { $0.id == frameID }),
              let referenceFrame = currentProject.frame(id: referenceID),
              let referenceCGImage = referenceFrame.image.cgImage else {
            return
        }

        if frameID == referenceID {
            currentProject.frames[index].registration = FrameRegistration(
                transform: .identity,
                confidence: 1,
                method: "reference"
            )
            currentProject.frames[index].isEnabled = true
            project = currentProject
            return
        }

        guard let floatingCGImage = currentProject.frames[index].image.cgImage else {
            throw StackingError.processingFailed(L10n.Error.lightFrameUnreadable)
        }

        let registration = await stacker.registerFrame(
            floatingImage: floatingCGImage,
            referenceImage: referenceCGImage
        )

        if rejectionReason(
            for: registration,
            frame: currentProject.frames[index],
            configuration: configuration
        ) != nil {
            currentProject.frames[index].isEnabled = false
            currentProject.frames[index].registration = registration
            rejectedFrameCount += 1
            project = currentProject
            previewImage = previewImage ?? currentProject.frames[index].image
            return
        }

        currentProject.frames[index].registration = registration
        currentProject.frames[index].isEnabled = true
        project = currentProject
    }

    func rejectionReason(
        for registration: FrameRegistration,
        frame: StackFrame,
        configuration: LiveStackingConfiguration
    ) -> String? {
        if registration.method == "identity-fallback" {
            return "registration"
        }

        let width = Double(frame.image.size.width)
        let height = Double(frame.image.size.height)
        let maxAllowedOffset = max(24, min(width, height) * configuration.strategy.maximumOffsetRatio)
        let offset = max(abs(registration.transform.translationX), abs(registration.transform.translationY))
        if offset > maxAllowedOffset {
            return "offset"
        }

        let angle = atan2(registration.transform.m21, registration.transform.m11) * 180 / Double.pi
        if abs(angle) > configuration.strategy.maximumAngleDegrees {
            return "angle"
        }

        return nil
    }

    func updateLivePreview(
        project: StackingProject,
        newFrameID: UUID,
        configuration: LiveStackingConfiguration
    ) throws -> UIImage {
        if previewAccumulator == nil || previewAccumulator?.referenceFrameID != project.referenceFrameID {
            previewAccumulator = try LiveStackPreviewAccumulator(
                project: project,
                strategy: configuration.strategy
            )
        } else if let newFrame = project.frame(id: newFrameID), newFrame.isEnabled {
            try previewAccumulator?.add(frame: newFrame)
        }

        return try previewAccumulator?.makeUIImage() ?? previewImage ?? project.enabledLightFrames.last?.image ?? UIImage()
    }

    func snapshot(status: LiveStackingFrameStatus, phase: LiveStackingPhase) -> LiveStackingSnapshot {
        let acceptedFrameCount = project?.enabledLightFrames.count ?? 0
        let fallbackExposureTime = configuration?.exposureTime ?? 0
        let totalExposure = project?.enabledLightFrames.reduce(0) { total, frame in
            total + (exposureDurations[frame.id] ?? fallbackExposureTime)
        } ?? 0

        return LiveStackingSnapshot(
            previewImage: previewImage,
            acceptedFrameCount: acceptedFrameCount,
            rejectedFrameCount: rejectedFrameCount,
            totalFrameCount: project?.frames.count ?? 0,
            totalExposure: totalExposure,
            phase: phase,
            lastFrameStatus: status,
            project: project
        )
    }
}

private struct LiveStackPreviewAccumulator {
    private static let maxPreviewDimension = 512.0

    let referenceFrameID: UUID?
    private let strategy: LiveStackingStrategy
    private let referenceOriginalSize: PixelSize
    private let targetSize: CGSize
    private var accumulatedPixels: [Float]
    private var acceptedFrameIDs: Set<UUID>
    private var frameCount: Int

    init(project: StackingProject, strategy: LiveStackingStrategy) throws {
        let resolvedReference = project.referenceFrameID.flatMap { project.frame(id: $0) }
        guard let referenceFrame = resolvedReference ?? project.enabledLightFrames.first else {
            throw StackingError.missingReferenceFrame
        }

        referenceFrameID = referenceFrame.id
        self.strategy = strategy
        referenceOriginalSize = referenceFrame.image.pixelSize
        targetSize = Self.previewSize(for: referenceFrame.image)
        accumulatedPixels = []
        acceptedFrameIDs = []
        frameCount = 0

        for frame in project.enabledLightFrames {
            try add(frame: frame)
        }
    }

    mutating func add(frame: StackFrame) throws {
        guard acceptedFrameIDs.contains(frame.id) == false else { return }

        var previewFrame = try PreviewRGBAImage(image: frame.image, targetSize: targetSize)
        if strategy.usesRegistration, let registration = frame.registration {
            let transform = registration.transform.scaled(
                sourceOriginalSize: frame.image.pixelSize,
                sourceWorkingSize: previewFrame.pixelSize,
                destinationOriginalSize: referenceOriginalSize,
                destinationWorkingSize: PixelSize(width: Double(targetSize.width), height: Double(targetSize.height))
            )
            previewFrame = previewFrame.warped(using: transform)
        }

        if accumulatedPixels.isEmpty {
            accumulatedPixels = Array(repeating: 0, count: previewFrame.pixels.count)
        }

        switch strategy.projectMode {
        case .maximum:
            if frameCount == 0 {
                accumulatedPixels = previewFrame.pixels
            } else {
                for index in accumulatedPixels.indices {
                    accumulatedPixels[index] = max(accumulatedPixels[index], previewFrame.pixels[index])
                }
            }
        case .average, .median, .kappaSigma, .medianKappaSigma:
            for index in accumulatedPixels.indices {
                accumulatedPixels[index] += previewFrame.pixels[index]
            }
        }

        acceptedFrameIDs.insert(frame.id)
        frameCount += 1
    }

    func makeUIImage() throws -> UIImage {
        guard frameCount > 0 else { throw StackingError.emptyInput }

        let pixels: [Float]
        if strategy.projectMode == .maximum {
            pixels = accumulatedPixels
        } else {
            pixels = accumulatedPixels.map { $0 / Float(frameCount) }
        }

        return try PreviewRGBAImage(
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            pixels: pixels
        )
        .makeUIImage()
    }

    private static func previewSize(for image: UIImage) -> CGSize {
        let pixelSize = image.pixelSize
        let maxSide = max(pixelSize.width, pixelSize.height)
        guard maxSide > maxPreviewDimension else {
            return CGSize(width: pixelSize.width, height: pixelSize.height)
        }

        let scale = maxPreviewDimension / maxSide
        return CGSize(
            width: max(1, (pixelSize.width * scale).rounded()),
            height: max(1, (pixelSize.height * scale).rounded())
        )
    }
}

private struct PreviewRGBAImage {
    let width: Int
    let height: Int
    let pixels: [Float]

    var pixelSize: PixelSize {
        PixelSize(width: Double(width), height: Double(height))
    }

    init(width: Int, height: Int, pixels: [Float]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(image: UIImage, targetSize: CGSize) throws {
        let renderedImage = image.renderedForLivePreview(targetSize: targetSize)
        guard let cgImage = renderedImage.cgImage else {
            throw StackingError.processingFailed(L10n.Error.lightFrameUnreadable)
        }

        width = cgImage.width
        height = cgImage.height
        pixels = try cgImage.livePreviewPixels()
    }

    func warped(using transform: ProjectiveTransform) -> PreviewRGBAImage {
        let inverseMatrix = transform.inverseMatrix
        var result = Array(repeating: Float.zero, count: pixels.count)

        for destinationY in 0..<height {
            for destinationX in 0..<width {
                let sourcePoint = inverseMatrix.project(x: Double(destinationX), y: Double(destinationY))
                let sampled = sample(atX: sourcePoint.x, y: sourcePoint.y)
                let offset = ((destinationY * width) + destinationX) * 4
                result[offset] = sampled.0
                result[offset + 1] = sampled.1
                result[offset + 2] = sampled.2
                result[offset + 3] = 1
            }
        }

        return PreviewRGBAImage(width: width, height: height, pixels: result)
    }

    func makeUIImage() throws -> UIImage {
        var bytes = Array(repeating: UInt8.zero, count: width * height * 4)
        for index in 0..<(width * height) {
            let offset = index * 4
            bytes[offset] = Self.byte(from: pixels[offset])
            bytes[offset + 1] = Self.byte(from: pixels[offset + 1])
            bytes[offset + 2] = Self.byte(from: pixels[offset + 2])
            bytes[offset + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            throw StackingError.processingFailed(L10n.Error.resultImageFailed)
        }

        return UIImage(cgImage: cgImage)
    }

    private func sample(atX x: Double, y: Double) -> (Float, Float, Float) {
        guard x >= 0,
              y >= 0,
              x < Double(width - 1),
              y < Double(height - 1) else {
            return (0, 0, 0)
        }

        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = min(x0 + 1, width - 1)
        let y1 = min(y0 + 1, height - 1)
        let dx = Float(x - Double(x0))
        let dy = Float(y - Double(y0))

        let topLeft = pixel(atX: x0, y: y0)
        let topRight = pixel(atX: x1, y: y0)
        let bottomLeft = pixel(atX: x0, y: y1)
        let bottomRight = pixel(atX: x1, y: y1)

        return (
            Self.bilinear(topLeft.0, topRight.0, bottomLeft.0, bottomRight.0, dx: dx, dy: dy),
            Self.bilinear(topLeft.1, topRight.1, bottomLeft.1, bottomRight.1, dx: dx, dy: dy),
            Self.bilinear(topLeft.2, topRight.2, bottomLeft.2, bottomRight.2, dx: dx, dy: dy)
        )
    }

    private func pixel(atX x: Int, y: Int) -> (Float, Float, Float) {
        let offset = ((y * width) + x) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2])
    }

    private static func bilinear(_ topLeft: Float, _ topRight: Float, _ bottomLeft: Float, _ bottomRight: Float, dx: Float, dy: Float) -> Float {
        let top = topLeft * (1 - dx) + topRight * dx
        let bottom = bottomLeft * (1 - dx) + bottomRight * dx
        return top * (1 - dy) + bottom * dy
    }

    private static func byte(from channel: Float) -> UInt8 {
        UInt8((min(max(channel, 0), 1) * 255).rounded())
    }
}

private extension UIImage {
    var pixelSize: PixelSize {
        if let cgImage {
            return PixelSize(width: Double(cgImage.width), height: Double(cgImage.height))
        }
        return PixelSize(width: Double(size.width), height: Double(size.height))
    }

    func renderedForLivePreview(targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

private extension CGImage {
    func livePreviewPixels() throws -> [Float] {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var bytes = Array(repeating: UInt8.zero, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw StackingError.processingFailed(L10n.Error.pixelReadFailed)
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels = Array(repeating: Float.zero, count: bytes.count)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            pixels[index] = Float(bytes[index]) / 255
            pixels[index + 1] = Float(bytes[index + 1]) / 255
            pixels[index + 2] = Float(bytes[index + 2]) / 255
            pixels[index + 3] = Float(bytes[index + 3]) / 255
        }
        return pixels
    }
}
