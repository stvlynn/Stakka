import CoreGraphics
import CoreImage
import Foundation
import simd
import UIKit
import Vision

actor ImageStacker: StackingProcessor {
    func analyze(_ project: StackingProject) async throws -> StackingProject {
        var frames = project.frames

        for index in frames.indices {
            frames[index].analysis = try analyzeFrame(frames[index].image)
            if frames[index].kind == .light {
                frames[index].registration = nil
            }
        }

        var updatedProject = project
        updatedProject.frames = frames
        updatedProject.referenceFrameID = resolveReferenceFrameID(in: updatedProject)
        if updatedProject.cometMode == nil {
            updatedProject.cometAnnotations = [:]
        }
        return updatedProject
    }

    func register(_ project: StackingProject) async throws -> StackingProject {
        let analyzedProject = try await ensureAnalyzed(project)
        let referenceFrame = try resolveReferenceFrame(in: analyzedProject)
        let referenceImage = referenceFrame.image.normalizedForProcessing(targetSize: referenceFrame.image.size)
        guard let referenceCGImage = referenceImage.cgImage else {
            throw StackingError.processingFailed(L10n.Error.referenceFrameUnreadable)
        }

        var frames = analyzedProject.frames
        for index in frames.indices where frames[index].kind == .light && frames[index].isEnabled {
            if frames[index].id == referenceFrame.id {
                frames[index].registration = FrameRegistration(
                    transform: .identity,
                    confidence: 1,
                    method: "reference"
                )
                continue
            }

            let floatingImage = frames[index].image.normalizedForProcessing(targetSize: referenceImage.size)
            guard let floatingCGImage = floatingImage.cgImage else {
                throw StackingError.processingFailed(L10n.Error.lightFrameUnreadable)
            }

            frames[index].registration = try register(
                floatingImage: floatingCGImage,
                referenceImage: referenceCGImage
            )
        }

        var updatedProject = analyzedProject
        updatedProject.frames = frames
        updatedProject.referenceFrameID = referenceFrame.id
        if updatedProject.cometMode != nil {
            updatedProject.cometAnnotations = try estimateCometAnnotations(
                in: updatedProject,
                previousAnnotations: project.cometAnnotations
            )
        } else {
            updatedProject.cometAnnotations = [:]
        }
        return updatedProject
    }

    func stack(_ project: StackingProject) async throws -> StackingResult {
        let registeredProject = try await ensureRegistered(project)
        let referenceFrame = try resolveReferenceFrame(in: registeredProject)
        let lightFrames = registeredProject.enabledLightFrames

        guard lightFrames.count >= 2 else {
            throw StackingError.notEnoughLightFrames
        }

        let referenceBuffer = try LinearRGBAImage(image: referenceFrame.image)
        let calibration = try CalibrationContext(project: registeredProject, referenceSize: referenceBuffer.size)

        let alignedBuffers = try lightFrames.map { frame -> LinearRGBAImage in
            var buffer = try LinearRGBAImage(image: frame.image, targetSize: referenceBuffer.size)
            buffer = calibration.calibrate(lightBuffer: buffer)

            if let registration = frame.registration {
                buffer = buffer.warped(using: registration.transform)
            }

            return buffer
        }

        let finalBuffer: LinearRGBAImage
        if let cometMode = registeredProject.cometMode {
            guard registeredProject.enabledFramesNeedingCometReview.isEmpty else {
                throw StackingError.cometAnnotationsRequired
            }

            let starAlignedBuffer = try combine(alignedBuffers, mode: registeredProject.mode)
            let cometAlignedBuffers = try makeCometAlignedBuffers(
                from: alignedBuffers,
                frames: lightFrames,
                in: registeredProject
            )
            let cometAlignedBuffer = try combine(cometAlignedBuffers, mode: registeredProject.mode)

            switch cometMode {
            case .standard:
                finalBuffer = starAlignedBuffer
            case .cometOnly:
                finalBuffer = cometAlignedBuffer
            case .cometAndStars:
                let cometCenter = try alignedCometPoint(for: referenceFrame, in: registeredProject)
                finalBuffer = starAlignedBuffer.blendingComet(
                    from: cometAlignedBuffer,
                    center: cometCenter,
                    radius: max(18, min(referenceBuffer.width, referenceBuffer.height) / 10)
                )
            }
        } else {
            finalBuffer = try combine(alignedBuffers, mode: registeredProject.mode)
        }

        let image = try finalBuffer.makeUIImage()
        let tiffData = try finalBuffer.makeTIFFData()
        let recap = StackingRecap(
            referenceFrameName: referenceFrame.name,
            usedLightFrameCount: lightFrames.count,
            darkFrameCount: registeredProject.frames(of: .dark).filter(\.isEnabled).count,
            flatFrameCount: registeredProject.frames(of: .flat).filter(\.isEnabled).count,
            darkFlatFrameCount: registeredProject.frames(of: .darkFlat).filter(\.isEnabled).count,
            biasFrameCount: registeredProject.frames(of: .bias).filter(\.isEnabled).count,
            cometMode: registeredProject.cometMode,
            annotatedFrameCount: registeredProject.cometAnnotations.count,
            manuallyAdjustedFrameCount: registeredProject.cometAnnotations.values.filter(\.isUserAdjusted).count
        )

        return StackingResult(
            image: image,
            tiffData: tiffData,
            frameCount: lightFrames.count,
            mode: registeredProject.mode,
            recap: recap
        )
    }
}

