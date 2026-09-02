import UIKit

/// 系统通过 HealthKit 后台投递唤醒进程时，只会执行到这里（不会渲染任何 SwiftUI View），
/// 所以这是整个 App 生命周期里唯一保证"每次进程启动都会执行"的钩子（对应 ADR-005 决策2）。
/// 按当前偏好值对齐注册状态：开则重新建立 HKObserverQuery，关则顺带撤销系统的后台投递资格，
/// 防止上一次关闭操作因为进程中途被杀等原因没有真正传达到系统。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { await ObserverRegistrar.syncRegistration(enabled: AutoSyncPreference().isEnabled) }
        return true
    }
}
