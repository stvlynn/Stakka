import Foundation

enum L10n {
    private static let table = "Localizable"

    private static func text(_ key: String, default defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: table)
    }

    private static func format(_ key: String, default defaultValue: String, _ arguments: CVarArg...) -> String {
        let format = text(key, default: defaultValue)
        return String(format: format, locale: Locale.autoupdatingCurrent, arguments: arguments)
    }

    enum Common {
        static var done: String { L10n.text("common.done", default: "Done") }
        static var confirm: String { L10n.text("common.confirm", default: "Confirm") }
        static var new: String { L10n.text("common.new", default: "New") }
        static var open: String { L10n.text("common.open", default: "Open") }
        static var close: String { L10n.text("common.close", default: "Close") }
        static var duplicate: String { L10n.text("common.duplicate", default: "Duplicate") }
        static var delete: String { L10n.text("common.delete", default: "Delete") }
        static var save: String { L10n.text("common.save", default: "Save") }
        static var off: String { L10n.text("common.off", default: "Off") }
        static var current: String { L10n.text("common.current", default: "Current") }
    }

    enum Tab {
        static var map: String { L10n.text("tab.map", default: "Map") }
        static var capture: String { L10n.text("tab.capture", default: "Capture") }
        static var gallery: String { L10n.text("tab.gallery", default: "Gallery") }
    }

    enum Gallery {
        static var title: String { L10n.text("gallery.title", default: "Gallery") }
        static var empty: String { L10n.text("gallery.empty", default: "Your finished photos will appear here") }
        static var emptyHint: String {
            L10n.text("gallery.empty.hint", default: "Tap the button below to create your first stacking project")
        }
        static var createProject: String { L10n.text("gallery.create", default: "New Project") }
    }

    enum Wizard {
        static var stepMode: String { L10n.text("wizard.step.mode", default: "Stacking Mode") }
        static var stepModeExplanation: String {
            L10n.text(
                "wizard.step.mode.explanation",
                default: "Choose how your photos will be combined. If you're unsure, \"Average\" is a great starting point — it reduces noise and brings out faint detail."
            )
        }
        static var stepFrames: String { L10n.text("wizard.step.frames", default: "Import Photos") }
        static var stepFramesExplanation: String {
            L10n.text(
                "wizard.step.frames.explanation",
                default: "Add at least 2 Light frames — these are your main photos of the night sky. Optionally add Dark, Flat, and Bias calibration frames for cleaner results."
            )
        }

        // Split import steps (Light → Dark → Flat+Bias)
        static var stepLight: String { L10n.text("wizard.step.light", default: "Light Frames") }
        static var stepLightExplanation: String {
            L10n.text(
                "wizard.step.light.explanation",
                default: "These are your actual photos of the night sky. Pick at least 2 — the more you add, the cleaner the final image."
            )
        }
        static var stepDark: String { L10n.text("wizard.step.dark", default: "Dark Frames") }
        static var stepDarkExplanation: String {
            L10n.text(
                "wizard.step.dark.explanation",
                default: "Optional. Dark frames cancel out sensor noise and hot pixels. Skip this step if you don't have any."
            )
        }
        static var stepCalibration: String { L10n.text("wizard.step.calibration", default: "Calibration Frames") }
        static var stepCalibrationExplanation: String {
            L10n.text(
                "wizard.step.calibration.explanation",
                default: "Optional. Flat and Bias frames correct vignetting and readout noise. Most casual captures don't need them."
            )
        }
        static var optional: String { L10n.text("wizard.optional", default: "Optional") }
        static var learnMore: String { L10n.text("wizard.learnMore", default: "Learn more") }
        static var dragToDelete: String {
            L10n.text("wizard.thumbnail.dragToDelete", default: "Drop here to remove")
        }
        static var photoCount: String {
            L10n.text("wizard.thumbnail.count", default: "%@ photos imported")
        }
        static func photoIndex(current: Int, total: Int) -> String {
            L10n.format("wizard.preview.index", default: "%@ / %@", String(current), String(total))
        }
        static var previewClose: String {
            L10n.text("wizard.preview.close", default: "Close")
        }
        static var loadingThumbnail: String {
            L10n.text("wizard.thumbnail.loading", default: "Loading")
        }

        // Frame-kind explainers (shown in the info popover)
        static var lightExplainer: String {
            L10n.text(
                "wizard.explainer.light",
                default: "Light frames are the photos you took of the stars. Stakka aligns and blends them together to boost the signal and smooth out noise."
            )
        }
        static var darkExplainer: String {
            L10n.text(
                "wizard.explainer.dark",
                default: "Dark frames are shots taken with the lens cap on, using the same exposure and ISO as your Light frames. They expose sensor heat noise so Stakka can subtract it."
            )
        }
        static var flatExplainer: String {
            L10n.text(
                "wizard.explainer.flat",
                default: "Flat frames are photos of an evenly lit surface (like the twilight sky) taken without moving the lens. They reveal vignetting and dust spots so Stakka can correct them."
            )
        }
        static var darkFlatExplainer: String {
            L10n.text(
                "wizard.explainer.darkFlat",
                default: "Dark Flats use the same exposure as your Flat frames but with the lens cap on. They remove the noise hidden inside the Flat frames themselves."
            )
        }
        static var biasExplainer: String {
            L10n.text(
                "wizard.explainer.bias",
                default: "Bias frames are the shortest possible exposures with the lens capped. They capture your sensor's baseline readout pattern."
            )
        }

        static var stepReview: String { L10n.text("wizard.step.review", default: "Review & Start") }
        static var stepReviewExplanation: String {
            L10n.text(
                "wizard.step.review.explanation",
                default: "Everything looks good! The app will align your photos and stack them together. This may take a moment depending on how many frames you have."
            )
        }
        static var next: String { L10n.text("wizard.next", default: "Next") }
        static var back: String { L10n.text("wizard.back", default: "Back") }
        static var startStacking: String { L10n.text("wizard.start", default: "Start Stacking") }
        static func stepIndicator(current: Int, total: Int) -> String {
            L10n.format("wizard.step.indicator", default: "Step %@ of %@", String(current), String(total))
        }
        static var lightFramesRequired: String {
            L10n.text("wizard.frames.required", default: "At least 2 Light frames are needed to stack")
        }
        static var modeAverageHint: String {
            L10n.text("wizard.mode.average.hint", default: "Best for most situations. Reduces noise by averaging pixel values across all frames.")
        }
        static var modeMedianHint: String {
            L10n.text("wizard.mode.median.hint", default: "Great for removing satellites and planes. Uses the middle value so outliers disappear.")
        }
        static var modeKappaHint: String {
            L10n.text("wizard.mode.kappa.hint", default: "Advanced. Rejects pixels that deviate too far from the mean, then averages the rest.")
        }
        static var modeMedianKappaHint: String {
            L10n.text("wizard.mode.medianKappa.hint", default: "Combines median rejection with kappa-sigma clipping for the cleanest result.")
        }
    }

    enum DarkSky {
        static var title: String { L10n.text("darksky.title", default: "Light Pollution Map") }
        static var marker: String { L10n.text("darksky.marker", default: "Dark Sky Point") }
        static var cardTitle: String { L10n.text("darksky.card.title", default: "Light Pollution Level") }

        static func bortleTitle(level: Int) -> String {
            switch level {
            case 1:
                return L10n.text("darksky.bortle.1", default: "Excellent Dark Sky")
            case 2:
                return L10n.text("darksky.bortle.2", default: "Truly Dark Sky")
            case 3:
                return L10n.text("darksky.bortle.3", default: "Rural Dark Sky")
            case 4:
                return L10n.text("darksky.bortle.4", default: "Rural Transition")
            case 5:
                return L10n.text("darksky.bortle.5", default: "Suburban Sky")
            case 6:
                return L10n.text("darksky.bortle.6", default: "Bright Suburban")
            case 7:
                return L10n.text("darksky.bortle.7", default: "Suburban Edge")
            case 8:
                return L10n.text("darksky.bortle.8", default: "City Sky")
            default:
                return L10n.text("darksky.bortle.9", default: "Inner City")
            }
        }

        static var labelSQM: String { L10n.text("darksky.label.sqm", default: "SQM Value") }
        static var labelDarkSkyGrade: String { L10n.text("darksky.label.grade", default: "Dark Sky Grade") }
        static var labelBrightness: String { L10n.text("darksky.label.brightness", default: "Ground Brightness") }
        static var labelMilkyWay: String { L10n.text("darksky.label.milkyWay", default: "Milky Way") }
        static var labelGalaxy: String { L10n.text("darksky.label.galaxy", default: "M31/M33") }
        static var labelZodiacal: String { L10n.text("darksky.label.zodiacal", default: "Zodiacal Light") }

        static func darkSkyGrade(level: Int) -> String {
            L10n.text("darksky.grade.\(level)", default: "Grade \(level)")
        }

        static var milkyWaySpectacular: String { L10n.text("darksky.milkyway.spectacular", default: "Spectacular, structure visible") }
        static var milkyWayClear: String { L10n.text("darksky.milkyway.clear", default: "Clearly visible") }
        static var milkyWayPartial: String { L10n.text("darksky.milkyway.partial", default: "Partially visible") }
        static var milkyWayCoreOnly: String { L10n.text("darksky.milkyway.coreOnly", default: "Only core visible") }
        static var milkyWayInvisible: String { L10n.text("darksky.milkyway.invisible", default: "Not visible") }

        static var galaxyBoth: String { L10n.text("darksky.galaxy.both", default: "M31 & M33 naked-eye") }
        static var galaxyM31: String { L10n.text("darksky.galaxy.m31", default: "M31 naked-eye") }
        static var galaxyBarely: String { L10n.text("darksky.galaxy.barely", default: "Barely discernible") }
        static var galaxyInvisible: String { L10n.text("darksky.galaxy.invisible", default: "Not visible") }

        static var zodiacalVeryClear: String { L10n.text("darksky.zodiacal.veryClear", default: "Extremely clear") }
        static var zodiacalClear: String { L10n.text("darksky.zodiacal.clear", default: "Clearly visible") }
        static var zodiacalVisible: String { L10n.text("darksky.zodiacal.visible", default: "Visible") }
        static var zodiacalInvisible: String { L10n.text("darksky.zodiacal.invisible", default: "Not visible") }

        static var searchPlaceholder: String { L10n.text("darksky.search.placeholder", default: "Search location") }
    }

    enum Camera {
        static var title: String { L10n.text("camera.title", default: "Stack Capture") }
        static var recentProjectSaved: String { L10n.text("camera.recentProject.saved", default: "Saved to recent project") }
        static var settingsTitle: String { L10n.text("camera.settings.title", default: "Capture Settings") }
        static var exposureSection: String { L10n.text("camera.section.exposure", default: "Exposure") }
        static var stackingSection: String { L10n.text("camera.section.stacking", default: "Stacking") }
        static var shotCount: String { L10n.text("camera.field.shotCount", default: "Shots") }
        static var interval: String { L10n.text("camera.field.interval", default: "Interval") }
        static var summarySection: String { L10n.text("camera.section.summary", default: "Summary") }
        static var exposureTime: String { L10n.text("camera.picker.exposureTime", default: "Exposure Time") }
        static var aperture: String { L10n.text("camera.control.aperture", default: "Aperture") }
        static var shutter: String { L10n.text("camera.control.shutter", default: "Shutter") }
        static var zoom: String { L10n.text("camera.control.zoom", default: "Zoom") }
        static var mode: String { L10n.text("camera.control.mode", default: "Mode") }
        static var shutterSpeed: String { L10n.text("camera.picker.shutterSpeed", default: "Shutter Speed") }
        static var zoomFactor: String { L10n.text("camera.picker.zoomFactor", default: "Zoom Factor") }
        static var shotCountPicker: String { L10n.text("camera.picker.shotCount", default: "Shot Count") }
        static var shootingMode: String { L10n.text("camera.picker.shootingMode", default: "Shooting Mode") }
    }

    enum Library {
        static var title: String { L10n.text("library.title", default: "Library Project") }
        static var introTitle: String { L10n.text("library.intro.title", default: "DSS-Style Project Flow") }
        static var introSubtitle: String {
            L10n.text("library.intro.subtitle", default: "Import five frame groups, then analyze, register, and stack.")
        }
        static var ready: String { L10n.text("library.phase.idle", default: "Ready") }
        static var analyze: String { L10n.text("library.action.analyze", default: "Analyze") }
        static var register: String { L10n.text("library.action.register", default: "Register") }
        static var stack: String { L10n.text("library.action.stack", default: "Stack") }
        // New single-button pipeline label used by the redesigned detail view.
        static var startStacking: String { L10n.text("library.action.startStacking", default: "Start Stacking") }
        static var frameSection: String { L10n.text("library.section.frames", default: "Frames") }
        static var resultPlaceholder: String {
            L10n.text("library.result.placeholder", default: "Your stacked night sky will appear here")
        }
        static var resultPlaceholderHint: String {
            L10n.text(
                "library.result.placeholderHint",
                default: "Add light frames and tap Start Stacking to begin."
            )
        }
        // Progress — per-stage captions
        static var progressAnalyzing: String { L10n.text("library.progress.analyzing", default: "Analyzing frames") }
        static var progressRegistering: String { L10n.text("library.progress.registering", default: "Aligning frames") }
        static var progressStacking: String { L10n.text("library.progress.stacking", default: "Stacking frames") }
        static func progressCount(current: Int, total: Int) -> String {
            L10n.format("library.progress.count", default: "Frame %@ of %@", String(current), String(total))
        }
        static func progressEta(seconds: Int) -> String {
            L10n.format("library.progress.eta", default: "about %@s left", String(seconds))
        }
        static func progressThroughput(fps: String) -> String {
            L10n.format("library.progress.throughput", default: "%@ frames/s", fps)
        }
        // Gallery preview
        static var openProject: String { L10n.text("gallery.preview.openProject", default: "Open Project") }
        static var cometHint: String {
            L10n.text(
                "library.hint.comet",
                default: "After choosing a comet mode, register first to estimate the comet position, then review it."
            )
        }
        static func referenceHint(lightTitle: String) -> String {
            L10n.format(
                "library.hint.reference",
                default: "Use at least 2 %@ frames. The best-scoring frame becomes the reference automatically, and you can also pick one manually.",
                lightTitle
            )
        }
        static var browserTitle: String { L10n.text("library.browser.title", default: "Projects") }
        static var browserEmpty: String { L10n.text("library.browser.empty", default: "No saved projects yet") }
        static var createProject: String { L10n.text("library.browser.create", default: "Create New Project") }
        static func autoReferenceHint(lightTitle: String) -> String {
            L10n.format(
                "library.summary.reference.auto",
                default: "Automatically selects a reference frame after importing %@ frames",
                lightTitle
            )
        }
        static var processingUpdating: String { L10n.text("library.processing.updating", default: "Project is updating") }
        static var resultCompleted: String { L10n.text("library.result.completed", default: "Stack Complete") }
        static var exportTIFF: String { L10n.text("library.result.exportTiff", default: "TIFF") }
        static func addFrame(kind: String) -> String {
            L10n.format("library.section.addKind", default: "Add %@", kind)
        }
        static var cometReviewPrerequisite: String {
            L10n.text(
                "library.error.reviewPrerequisite",
                default: "Register first so the app can estimate the comet position."
            )
        }
        static var reviewTitle: String { L10n.text("library.review.title", default: "Comet Review") }
        static var useEstimated: String { L10n.text("library.review.useEstimated", default: "Use Estimated Point") }
        static var reviewNeedsCheck: String { L10n.text("library.review.status.needsReview", default: "Needs Review") }
        static var reviewConfirmed: String { L10n.text("library.review.status.confirmed", default: "Confirmed") }
        static var reviewManual: String { L10n.text("library.review.source.manual", default: "Manual") }
        static var reviewAuto: String { L10n.text("library.review.source.auto", default: "Auto") }
        static var previousFrame: String { L10n.text("library.review.previous", default: "Previous") }
        static var nextFrame: String { L10n.text("library.review.next", default: "Next") }

        static func cometReviewAction(needsReviewCount: Int) -> String {
            if needsReviewCount == 0 {
                return L10n.text("library.review.action.view", default: "View Comet Review")
            }

            return L10n.text("library.review.action.check", default: "Check Comet Review")
        }
    }

    enum Stacking {
        enum Frame {
            static var light: String { L10n.text("stack.frame.light", default: "Light") }
            static var dark: String { L10n.text("stack.frame.dark", default: "Dark") }
            static var flat: String { L10n.text("stack.frame.flat", default: "Flat") }
            static var darkFlat: String { L10n.text("stack.frame.darkFlat", default: "Dark Flat") }
            static var bias: String { L10n.text("stack.frame.bias", default: "Bias") }
        }

        enum Mode {
            static var average: String { L10n.text("stack.mode.average", default: "Average") }
            static var median: String { L10n.text("stack.mode.median", default: "Median") }
            static var kappa: String { L10n.text("stack.mode.kappa", default: "Kappa") }
            static var medianKappa: String { L10n.text("stack.mode.medianKappa", default: "M-Kappa") }
        }

        enum Comet {
            static var standard: String { L10n.text("stack.comet.standard", default: "Standard") }
            static var cometOnly: String { L10n.text("stack.comet.cometOnly", default: "Comet Only") }
            static var cometAndStars: String { L10n.text("stack.comet.cometAndStars", default: "Comet + Stars") }
            static var standardDescription: String {
                L10n.text("stack.comet.standard.description", default: "Stars stay fixed and the comet trails.")
            }
            static var cometOnlyDescription: String {
                L10n.text("stack.comet.cometOnly.description", default: "The comet stays fixed and the stars trail.")
            }
            static var cometAndStarsDescription: String {
                L10n.text("stack.comet.cometAndStars.description", default: "Both the comet and stars stay fixed.")
            }
        }
    }

    enum Project {
        private static let knownDuplicateSuffixes = [" Copy", " 副本"]

        static var defaultTitle: String { L10n.text("project.defaultTitle", default: "Library Project") }

        static func newTitle(at date: Date) -> String {
            L10n.format("project.title.new", default: "New Project %@", L10nFormat.projectDateTime(date))
        }

        static func captureTitle(at date: Date) -> String {
            L10n.format("project.title.capture", default: "Capture Project %@", L10nFormat.projectTime(date))
        }

        static func captureFrameName(index: Int) -> String {
            L10n.format("project.frame.capture", default: "Capture %@", String(index))
        }

        static func duplicateTitle(from title: String) -> String {
            if knownDuplicateSuffixes.contains(where: { title.hasSuffix($0) }) {
                return title
            }

            return L10n.format("project.title.copy", default: "%@ Copy", title)
        }
    }

    enum Error {
        static var unavailable: String { L10n.text("error.unavailable", default: "This feature is unavailable") }
        static var permissionDenied: String { L10n.text("error.permissionDenied", default: "Permission was denied") }
        static var emptyInput: String { L10n.text("error.stacking.emptyInput", default: "There are no images to stack") }
        static var notEnoughLightFrames: String {
            L10n.text("error.stacking.notEnoughLightFrames", default: "At least two enabled Light frames are required")
        }
        static var missingReferenceFrame: String {
            L10n.text("error.stacking.missingReferenceFrame", default: "No reference frame is available")
        }
        static var cometAnnotationsRequired: String {
            L10n.text("error.stacking.cometAnnotationsRequired", default: "Some comet frames still need review or correction")
        }
        static var incompatibleDimensions: String {
            L10n.text("error.stacking.incompatibleDimensions", default: "Image dimensions do not match")
        }
        static var referenceFrameUnreadable: String {
            L10n.text("error.stacking.referenceFrameUnreadable", default: "The reference frame could not be decoded")
        }
        static var lightFrameUnreadable: String {
            L10n.text("error.stacking.lightFrameUnreadable", default: "A Light frame could not be decoded")
        }
        static var emptyAnalysisData: String {
            L10n.text("error.stacking.emptyAnalysisData", default: "Analysis data is empty")
        }
        static var registrationFailed: String {
            L10n.text("error.stacking.registrationFailed", default: "Image registration could not be completed")
        }
        static var sampleImageFailed: String {
            L10n.text("error.stacking.sampleImageFailed", default: "A sample image could not be created")
        }
        static var pixelReadFailed: String {
            L10n.text("error.stacking.pixelReadFailed", default: "Image pixels could not be read")
        }
        static var resultImageFailed: String {
            L10n.text("error.stacking.resultImageFailed", default: "The result image could not be created")
        }
        static var tiffExportFailed: String {
            L10n.text("error.stacking.tiffExportFailed", default: "The TIFF export could not be created")
        }
        static var duplicateProjectMissing: String {
            L10n.text("error.project.duplicateMissing", default: "The project to duplicate could not be found")
        }
        static var switchProjectMissing: String {
            L10n.text("error.project.switchMissing", default: "The project to open could not be found")
        }
        static var frameCacheWriteFailed: String {
            L10n.text("error.project.frameCacheWriteFailed", default: "The frame cache could not be written")
        }
        static var photoProcessingFailed: String {
            L10n.text("error.camera.photoProcessingFailed", default: "The photo could not be processed")
        }
        static var saveFailed: String {
            L10n.text("error.photo.saveFailed", default: "The image could not be saved")
        }
        static var tiffReadFailed: String {
            L10n.text("error.document.tiffReadFailed", default: "The TIFF document could not be read")
        }
    }

    enum Accessibility {
        static var centerOnLocation: String {
            L10n.text("a11y.darksky.centerOnLocation", default: "Center on current location")
        }
        static var search: String {
            L10n.text("a11y.darksky.search", default: "Search")
        }
        static var openSettings: String {
            L10n.text("a11y.camera.openSettings", default: "Open capture settings")
        }
        static var openProjects: String {
            L10n.text("a11y.library.openProjects", default: "Open saved projects")
        }
        static var dismissPicker: String {
            L10n.text("a11y.common.dismissPicker", default: "Dismiss picker")
        }
        static var startCapture: String {
            L10n.text("a11y.camera.startCapture", default: "Start capture")
        }
        static var stopCapture: String {
            L10n.text("a11y.camera.stopCapture", default: "Stop capture")
        }
        static func importPhotos(kind: String) -> String {
            L10n.format("a11y.library.importPhotos", default: "Import %@ photos", kind)
        }
        static func importFiles(kind: String) -> String {
            L10n.format("a11y.library.importFiles", default: "Import %@ files", kind)
        }
        static func clearFrames(kind: String) -> String {
            L10n.format("a11y.library.clearFrames", default: "Clear %@ frames", kind)
        }
        static var enableFrame: String {
            L10n.text("a11y.library.enableFrame", default: "Enable frame")
        }
        static var disableFrame: String {
            L10n.text("a11y.library.disableFrame", default: "Disable frame")
        }
        static var removeFrame: String {
            L10n.text("a11y.library.removeFrame", default: "Remove frame")
        }
        static var setReferenceFrame: String {
            L10n.text("a11y.library.setReferenceFrame", default: "Set as reference frame")
        }
        static var reviewCometAnnotation: String {
            L10n.text("a11y.library.reviewComet", default: "Review comet annotation")
        }
    }

    enum Permissions {
        // Location
        static var locationTitle: String {
            L10n.text("permissions.location.title", default: "Find your night sky")
        }
        static var locationBody: String {
            L10n.text(
                "permissions.location.body",
                default: "Stakka uses your location to show the light pollution level where you are and to suggest nearby dark-sky spots."
            )
        }
        static var locationAllow: String {
            L10n.text("permissions.location.allow", default: "Allow Location")
        }
        static var locationDeniedTitle: String {
            L10n.text("permissions.location.denied.title", default: "Location access is off")
        }
        static var locationDeniedBody: String {
            L10n.text(
                "permissions.location.denied.body",
                default: "Location permission is disabled. Open Settings to turn it back on so Stakka can center the map on you."
            )
        }

        // Camera
        static var cameraTitle: String {
            L10n.text("permissions.camera.title", default: "Ready to capture the stars")
        }
        static var cameraBody: String {
            L10n.text(
                "permissions.camera.body",
                default: "Stakka needs camera access to run a long-exposure stacking session and record each frame of the night sky."
            )
        }
        static var cameraAllow: String {
            L10n.text("permissions.camera.allow", default: "Allow Camera")
        }
        static var cameraDeniedTitle: String {
            L10n.text("permissions.camera.denied.title", default: "Camera access is off")
        }
        static var cameraDeniedBody: String {
            L10n.text(
                "permissions.camera.denied.body",
                default: "Camera permission is disabled. Open Settings to turn it on so Stakka can stream the live preview."
            )
        }

        // Photos
        static var photosTitle: String {
            L10n.text("permissions.photos.title", default: "Bring in your photos")
        }
        static var photosBody: String {
            L10n.text(
                "permissions.photos.body",
                default: "Stakka needs access to your photo library to import the frames you want to stack."
            )
        }
        static var photosAllow: String {
            L10n.text("permissions.photos.allow", default: "Allow Photos")
        }
        static var photosDeniedTitle: String {
            L10n.text("permissions.photos.denied.title", default: "Photos access is off")
        }
        static var photosDeniedBody: String {
            L10n.text(
                "permissions.photos.denied.body",
                default: "Photo library permission is disabled. Open Settings to turn it on so Stakka can import your frames."
            )
        }

        // Common actions
        static var notNow: String { L10n.text("permissions.notNow", default: "Not Now") }
        static var openSettings: String { L10n.text("permissions.openSettings", default: "Open Settings") }
    }
}