private extension ImageStacker {
    static let cometReviewThreshold = 0.68

    func ensureAnalyzed(_ project: StackingProject) async throws -> StackingProject {
        guard project.frames.contains(where: { $0.analysis == nil }) else {
            var updatedProject = project
            updatedProject.referenceFrameID = resolveReferenceFrameID(in: project)
            return updatedProject
        }

        return try await analyze(project)
    }

    func ensureRegistered(_ project: StackingProject) async throws -> StackingProject {
        let analyzedProject = try await ensureAnalyzed(project)
        let lightFrames = analyzedProject.enabledLightFrames
        guard lightFrames.count >= 2 else {
            throw StackingError.notEnoughLightFrames
        }

        guard lightFrames.contains(where: { $0.registration == nil }) else {
            return analyzedProject
        }

        return try await register(analyzedProject)
    }

    func resolveReferenceFrameID(in project: StackingProject) -> UUID? {
        let enabledLightFrames = project.enabledLightFrames
        guard !enabledLightFrames.isEmpty else { return nil }

        if let referenceFrameID = project.referenceFrameID,
           enabledLightFrames.contains(where: { $0.id == referenceFrameID }) {
            return referenceFrameID
        }

        return enabledLightFrames
            .max { lhs, rhs in
                (lhs.analysis?.score ?? .zero) < (rhs.analysis?.score ?? .zero)
            }?
            .id
    }

    func resolveReferenceFrame(in project: StackingProject) throws -> StackFrame {
        guard let referenceFrameID = resolveReferenceFrameID(in: project),
              let referenceFrame = project.frame(id: referenceFrameID) else {
            throw StackingError.missingReferenceFrame
        }

        return referenceFrame
    }

    func analyzeFrame(_ image: UIImage) throws -> FrameAnalysis {
        let sample = try LuminanceSample(image: image, maxDimension: 256)
        let pixels = sample.pixels
        guard !pixels.isEmpty else {
            throw StackingError.processingFailed(L10n.Error.emptyAnalysisData)
        }

        let mean = pixels.reduce(0, +) / Double(pixels.count)
        let variance = pixels.reduce(0) { partialResult, value in
            let delta = value - mean
            return partialResult + delta * delta
        } / Double(pixels.count)
        let deviation = sqrt(variance)
        let sortedPixels = pixels.sorted()
        let background = percentile(in: sortedPixels, ratio: 0.22)
        let threshold = min(0.98, max(background + 0.14, mean + (deviation * 1.8)))
        let stars = detectStars(in: sample, threshold: threshold)
        let fwhm = estimateAverageFWHM(in: sample, stars: stars)

        let averagePeak = stars.isEmpty
            ? threshold
            : stars.reduce(0) { $0 + $1.peak } / Double(stars.count)
        let contrast = max(0.001, averagePeak - background)
        let score = (Double(stars.count) * contrast * 100) / max(fwhm, 1.0)

        return FrameAnalysis(
            starCount: stars.count,
            background: background,
            fwhm: fwhm,
            score: score
        )
    }

    func detectStars(in sample: LuminanceSample, threshold: Double) -> [StarCandidate] {
        guard sample.width > 4, sample.height > 4 else { return [] }

        var stars: [StarCandidate] = []
        let step = max(1, min(sample.width, sample.height) / 128)

        for y in stride(from: 1, to: sample.height - 1, by: step) {
            for x in stride(from: 1, to: sample.width - 1, by: step) {
                let center = sample.valueAt(x: x, y: y)
                guard center >= threshold else { continue }

                let neighbors = [
                    sample.valueAt(x: x - 1, y: y - 1),
                    sample.valueAt(x: x, y: y - 1),
                    sample.valueAt(x: x + 1, y: y - 1),
                    sample.valueAt(x: x - 1, y: y),
                    sample.valueAt(x: x + 1, y: y),
                    sample.valueAt(x: x - 1, y: y + 1),
                    sample.valueAt(x: x, y: y + 1),
                    sample.valueAt(x: x + 1, y: y + 1)
                ]

                guard neighbors.allSatisfy({ center > $0 }) else { continue }
                stars.append(StarCandidate(x: x, y: y, peak: center))
            }
        }

        return stars.sorted { lhs, rhs in
            lhs.peak > rhs.peak
        }
    }

    func estimateAverageFWHM(in sample: LuminanceSample, stars: [StarCandidate]) -> Double {
        let measuredStars = stars.prefix(12)
        guard !measuredStars.isEmpty else { return 0 }

        let values = measuredStars.map { candidate in
            estimateFWHM(for: candidate, in: sample)
        }

        return values.reduce(0, +) / Double(values.count)
    }

    func estimateFWHM(for candidate: StarCandidate, in sample: LuminanceSample) -> Double {
        let halfPeak = candidate.peak * 0.5
        let left = walk(from: candidate.x, y: candidate.y, deltaX: -1, deltaY: 0, in: sample, threshold: halfPeak)
        let right = walk(from: candidate.x, y: candidate.y, deltaX: 1, deltaY: 0, in: sample, threshold: halfPeak)
        let top = walk(from: candidate.x, y: candidate.y, deltaX: 0, deltaY: -1, in: sample, threshold: halfPeak)
        let bottom = walk(from: candidate.x, y: candidate.y, deltaX: 0, deltaY: 1, in: sample, threshold: halfPeak)

        let width = Double(left + right + 1)
        let height = Double(top + bottom + 1)
        return max(1, (width + height) / 2)
    }

