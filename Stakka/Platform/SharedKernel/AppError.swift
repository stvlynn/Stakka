import Foundation

enum AppError: LocalizedError {
    case unavailable
    case permissionDenied
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前功能不可用"
        case .permissionDenied:
            return "权限被拒绝"
        case .operationFailed(let message):
            return message
        }
    }
}
