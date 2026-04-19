import Foundation

enum AppError: LocalizedError {
    case unavailable
    case permissionDenied
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return L10n.Error.unavailable
        case .permissionDenied:
            return L10n.Error.permissionDenied
        case .operationFailed(let message):
            return message
        }
    }
}