    func walk(
        from startX: Int,
        y startY: Int,
        deltaX: Int,
        deltaY: Int,
        in sample: LuminanceSample,
        threshold: Double
    ) -> Int {
        var distance = 0
        var x = startX + deltaX
        var y = startY + deltaY

        while x >= 0,
              x < sample.width,
              y >= 0,
              y < sample.height,
              sample.valueAt(x: x, y: y) >= threshold {
            distance += 1
            x += deltaX
            y += deltaY
        }

        return distance
    }

    func percentile(in sortedValues: [Double], ratio: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let clampedRatio = min(max(ratio, 0), 1)
        let index = Int(Double(sortedValues.count - 1) * clampedRatio)
        return sortedValues[index]
    }

    func register(floatingImage: CGImage, referenceImage: CGImage) throws -> FrameRegistration {
        do {
            let request = VNHomographicImageRegistrationRequest(targetedCGImage: floatingImage, options: [:])
            let handler = VNImageRequestHandler(cgImage: referenceImage, options: [:])
            try handler.perform([request])

            if let observation = request.results?.first {
                return FrameRegistration(
                    transform: ProjectiveTransform(matrix: observation.warpTransform),
                    confidence: Double(observation.confidence),
                    method: "homography"
                )
            }
        } catch {
            // Fall back to translational registration when Vision cannot resolve a homography.
        }

        let fallbackRequest = VNTranslationalImageRegistrationRequest(targetedCGImage: floatingImage, options: [:])
        let fallbackHandler = VNImageRequestHandler(cgImage: referenceImage, options: [:])
        try fallbackHandler.perform([fallbackRequest])

        guard let fallbackObservation = fallbackRequest.results?.first else {
            throw StackingError.processingFailed(L10n.Error.registrationFailed)
        }

        let transform = CGAffineTransform(
            translationX: fallbackObservation.alignmentTransform.tx,
            y: fallbackObservation.alignmentTransform.ty
        )

        return FrameRegistration(
            transform: ProjectiveTransform(affineTransform: transform),
            confidence: Double(fallbackObservation.confidence),
            method: "translation"
        )
    }

    func estimateCometAnnotations(
        in project: StackingProject,
        previousAnnotations: [UUID: CometAnnotation]
    ) throws -> [UUID: CometAnnotation] {
        let referenceFrame = try resolveReferenceFrame(in: project)
        let enabledLightFrames = project.enabledLightFrames
        guard enabledLightFrames.count >= 2 else { return [:] }

        let alignedFields = try enabledLightFrames.map { frame in
            try alignedCometField(
                for: frame,
                referenceFrame: referenceFrame,
                maxDimension: 256
            )
        }
        let medianField = medianBackground(for: alignedFields.map(\.field))
        let rawCandidates = alignedFields.map { alignedField in
            estimateRawCometCandidate(in: alignedField.field, background: medianField)
        }
        let smoothedCandidates = smooth(candidates: rawCandidates)

        var annotations: [UUID: CometAnnotation] = [:]
        for index in enabledLightFrames.indices {
            let frame = enabledLightFrames[index]
            let alignedField = alignedFields[index]
            let rawCandidate = rawCandidates[index]
            let smoothedCandidate = smoothedCandidates[index]

            let estimatedSourcePoint = rawCandidate.map {
                sourcePoint(
                    fromAlignedPoint: $0.point,
                    frame: frame,
                    referenceSampleSize: alignedField.sampleSize,
                    referenceFrame: referenceFrame
                )
            }
            let smoothedSourcePoint = smoothedCandidate.map {
                sourcePoint(
                    fromAlignedPoint: $0.point,
                    frame: frame,
                    referenceSampleSize: alignedField.sampleSize,
                    referenceFrame: referenceFrame
                )
            }

            let carriedAnnotation = previousAnnotations[frame.id]
            let isUserAdjusted = carriedAnnotation?.isUserAdjusted == true
            let resolvedPoint = isUserAdjusted
                ? carriedAnnotation?.resolvedPoint
                : smoothedSourcePoint ?? estimatedSourcePoint
            let confidence = smoothedCandidate?.confidence ?? rawCandidate?.confidence ?? 0
            let requiresReview = resolvedPoint == nil || (!isUserAdjusted && confidence < Self.cometReviewThreshold)

            annotations[frame.id] = CometAnnotation(
                estimatedPoint: estimatedSourcePoint,
                resolvedPoint: resolvedPoint,
                confidence: confidence,
                isUserAdjusted: isUserAdjusted,
                requiresReview: requiresReview,
                sourceFrameSize: PixelSize(
                    width: frame.image.size.width,
                    height: frame.image.size.height
                )
            )
        }

        return annotations
    }

