import SwiftUI

struct RootView: View {
    @State private var authorizationError: String?
    @State private var showAutoSyncPrompt = false

    var body: some View {
        TabView {
            NavigationStack {
                ScanHistoryView()
            }
            .tabItem { Label("扫描历史", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack {
                RecordListView()
            }
            .tabItem { Label("已写入记录", systemImage: "list.bullet") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .task {
            do {
                try await HealthKitManager.requestAuthorizationIfNeeded(using: RealHealthStore.shared)

                // 对应 ADR-005 决策2：App 启动检查只在 AppDelegate 做一次，这里不再重复注册；
                // 已经问过就直接按偏好对齐一次状态，没问过就弹窗，弹窗的选择本身会去对齐状态。
                let preference = AutoSyncPreference()
                if preference.hasPrompted {
                    await ObserverRegistrar.syncRegistration(enabled: preference.isEnabled)
                } else {
                    showAutoSyncPrompt = true
                }
            } catch {
                authorizationError = error.localizedDescription
            }
        }
        .alert(
            "健康数据授权失败",
            isPresented: Binding(
                get: { authorizationError != nil },
                set: { if !$0 { authorizationError = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(authorizationError ?? "")
        }
        // 对应 ADR-003：首次授权成功后只问一次，且必须二选一，不能划掉/侧滑关闭。
        .autoSyncPrompt(isPresented: $showAutoSyncPrompt)
    }
}
