import SwiftUI
import UIKit

struct PermissionsView: View {
    @State private var isRequesting = false
    @State private var message: String?
    @State private var showAutoSyncPrompt = false

    var body: some View {
        List {
            Section {
                Text("本 App 需要读取所有训练记录和运动距离数据，需要写入运动距离数据用于补全。")
            }
            Section {
                Button("重新请求授权") {
                    Task {
                        isRequesting = true
                        defer { isRequesting = false }
                        do {
                            try await HealthKitManager.requestAuthorizationIfNeeded(using: RealHealthStore.shared)
                            // 对应 ADR-005 决策2：和 RootView.task 复用同一套逻辑——已经问过就直接
                            // 按偏好对齐一次状态，没问过就弹窗（比如权限被外部吊销后重新走一遍授权）。
                            let preference = AutoSyncPreference()
                            if preference.hasPrompted {
                                await ObserverRegistrar.syncRegistration(enabled: preference.isEnabled)
                            } else {
                                showAutoSyncPrompt = true
                            }
                            message = String(localized: "已请求授权")
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                }
                .disabled(isRequesting)

                Button("前往系统设置检查授权") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("健康数据的读权限状态对 App 不可见：如果扫描历史一直是 0 条待处理，请来这里检查是否已经在系统设置里授予了读取权限。")
            }
            if let message {
                Section {
                    Text(message)
                }
            }
        }
        .navigationTitle("健康数据权限")
        .autoSyncPrompt(isPresented: $showAutoSyncPrompt)
    }
}