    func alignedCometField(
        for frame: StackFrame,
        referenceFrame: StackFrame,
        maxDimension: CGFloat
    ) throws -> AlignedCometField {
        let sourceField = try LuminanceField(image: frame.image, maxDimension: maxDimension)
        let referenceField = try LuminanceField(image: referenceFrame.image, maxDimension: maxDimension)

        if frame.id == referenceFrame.id {
            return AlignedCometField(
                frameID: frame.id,
                field: referenceField,
                sampleSize: PixelSize(width: Double(referenceField.width), height: Double(referenceField.height))
            )
        }

        let registrationTransform = frame.registration?.transform ?? .identity
        let scaledTransform = registrationTransform.scaled(
            sourceOriginalSize: PixelSize(width: frame.image.size.width, height: frame.image.size.height),
            sourceWorkingSize: PixelSize(width: Double(sourceField.width), height: Double(sourceField.height)),
            destinationOriginalSize: PixelSize(width: referenceFrame.image.size.width, height: referenceFrame.image.size.height),
            destinationWorkingSize: PixelSize(width: Double(referenceField.width), height: Double(referenceField.height))
        )

        return AlignedCometField(
            frameID: frame.id,
            field: sourceField.warped(
                using: scaledTransform,
                outputWidth: referenceField.width,
                outputHeight: referenceField.height
            ),
            sampleSize: PixelSize(width: Double(referenceField.width), height: Double(referenceField.height))
        )
    }

    func medianBackground(for fields: [LuminanceField]) -> [Double] {
        guard let first = fields.first else { return [] }
        let pixelCount = first.width * first.height
        var background = Array(repeating: Double.zero, count: pixelCount)

        for pixelIndex in 0..<pixelCount {
            let samples = fields.map { $0.pixels[pixelIndex] }.sorted()
            let midpoint = samples.count / 2
            background[pixelIndex] = samples.count.isMultiple(of: 2)
                ? (samples[midpoint - 1] + samples[midpoint]) / 2
                : samples[midpoint]
        }

        return background
    }

    func estimateRawCometCandidate(
        in field: LuminanceField,
        background: [Double]
    ) -> CometCandidate? {
        guard field.width * field.height == background.count else { return nil }

        var residual = Array(repeating: Double.zero, count: background.count)
        var peakValue = 0.0
        var peakIndex = 0
        var sum = 0.0

        for index in residual.indices {
            let value = max(0, field.pixels[index] - background[index])
            residual[index] = value
            sum += value

            if value > peakValue {
                peakValue = value
                peakIndex = index
            }
        }

        let mean = sum / Double(max(residual.count, 1))
        guard peakValue > max(mean * 3.5, 0.035) else {
            return nil
        }

        let peakX = peakIndex % field.width
        let peakY = peakIndex / field.width
        let supportThreshold = peakValue * 0.45
        let radius = 7

        var weightedX = 0.0
        var weightedY = 0.0
        var totalWeight = 0.0

        for y in max(0, peakY - radius)...min(field.height - 1, peakY + radius) {
            for x in max(0, peakX - radius)...min(field.width - 1, peakX + radius) {
                let value = residual[(y * field.width) + x]
                guard value >= supportThreshold else { continue }

                weightedX += Double(x) * value
                weightedY += Double(y) * value
                totalWeight += value
            }
        }

        guard totalWeight > 0 else { return nil }

        return CometCandidate(
            point: PixelPoint(x: weightedX / totalWeight, y: weightedY / totalWeight),
            confidence: min(1, peakValue / max(mean * 8, 0.01))
        )
    }

    func smooth(candidates: [CometCandidate?]) -> [CometCandidate?] {
        guard !candidates.isEmpty else { return [] }

        var smoothed = candidates
        let reliableIndices = candidates.indices.filter { index in
            (candidates[index]?.confidence ?? 0) >= 0.45
        }

        guard !reliableIndices.isEmpty else {
            return candidates
        }

        for index in candidates.indices {
            if let candidate = candidates[index], candidate.confidence >= 0.7 {
                smoothed[index] = candidate
                continue
            }

            let previousIndex = reliableIndices.last(where: { $0 < index })
            let nextIndex = reliableIndices.first(where: { $0 > index })

            switch (previousIndex, nextIndex) {
            case let (previous?, next?):
                let previousPoint = candidates[previous]!.point
                let nextPoint = candidates[next]!.point
                let progress = Double(index - previous) / Double(next - previous)
                smoothed[index] = CometCandidate(
                    point: PixelPoint(
                        x: previousPoint.x + ((nextPoint.x - previousPoint.x) * progress),
                        y: previousPoint.y + ((nextPoint.y - previousPoint.y) * progress)
                    ),
                    confidence: min(candidates[previous]!.confidence, candidates[next]!.confidence) * 0.6
                )
            case let (previous?, nil):
                smoothed[index] = CometCandidate(
                    point: candidates[previous]!.point,
                    confidence: candidates[previous]!.confidence * 0.5
                )
            case let (nil, next?):
                smoothed[index] = CometCandidate(
                    point: candidates[next]!.point,
                    confidence: candidates[next]!.confidence * 0.5
                )
            default:
                break
            }
        }

        return smoothed
    }

