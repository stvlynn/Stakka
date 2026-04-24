import CoreGraphics
import CoreImage
import Foundation
import simd
import UIKit
import Vision

actor ImageStacker: StackingProcessor {
    func analyze(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject {
        var frames = project.frames
        let total = frames.count
        // Announce the upcoming workload even when there's nothing to do so
        // the UI can draw a 0/N state right away.
        progress?(.analyzing, 0, total)

        for index in frames.indices {
            frames[index].analysis = try analyzeFrame(frames[index].image)
            if frames[index].kind == .light {
                frames[index].registration = nil
            }
            progress?(.analyzing, index + 1, total)
        }

        var updatedProject = project
        updatedProject.frames = frames
        updatedProject.referenceFrameID = resolveReferenceFrameID(in: updatedProject)
        if updatedProject.cometMode == nil {
            updatedProject.cometAnnotations = [:]
        }
        return updatedProject
    }

    func register(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject {
        let analyzedProject = try await ensureAnalyzed(project)
        let referenceFrame = try resolveReferenceFrame(in: analyzedProject)
        let referenceImage = referenceFrame.image.normalizedForProcessing(targetSize: referenceFrame.image.size)
        guard let referenceCGImage = referenceImage.cgImage else {
            throw StackingError.processingFailed(L10n.Error.referenceFrameUnreadable)
        }

        var frames = analyzedProject.frames
        // Count all enabled light frames (including the reference itself, which
        // takes no real work but is still a unit of progress).
        let registrationIndices = frames.indices.filter { frames[$0].kind == .light && frames[$0].isEnabled }
        let total = registrationIndices.count
        var completed = 0
        progress?(.registering, 0, total)

        for index in registrationIndices {
            if frames[index].id == referenceFrame.id {
                frames[index].registration = FrameRegistration(
                    transform: .identity,
                    confidence: 1,
                    method: "reference"
                )
                completed += 1
                progress?(.registering, completed, total)
                continue
            }

            let floatingImage = frames[index].image.normalizedForProcessing(targetSize: referenceImage.size)
            guard let floatingCGImage = floatingImage.cgImage else {
                throw StackingError.processingFailed(L10n.Error.lightFrameUnreadable)
            }

            frames[index].registration = register(
                floatingImage: floatingCGImage,
                referenceImage: referenceCGImage
            )
            completed += 1
            progress?(.registering, completed, total)
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

    func stack(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingResult {
        let registeredProject = try await ensureRegistered(project)
        let referenceFrame = try resolveReferenceFrame(in: registeredProject)
        let lightFrames = registeredProject.enabledLightFrames

        guard lightFrames.count >= 2 else {
            throw StackingError.notEnoughLightFrames
        }

        let referenceBuffer = try LinearRGBAImage(image: referenceFrame.image)
        let calibration = try CalibrationContext(project: registeredProject, referenceSize: referenceBuffer.size)

        // Per-frame unit of work: calibrate + warp. Report before / after
        // each one so the UI's throughput estimate stabilises.
        let total = lightFrames.count
        progress?(.stacking, 0, total)
        var alignedBuffers: [LinearRGBAImage] = []
        alignedBuffers.reserveCapacity(total)
        for (offset, frame) in lightFrames.enumerated() {
            var buffer = try LinearRGBAImage(image: frame.image, targetSize: referenceBuffer.size)
            buffer = calibration.calibrate(lightBuffer: buffer)
            if let registration = frame.registration {
                buffer = buffer.warped(using: registration.transform)
            }
            alignedBuffers.append(buffer)
            progress?(.stacking, offset + 1, total)
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

    func renderLiveStackPreview(_ project: StackingProject, strategy: LiveStackingStrategy) async throws -> UIImage {
        let referenceFrame = try resolveReferenceFrame(in: project)
        let lightFrames = project.enabledLightFrames

        guard lightFrames.count >= strategy.minimumFrameCount else {
            throw StackingError.notEnoughLightFrames
        }

        let referenceBuffer = try LinearRGBAImage(image: referenceFrame.image)
        let calibration = try CalibrationContext(project: project, referenceSize: referenceBuffer.size)
        let buffers = try lightFrames.map { frame in
            var buffer = try LinearRGBAImage(image: frame.image, targetSize: referenceBuffer.size)
            buffer = calibration.calibrate(lightBuffer: buffer)

            if strategy.usesRegistration, let registration = frame.registration {
                buffer = buffer.warped(using: registration.transform)
            }

            return buffer
        }

        let finalBuffer = try combine(buffers, mode: strategy.projectMode)

        return try finalBuffer.makeUIImage()
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

    func detectStars(in sample: LuminanceSample, threshold: Double) -> [StarCandidate] {
        detectStars(in: sample, threshold: threshold, background: 0)
    }

    /// DSS-parity star detector (port of `DSS::registerSubRect`).
    ///
    /// For every pixel above `threshold` this routine runs the same 8-direction
    /// extension check that DeepSkyStacker performs:
    ///
    /// 1. From the candidate centre it walks up to `STARMAXSIZE` (50) pixels
    ///    in each of the 8 compass directions.
    /// 2. In every direction it must find at least **two** pixels darker
    ///    than `background + 0.25 * (center - background)` — DSS's "found two
    ///    pixels darker than 25 % of the excursion above background" rule.
    /// 3. No pixel along the walk may be brighter than the centre (with a
    ///    5 % tolerance, and at most one such pixel total).
    /// 4. The per-direction "edge radius" is the distance at which the
    ///    second darker pixel was found.  The maximum spread across the 8
    ///    directions must stay within a `deltaRadius` tolerance (0…3,
    ///    swept from tight to loose to catch both crisp and slightly
    ///    elongated stars) and the largest edge radius must exceed 2
    ///    (min-size check).
    /// 5. A hot-pixel veto rejects centres where ≥ 7 of the 8 immediate
    ///    neighbours are darker than the centre excursion and ≥ 4 are
    ///    darker than 0.6 × that excursion.
    /// 6. A candidate overlapping an already-accepted star
    ///    (`dist < (r1 + r2) * RadiusFactor`, `RadiusFactor = 2.35 / 1.5`)
    ///    is discarded — this is how DSS collapses 3×3 + 2×2 touching
    ///    blobs into a single star rather than merging by geometry.
    func detectStars(
        in sample: LuminanceSample,
        threshold: Double,
        background: Double
    ) -> [StarCandidate] {
        guard sample.width > 4, sample.height > 4 else { return [] }

        let starMaxSize = 50
        let radiusFactor = 2.35 / 1.5
        let maxDeltaRadius = 3

        // 8 compass directions (dx, dy).
        let directions: [(Int, Int)] = [
            ( 0, -1), ( 1,  0), ( 0,  1), (-1,  0),
            ( 1, -1), ( 1,  1), (-1,  1), (-1, -1)
        ]

        // Accept candidates peak-first so overlap suppression deterministically
        // keeps the brightest local maximum.
        var raw: [(x: Int, y: Int, peak: Double)] = []
        raw.reserveCapacity(sample.width * sample.height / 16)
        for y in 1..<(sample.height - 1) {
            for x in 1..<(sample.width - 1) {
                let centre = sample.valueAt(x: x, y: y)
                if centre >= threshold {
                    raw.append((x, y, centre))
                }
            }
        }
        raw.sort { $0.peak > $1.peak }

        var accepted: [StarCandidate] = []

        candidateLoop: for candidate in raw {
            let centre = candidate.peak
            let excursion = centre - background
            guard excursion > 0 else { continue }

            // Reject hot pixels: 8 immediate neighbours mostly darker than
            // the excursion (DSS RegisterCore.cpp hot-pixel test).
            var darkerThanFull = 0
            var darkerThan60 = 0
            for (dx, dy) in directions {
                let nx = candidate.x + dx
                let ny = candidate.y + dy
                guard nx >= 0, nx < sample.width, ny >= 0, ny < sample.height else { continue }
                let n = sample.valueAt(x: nx, y: ny) - background
                if n < excursion { darkerThanFull += 1 }
                if n < 0.6 * excursion { darkerThan60 += 1 }
            }
            if darkerThanFull >= 7 && darkerThan60 >= 4 {
                // All 8 neighbours collapse sharply — a single hot pixel.
                // DSS requires that the candidate also expand outwards to
                // survive, so let the extension check do the final word.
                if darkerThan60 == 8 {
                    continue candidateLoop
                }
            }

            // 8-direction extension check with sweeping deltaRadius.
            var bestEdges: [Int]?
            var bestMax = 0

            for deltaRadius in 0...maxDeltaRadius {
                var edges = [Int](repeating: 0, count: directions.count)
                var brighterPixels = 0
                var ok = true

                for (dirIndex, direction) in directions.enumerated() {
                    let darkThreshold = background + 0.25 * excursion
                    var darkerFound = 0
                    var edgeRadius = 0
                    var step = 1

                    walkLoop: while step <= starMaxSize {
                        let px = candidate.x + direction.0 * step
                        let py = candidate.y + direction.1 * step
                        guard px >= 0, px < sample.width, py >= 0, py < sample.height else {
                            ok = false
                            break walkLoop
                        }
                        let value = sample.valueAt(x: px, y: py)
                        if value > centre * 1.05 {
                            brighterPixels += 1
                            if brighterPixels > 1 {
                                ok = false
                                break walkLoop
                            }
                        }
                        if value < darkThreshold {
                            darkerFound += 1
                            if darkerFound == 2 {
                                edgeRadius = step
                                break walkLoop
                            }
                        }
                        step += 1
                    }

                    if !ok || darkerFound < 2 {
                        ok = false
                        break
                    }
                    edges[dirIndex] = edgeRadius
                }

                guard ok else { continue }

                let maxEdge = edges.max() ?? 0
                let minEdge = edges.min() ?? 0
                // Min-size check: star must span at least 3 pixels total.
                guard maxEdge > 2 else { continue }
                // Roundness check: spread across directions within tolerance.
                guard (maxEdge - minEdge) <= deltaRadius else { continue }

                // Perpendicular-diameter ratio check for small stars.
                if maxEdge < 10 {
                    let horizontalDiameter = edges[1] + edges[3] + 1      // E + W
                    let verticalDiameter = edges[0] + edges[2] + 1        // N + S
                    let larger = Double(max(horizontalDiameter, verticalDiameter))
                    let smaller = Double(max(1, min(horizontalDiameter, verticalDiameter)))
                    guard larger / smaller <= 1.5 else { continue }
                }

                bestEdges = edges
                bestMax = maxEdge
                break
            }

            guard let edges = bestEdges else { continue }

            // Mean radius across the 8 directions (DSS uses this for the
            // overlap test and the FWHM derivation).
            let meanRadius = Double(edges.reduce(0, +)) / Double(edges.count)
            _ = bestMax

            // Overlap suppression against previously-accepted brighter stars.
            for existing in accepted {
                let dx = Double(candidate.x - existing.x)
                let dy = Double(candidate.y - existing.y)
                let distance = (dx * dx + dy * dy).squareRoot()
                let minSeparation = (existing.meanRadius + meanRadius) * radiusFactor
                if distance < max(minSeparation, 1) {
                    continue candidateLoop
                }
            }

            accepted.append(StarCandidate(
                x: candidate.x,
                y: candidate.y,
                peak: centre,
                meanRadius: meanRadius
            ))
        }

        return accepted
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

    func register(floatingImage: CGImage, referenceImage: CGImage) -> FrameRegistration {
        // Vision's registration requests allocate a `VNImageSignature` object
        // internally. On low-memory environments (most notably the iOS
        // Simulator) this allocation can fail outright with
        // "Error while trying to allocate VNImageSignature object". We can't
        // prevent that, but we can refuse to surface it as a user-visible
        // error: stacking with an identity transform still produces a valid
        // (if un-aligned) output, which beats hard-failing the whole project.
        //
        // Strategy — three layers, each one silently falls through:
        //   1. VNHomographicImageRegistrationRequest  (best alignment)
        //   2. VNTranslationalImageRegistrationRequest (shift-only)
        //   3. identity transform                       (last resort)

        // Downsample oversized images before feeding Vision. Full-resolution
        // frames from modern iPhones (48MP+) routinely exhaust the Simulator
        // heap; 2048px on the long edge is plenty for feature matching.
        let downsampleTarget: CGFloat = 2048
        let floating = Self.downsampledCGImage(floatingImage, maxLongEdge: downsampleTarget) ?? floatingImage
        let reference = Self.downsampledCGImage(referenceImage, maxLongEdge: downsampleTarget) ?? referenceImage

        if let homography = try? Self.performHomographicRegistration(
            floatingImage: floating,
            referenceImage: reference
        ) {
            return homography
        }

        if let translation = try? Self.performTranslationalRegistration(
            floatingImage: floating,
            referenceImage: reference
        ) {
            return translation
        }

        // Last resort: assume the frames are already aligned. Confidence is
        // set to 0 so downstream heuristics (reference-frame scoring, quality
        // reporting) can still tell that registration didn't succeed.
        return FrameRegistration(
            transform: .identity,
            confidence: 0,
            method: "identity-fallback"
        )
    }

    private static func performHomographicRegistration(
        floatingImage: CGImage,
        referenceImage: CGImage
    ) throws -> FrameRegistration? {
        let request = VNHomographicImageRegistrationRequest(targetedCGImage: floatingImage, options: [:])
        let handler = VNImageRequestHandler(cgImage: referenceImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        return FrameRegistration(
            transform: ProjectiveTransform(matrix: observation.warpTransform),
            confidence: Double(observation.confidence),
            method: "homography"
        )
    }

    private static func performTranslationalRegistration(
        floatingImage: CGImage,
        referenceImage: CGImage
    ) throws -> FrameRegistration? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: floatingImage, options: [:])
        let handler = VNImageRequestHandler(cgImage: referenceImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        let transform = CGAffineTransform(
            translationX: observation.alignmentTransform.tx,
            y: observation.alignmentTransform.ty
        )
        return FrameRegistration(
            transform: ProjectiveTransform(affineTransform: transform),
            confidence: Double(observation.confidence),
            method: "translation"
        )
    }

    /// Returns a downsampled copy of `image` whose longer edge does not
    /// exceed `maxLongEdge`. Returns `nil` when the image is already small
    /// enough (so callers can short-circuit without a copy).
    private static func downsampledCGImage(_ image: CGImage, maxLongEdge: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxLongEdge else { return nil }

        let scale = maxLongEdge / longest
        let targetWidth = Int((width * scale).rounded())
        let targetHeight = Int((height * scale).rounded())
        guard targetWidth > 0, targetHeight > 0,
              let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
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

    func median(of samples: [Float]) -> Float {
        let sorted = samples.sorted()
        let midpoint = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }

        return sorted[midpoint]
    }

    func kappaSigma(_ samples: [Float], replaceRejectedWithMedian: Bool) -> Float {
        // Small-sample kappa-sigma must stay robust against a single extreme
        // outlier — textbook mean/σ iteration breaks down because the very
        // outlier inflates σ until nothing gets rejected.  DSS-style
        // astrophotography stackers sidestep this by seeding the rejection
        // statistic with median + MAD (median absolute deviation), then
        // refining with mean/σ on the surviving inliers.  That is what we
        // mirror below.
        let kappa: Float = 2.0
        let iterations = 3
        let medianValue = median(of: samples)
        var working = samples

        for iteration in 0..<iterations {
            guard working.count > 1 else { break }

            // First pass: rejection centre is the median, spread is the
            // MAD scaled to the Gaussian σ equivalent (1.4826 factor).
            // Later passes use the standard mean/σ so a clean inlier set
            // converges to its arithmetic mean just like DSS's AvxAccumulation.
            let centre: Float
            let spread: Float
            if iteration == 0 {
                centre = median(of: working)
                let deviations = working.map { abs($0 - centre) }
                let mad = median(of: deviations)
                spread = mad * 1.4826
            } else {
                let mean = working.reduce(0, +) / Float(working.count)
                centre = mean
                let variance = working.reduce(0) { partialResult, sample in
                    let delta = sample - mean
                    return partialResult + (delta * delta)
                } / Float(working.count)
                spread = variance.squareRoot()
            }

            guard spread > 0 else { break }

            let tolerance = kappa * spread
            if replaceRejectedWithMedian {
                let replaced = working.map { sample in
                    abs(sample - centre) > tolerance ? medianValue : sample
                }
                if replaced == working { break }
                working = replaced
            } else {
                let filtered = working.filter { sample in
                    abs(sample - centre) <= tolerance
                }
                if filtered.isEmpty { break }
                if filtered.count == working.count { break }
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
    let meanRadius: Double

    init(x: Int, y: Int, peak: Double, meanRadius: Double = 0) {
        self.x = x
        self.y = y
        self.peak = peak
        self.meanRadius = meanRadius
    }
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
        // Fast path for test fixtures / DSS-style synthetic patterns: when
        // the input already is a single-channel grayscale bitmap and fits
        // within `maxDimension`, read its raw pixels directly to avoid the
        // UIGraphicsImageRenderer resample, which would otherwise apply an
        // alpha-premultiplied sRGB gamma round-trip that softens sharp
        // single-pixel bright features below the star-detection threshold.
        if let cgImage = image.cgImage,
           cgImage.colorSpace?.model == .monochrome,
           CGFloat(cgImage.width) <= maxDimension,
           CGFloat(cgImage.height) <= maxDimension,
           let raw = try? cgImage.grayscaleBytes() {
            width = cgImage.width
            height = cgImage.height
            var luminance = Array(repeating: Double.zero, count: width * height)
            for index in 0..<(width * height) {
                luminance[index] = Double(raw[index]) / 255
            }
            pixels = luminance
            return
        }

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

    /// Read raw 8-bit grayscale samples without routing through the
    /// sRGB/alpha pipeline.  Used as a fast path for DSS-style synthetic
    /// test fixtures whose pixel values must be preserved bit-exactly so
    /// the star detector operates on the same luminance the fixture
    /// declared (avoiding the gamma-induced softening that
    /// `UIGraphicsImageRenderer` introduces for tiny bright features).
    func grayscaleBytes() throws -> [UInt8] {
        let width = width
        let height = height
        let bytesPerRow = width
        var bytes = Array(repeating: UInt8.zero, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw StackingError.processingFailed(L10n.Error.pixelReadFailed)
        }

        // Disable interpolation so a 1:1 draw preserves the source pixels
        // exactly, even when the source CGImage is itself a grayscale
        // buffer with the same dimensions.
        context.interpolationQuality = .none
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}

// MARK: - Test-visible entry points
//
// `analyzeFrame` and the scalar `combine` overload are intentionally exposed
// at module (`internal`) visibility so that `@testable import Stakka` in the
// StakkaTests target can exercise them directly, mirroring DSS's unit-level
// coverage of `registerSubRect` and `AvxAccumulation::accumulate`.  The
// image-level `combine([LinearRGBAImage]...)` overload stays fileprivate
// because it references the fileprivate `LinearRGBAImage` type.
extension ImageStacker {
    func registerFrame(floatingImage: CGImage, referenceImage: CGImage) -> FrameRegistration {
        register(floatingImage: floatingImage, referenceImage: referenceImage)
    }

    func analyzeFrame(_ image: UIImage) throws -> FrameAnalysis {
        let sample = try LuminanceSample(image: image, maxDimension: 256)
        let pixels = sample.pixels
        guard !pixels.isEmpty else {
            throw StackingError.processingFailed(L10n.Error.emptyAnalysisData)
        }

        // DSS uses the 50th-percentile (median) of the sub-rectangle as its
        // background estimate, then adds the user-selected detection
        // threshold (default 10 %) to derive the acceptance floor.  See
        // `DSS::registerSubRect` — `intensityThreshold = 256 * detectionThreshold + backgroundLevel`,
        // here normalised to the [0, 1] luminance scale.
        let sortedPixels = pixels.sorted()
        let background = percentile(in: sortedPixels, ratio: 0.5)
        let detectionThreshold = 0.10
        let threshold = min(0.99, background + detectionThreshold)

        let stars = detectStars(in: sample, threshold: threshold, background: background)
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
        case .maximum:
            return samples.max() ?? 0
        }
    }
}
