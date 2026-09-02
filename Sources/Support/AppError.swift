import Foundation

enum AppError: LocalizedError {
    case healthDataUnavailable
    case authorizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return String(localized: "此设备不支持健康数据")
        case .authorizationFailed(let message):
            return String(localized: "健康数据授权失败：\(message)")
        }
    }
}