    func sourcePoint(
        fromAlignedPoint alignedPoint: PixelPoint,
        frame: StackFrame,
        referenceSampleSize: PixelSize,
        referenceFrame: StackFrame
    ) -> PixelPoint {
        let referenceScaleX = referenceFrame.image.size.width / referenceSampleSize.width
        let referenceScaleY = referenceFrame.image.size.height / referenceSampleSize.height
        let referenceOriginalPoint = PixelPoint(
            x: alignedPoint.x * referenceScaleX,
            y: alignedPoint.y * referenceScaleY
        )

        guard frame.id != referenceFrame.id,
              let registration = frame.registration else {
            return referenceOriginalPoint
        }

        return registration.transform.inverseMatrix.project(point: referenceOriginalPoint)
    }

    func alignedCometPoint(
        for frame: StackFrame,
        in project: StackingProject
    ) throws -> PixelPoint {
        guard let annotation = project.cometAnnotations[frame.id],
              let sourcePoint = annotation.resolvedPoint else {
            throw StackingError.cometAnnotationsRequired
        }

        guard frame.id != project.referenceFrameID,
              let registration = frame.registration else {
            return sourcePoint
        }

        return registration.transform.project(point: sourcePoint)
    }

    func makeCometAlignedBuffers(
        from starAlignedBuffers: [LinearRGBAImage],
        frames: [StackFrame],
        in project: StackingProject
    ) throws -> [LinearRGBAImage] {
        let referenceFrame = try resolveReferenceFrame(in: project)
        let referenceCometPoint = try alignedCometPoint(for: referenceFrame, in: project)

        return try zip(frames, starAlignedBuffers).map { frame, buffer in
            let currentPoint = try alignedCometPoint(for: frame, in: project)
            return buffer.translated(
                x: referenceCometPoint.x - currentPoint.x,
                y: referenceCometPoint.y - currentPoint.y
            )
        }
    }

    func combine(_ images: [LinearRGBAImage], mode: StackingMode) throws -> LinearRGBAImage {
        guard let firstImage = images.first else {
            throw StackingError.emptyInput
        }

        let pixelsPerImage = firstImage.pixels.count
        guard images.allSatisfy({ $0.pixels.count == pixelsPerImage }) else {
            throw StackingError.incompatibleDimensions
        }

        var combinedPixels = Array(repeating: Float.zero, count: pixelsPerImage)
        let pixelCount = firstImage.width * firstImage.height

        for pixelIndex in 0..<pixelCount {
            let base = pixelIndex * 4
            for channel in 0..<3 {
                let samples = images.map { image in
                    image.pixels[base + channel]
                }

                combinedPixels[base + channel] = combine(samples, mode: mode)
            }

            combinedPixels[base + 3] = 1
        }

        return LinearRGBAImage(width: firstImage.width, height: firstImage.height, pixels: combinedPixels)
    }

    func combine(_ samples: [Float], mode: StackingMode) -> Float {
        guard !samples.isEmpty else { return 0 }

        switch mode {
        case .average:
            return samples.reduce(0, +) / Float(samples.count)
        case .median:
            return median(of: samples)
        case .kappaSigma:
            return kappaSigma(samples, replaceRejectedWithMedian: false)
        case .medianKappaSigma:
            return kappaSigma(samples, replaceRejectedWithMedian: true)
        }
    }

    func median(of samples: [Float]) -> Float {
        let sorted = samples.sorted()
        let midpoint = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }

        return sorted[midpoint]
    }

    func kappaSigma(_ samples: [Float], replaceRejectedWithMedian: Bool) -> Float {
        let kappa: Float = 2.0
        let iterations = 2
        let medianValue = median(of: samples)
        var working = samples

        for _ in 0..<iterations {
            guard !working.isEmpty else { break }

            let mean = working.reduce(0, +) / Float(working.count)
            let variance = working.reduce(0) { partialResult, sample in
                let delta = sample - mean
                return partialResult + (delta * delta)
            } / Float(working.count)
            let sigma = sqrt(variance)

            guard sigma > 0 else { break }

            if replaceRejectedWithMedian {
                working = working.map { sample in
                    abs(sample - mean) > (kappa * sigma) ? medianValue : sample
                }
            } else {
                let filtered = working.filter { sample in
                    abs(sample - mean) <= (kappa * sigma)
                }

                if filtered.isEmpty {
                    break
                }

                working = filtered
            }
        }

        return working.reduce(0, +) / Float(working.count)
    }
}

private struct StarCandidate {
    let x: Int
    let y: Int
    let peak: Double
}

private struct CometCandidate {
    let point: PixelPoint
    let confidence: Double
}

private struct AlignedCometField {
    let frameID: UUID
    let field: LuminanceField
    let sampleSize: PixelSize
}

private struct LuminanceSample {
    let width: Int
    let height: Int
    let pixels: [Double]

    init(image: UIImage, maxDimension: CGFloat) throws {
        let normalizedImage = image.normalizedForProcessing(maxDimension: maxDimension)
        guard let cgImage = normalizedImage.cgImage else {
            throw StackingError.processingFailed(L10n.Error.sampleImageFailed)
        }

        width = cgImage.width
        height = cgImage.height
        let bytes = try cgImage.rgbaBytes()
        var luminance = Array(repeating: Double.zero, count: width * height)

        for pixelIndex in 0..<(width * height) {
            let offset = pixelIndex * 4
            let red = Double(bytes[offset]) / 255
            let green = Double(bytes[offset + 1]) / 255
            let blue = Double(bytes[offset + 2]) / 255
            luminance[pixelIndex] = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }

        pixels = luminance
    }

