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
        static var duplicate: String { L10n.text("common.duplicate", default: "Duplicate") }
        static var delete: String { L10n.text("common.delete", default: "Delete") }
        static var save: String { L10n.text("common.save", default: "Save") }
        static var off: String { L10n.text("common.off", default: "Off") }
        static var current: String { L10n.text("common.current", default: "Current") }
    }

    enum Tab {
        static var map: String { L10n.text("tab.map", default: "Map") }
        static var capture: String { L10n.text("tab.capture", default: "Capture") }
        static var stacking: String { L10n.text("tab.stacking", default: "Stacking") }
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
}