    func valueAt(x: Int, y: Int) -> Double {
        pixels[(y * width) + x]
    }
}

private struct LuminanceField {
    let width: Int
    let height: Int
    let pixels: [Double]

    init(image: UIImage, maxDimension: CGFloat) throws {
        let sample = try LuminanceSample(image: image, maxDimension: maxDimension)
        width = sample.width
        height = sample.height
        pixels = sample.pixels
    }

    init(width: Int, height: Int, pixels: [Double]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func warped(using transform: ProjectiveTransform, outputWidth: Int, outputHeight: Int) -> LuminanceField {
        let inverse = transform.inverseMatrix
        var output = Array(repeating: Double.zero, count: outputWidth * outputHeight)

        for destinationY in 0..<outputHeight {
            for destinationX in 0..<outputWidth {
                let sourcePoint = inverse.project(x: Double(destinationX), y: Double(destinationY))
                output[(destinationY * outputWidth) + destinationX] = sample(atX: sourcePoint.x, y: sourcePoint.y)
            }
        }

        return LuminanceField(width: outputWidth, height: outputHeight, pixels: output)
    }

    private func sample(atX x: Double, y: Double) -> Double {
        guard x >= 0,
              y >= 0,
              x < Double(width - 1),
              y < Double(height - 1) else {
            return 0
        }

        let x0 = Int(floor(x))
        let y0 = Int(floor(y))
        let x1 = min(x0 + 1, width - 1)
        let y1 = min(y0 + 1, height - 1)
        let dx = x - Double(x0)
        let dy = y - Double(y0)

        let topLeft = pixels[(y0 * width) + x0]
        let topRight = pixels[(y0 * width) + x1]
        let bottomLeft = pixels[(y1 * width) + x0]
        let bottomRight = pixels[(y1 * width) + x1]

        let top = topLeft + ((topRight - topLeft) * dx)
        let bottom = bottomLeft + ((bottomRight - bottomLeft) * dx)
        return top + ((bottom - top) * dy)
    }
}

private struct CalibrationContext {
    let masterBias: LinearRGBAImage?
    let masterDark: LinearRGBAImage?
    let normalizedFlat: LinearRGBAImage?

    init(project: StackingProject, referenceSize: CGSize) throws {
        let biasFrames = project.frames(of: .bias).filter(\.isEnabled)
        let darkFrames = project.frames(of: .dark).filter(\.isEnabled)
        let flatFrames = project.frames(of: .flat).filter(\.isEnabled)
        let darkFlatFrames = project.frames(of: .darkFlat).filter(\.isEnabled)

        let biasBuffers = try CalibrationContext.loadBuffers(from: biasFrames, size: referenceSize)
        let resolvedBias = biasBuffers.isEmpty ? nil : CalibrationContext.average(of: biasBuffers)

        let darkFlatBuffers = try CalibrationContext.loadBuffers(from: darkFlatFrames, size: referenceSize)
        let calibratedDarkFlatBuffers = darkFlatBuffers.map { buffer in
            guard let resolvedBias else { return buffer }
            return buffer.subtracting(resolvedBias)
        }
        let resolvedDarkFlat = calibratedDarkFlatBuffers.isEmpty ? nil : CalibrationContext.average(of: calibratedDarkFlatBuffers)

        let darkBuffers = try CalibrationContext.loadBuffers(from: darkFrames, size: referenceSize)
        let calibratedDarkBuffers = darkBuffers.map { buffer in
            guard let resolvedBias else { return buffer }
            return buffer.subtracting(resolvedBias)
        }
        let resolvedDark = calibratedDarkBuffers.isEmpty ? nil : CalibrationContext.average(of: calibratedDarkBuffers)

        let flatBuffers = try CalibrationContext.loadBuffers(from: flatFrames, size: referenceSize)
        let calibratedFlatBuffers = flatBuffers.map { buffer in
            if let resolvedDarkFlat {
                return buffer.subtracting(resolvedDarkFlat)
            }

            guard let resolvedBias else { return buffer }
            return buffer.subtracting(resolvedBias)
        }

        if calibratedFlatBuffers.isEmpty {
            normalizedFlat = nil
        } else {
            normalizedFlat = CalibrationContext.average(of: calibratedFlatBuffers).normalizedFlat()
        }

        masterBias = resolvedBias
        masterDark = resolvedDark
    }

    func calibrate(lightBuffer: LinearRGBAImage) -> LinearRGBAImage {
        var calibrated = lightBuffer

        if let masterBias {
            calibrated = calibrated.subtracting(masterBias)
        }

        if let masterDark {
            calibrated = calibrated.subtracting(masterDark)
        }

        if let normalizedFlat {
            calibrated = calibrated.dividing(by: normalizedFlat)
        }

        return calibrated.clamped()
    }

    private static func loadBuffers(from frames: [StackFrame], size: CGSize) throws -> [LinearRGBAImage] {
        try frames.map { frame in
            try LinearRGBAImage(image: frame.image, targetSize: size)
        }
    }

    private static func average(of buffers: [LinearRGBAImage]) -> LinearRGBAImage {
        let first = buffers[0]
        let pixelCount = first.pixels.count
        var merged = Array(repeating: Float.zero, count: pixelCount)

        for buffer in buffers {
            for index in 0..<pixelCount {
                merged[index] += buffer.pixels[index]
            }
        }

        let divisor = Float(buffers.count)
        for index in 0..<pixelCount {
            merged[index] /= divisor
        }

        return LinearRGBAImage(width: first.width, height: first.height, pixels: merged)
    }
}

private struct LinearRGBAImage {
    let width: Int
    let height: Int
    let pixels: [Float]

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    init(width: Int, height: Int, pixels: [Float]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(image: UIImage, targetSize: CGSize? = nil) throws {
        let preparedImage = image.normalizedForProcessing(targetSize: targetSize)
        guard let cgImage = preparedImage.cgImage else {
            throw StackingError.processingFailed(L10n.Error.pixelReadFailed)
        }

        width = cgImage.width
        height = cgImage.height
        let rgbaBytes = try cgImage.rgbaBytes()
        var linearPixels = Array(repeating: Float.zero, count: width * height * 4)

        for pixelIndex in 0..<(width * height) {
            let offset = pixelIndex * 4
            linearPixels[offset] = Self.toLinear(channel: rgbaBytes[offset])
            linearPixels[offset + 1] = Self.toLinear(channel: rgbaBytes[offset + 1])
            linearPixels[offset + 2] = Self.toLinear(channel: rgbaBytes[offset + 2])
            linearPixels[offset + 3] = Float(rgbaBytes[offset + 3]) / 255
        }

        pixels = linearPixels
    }

    func subtracting(_ other: LinearRGBAImage) -> LinearRGBAImage {
        var result = pixels
        for index in stride(from: 0, to: result.count, by: 4) {
            result[index] = max(0, result[index] - other.pixels[index])
            result[index + 1] = max(0, result[index + 1] - other.pixels[index + 1])
            result[index + 2] = max(0, result[index + 2] - other.pixels[index + 2])
            result[index + 3] = 1
        }
        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func dividing(by flat: LinearRGBAImage) -> LinearRGBAImage {
        var result = pixels
        let epsilon: Float = 0.0001

        for index in stride(from: 0, to: result.count, by: 4) {
            result[index] = result[index] / max(flat.pixels[index], epsilon)
            result[index + 1] = result[index + 1] / max(flat.pixels[index + 1], epsilon)
            result[index + 2] = result[index + 2] / max(flat.pixels[index + 2], epsilon)
            result[index + 3] = 1
        }

        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func normalizedFlat() -> LinearRGBAImage {
        let pixelCount = width * height
        var luminanceSum: Float = 0

        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            luminanceSum += (red + green + blue) / 3
        }

        let meanLuminance = max(luminanceSum / Float(pixelCount), 0.0001)
        var result = pixels

        for index in stride(from: 0, to: result.count, by: 4) {
            result[index] = max(0.0001, result[index] / meanLuminance)
            result[index + 1] = max(0.0001, result[index + 1] / meanLuminance)
            result[index + 2] = max(0.0001, result[index + 2] / meanLuminance)
            result[index + 3] = 1
        }

        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func warped(using transform: ProjectiveTransform) -> LinearRGBAImage {
        let inverseMatrix = transform.inverseMatrix
        var result = Array(repeating: Float.zero, count: pixels.count)

        for destinationY in 0..<height {
            for destinationX in 0..<width {
                let sourcePoint = inverseMatrix.project(x: Double(destinationX), y: Double(destinationY))
                let sourceX = sourcePoint.x
                let sourceY = sourcePoint.y
                let sampled = sample(atX: sourceX, y: sourceY)
                let offset = ((destinationY * width) + destinationX) * 4
                result[offset] = sampled.0
                result[offset + 1] = sampled.1
                result[offset + 2] = sampled.2
                result[offset + 3] = 1
            }
        }

        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func translated(x: Double, y: Double) -> LinearRGBAImage {
        var result = Array(repeating: Float.zero, count: pixels.count)

        for destinationY in 0..<height {
            for destinationX in 0..<width {
                let sourceX = Double(destinationX) - x
                let sourceY = Double(destinationY) - y
                let sampled = sample(atX: sourceX, y: sourceY)
                let offset = ((destinationY * width) + destinationX) * 4
                result[offset] = sampled.0
                result[offset + 1] = sampled.1
                result[offset + 2] = sampled.2
                result[offset + 3] = 1
            }
        }

        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func blendingComet(from overlay: LinearRGBAImage, center: PixelPoint, radius: Int) -> LinearRGBAImage {
        var result = pixels
        let innerRadius = Double(radius)
        let outerRadius = Double(radius) * 1.6

        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x) - center.x
                let dy = Double(y) - center.y
                let distance = sqrt((dx * dx) + (dy * dy))

                let weight: Float
                if distance <= innerRadius {
                    weight = 1
                } else if distance >= outerRadius {
                    weight = 0
                } else {
                    let progress = (distance - innerRadius) / (outerRadius - innerRadius)
                    weight = Float(1 - progress)
                }

                guard weight > 0 else { continue }

                let offset = ((y * width) + x) * 4
                result[offset] = (pixels[offset] * (1 - weight)) + (overlay.pixels[offset] * weight)
                result[offset + 1] = (pixels[offset + 1] * (1 - weight)) + (overlay.pixels[offset + 1] * weight)
                result[offset + 2] = (pixels[offset + 2] * (1 - weight)) + (overlay.pixels[offset + 2] * weight)
                result[offset + 3] = 1
            }
        }

        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func clamped() -> LinearRGBAImage {
        var result = pixels
        for index in stride(from: 0, to: result.count, by: 4) {
            result[index] = min(max(result[index], 0), 1)
            result[index + 1] = min(max(result[index + 1], 0), 1)
            result[index + 2] = min(max(result[index + 2], 0), 1)
            result[index + 3] = 1
        }
        return LinearRGBAImage(width: width, height: height, pixels: result)
    }

    func makeUIImage() throws -> UIImage {
        var bytes = Array(repeating: UInt8.zero, count: width * height * 4)

        for pixelIndex in 0..<(width * height) {
            let offset = pixelIndex * 4
            bytes[offset] = Self.toSRGBByte(channel: pixels[offset])
            bytes[offset + 1] = Self.toSRGBByte(channel: pixels[offset + 1])
            bytes[offset + 2] = Self.toSRGBByte(channel: pixels[offset + 2])
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

    func makeTIFFData() throws -> Data {
        let bitmapData = make16BitBitmapData()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ciImage = CIImage(
            bitmapData: bitmapData,
            bytesPerRow: width * MemoryLayout<UInt16>.size * 4,
            size: CGSize(width: width, height: height),
            format: .RGBA16,
            colorSpace: colorSpace
        )

        let context = CIContext()
        guard let data = context.tiffRepresentation(
            of: ciImage,
            format: .RGBA16,
            colorSpace: colorSpace,
            options: [:]
        ) else {
            throw StackingError.processingFailed(L10n.Error.tiffExportFailed)
        }

        return data as Data
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
            bilinear(topLeft.0, topRight.0, bottomLeft.0, bottomRight.0, dx: dx, dy: dy),
            bilinear(topLeft.1, topRight.1, bottomLeft.1, bottomRight.1, dx: dx, dy: dy),
            bilinear(topLeft.2, topRight.2, bottomLeft.2, bottomRight.2, dx: dx, dy: dy)
        )
    }

    private func pixel(atX x: Int, y: Int) -> (Float, Float, Float) {
        let offset = ((y * width) + x) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2])
    }

    private func bilinear(
        _ topLeft: Float,
        _ topRight: Float,
        _ bottomLeft: Float,
        _ bottomRight: Float,
        dx: Float,
        dy: Float
    ) -> Float {
        let top = topLeft + ((topRight - topLeft) * dx)
        let bottom = bottomLeft + ((bottomRight - bottomLeft) * dx)
        return top + ((bottom - top) * dy)
    }

    private static func toLinear(channel: UInt8) -> Float {
        let normalized = Float(channel) / 255
        return pow(normalized, 2.2)
    }

    private static func toSRGBByte(channel: Float) -> UInt8 {
        let normalized = min(max(channel, 0), 1)
        return UInt8((pow(normalized, 1 / 2.2) * 255).rounded())
    }

    private func make16BitBitmapData() -> Data {
        var words = Array(repeating: UInt16.zero, count: width * height * 4)

        for pixelIndex in 0..<(width * height) {
            let offset = pixelIndex * 4
            words[offset] = Self.toSixteenBitWord(channel: pixels[offset])
            words[offset + 1] = Self.toSixteenBitWord(channel: pixels[offset + 1])
            words[offset + 2] = Self.toSixteenBitWord(channel: pixels[offset + 2])
            words[offset + 3] = .max
        }

        return Data(bytes: &words, count: words.count * MemoryLayout<UInt16>.size)
    }

    private static func toSixteenBitWord(channel: Float) -> UInt16 {
        let normalized = min(max(channel, 0), 1)
        return UInt16((normalized * Float(UInt16.max)).rounded())
    }
}

private extension ProjectiveTransform {
    init(matrix: matrix_float3x3) {
        self.init(
            m11: Double(matrix[0, 0]),
            m12: Double(matrix[0, 1]),
            m13: Double(matrix[0, 2]),
            m21: Double(matrix[1, 0]),
            m22: Double(matrix[1, 1]),
            m23: Double(matrix[1, 2]),
            m31: Double(matrix[2, 0]),
            m32: Double(matrix[2, 1]),
            m33: Double(matrix[2, 2])
        )
    }

    init(affineTransform: CGAffineTransform) {
        self.init(
            m11: Double(affineTransform.a),
            m12: Double(affineTransform.c),
            m13: Double(affineTransform.tx),
            m21: Double(affineTransform.b),
            m22: Double(affineTransform.d),
            m23: Double(affineTransform.ty),
            m31: 0,
            m32: 0,
            m33: 1
        )
    }

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

private extension UIImage {
    func normalizedForProcessing(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else {
            return normalizedForProcessing(targetSize: size)
        }

        let scale = maxDimension / maxSide
        return normalizedForProcessing(
            targetSize: CGSize(width: size.width * scale, height: size.height * scale)
        )
    }

    func normalizedForProcessing(targetSize: CGSize?) -> UIImage {
        let resolvedSize = targetSize ?? size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: resolvedSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: resolvedSize))
        }
    }
}

private extension CGImage {
    func rgbaBytes() throws -> [UInt8] {
        let width = width
        let height = height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        var bytes = Array(repeating: UInt8.zero, count: totalBytes)

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
        return bytes
    }
}
