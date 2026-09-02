import SwiftUI

/// "开启自动补全？"询问弹窗（对应 PRD-001 功能需求7、ADR-003、ADR-005 决策2）。
/// `RootView` 首次授权成功、`PermissionsView` 重新请求授权成功后，只要还没问过
/// （`hasPrompted == false`）都复用这同一个弹窗，文案和按钮逻辑只维护一处。
struct AutoSyncPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    @AppStorage(AutoSyncPreference.enabledKey) private var autoSyncEnabled = false
    @AppStorage(AutoSyncPreference.hasPromptedKey) private var autoSyncHasPrompted = false

    func body(content: Content) -> some View {
        content.alert("开启自动补全？", isPresented: $isPresented) {
            Button("打开") {
                autoSyncEnabled = true
                autoSyncHasPrompted = true
                Task { await ObserverRegistrar.syncRegistration(enabled: true) }
            }
            Button("暂不开启", role: .cancel) {
                autoSyncEnabled = false
                autoSyncHasPrompted = true
                Task { await ObserverRegistrar.syncRegistration(enabled: false) }
            }
        } message: {
            Text("开启后，新训练同步进健康 App 会自动补全距离，无需手动操作。之后可以随时在设置里重新打开或关闭。")
        }
    }
}

extension View {
    func autoSyncPrompt(isPresented: Binding<Bool>) -> some View {
        modifier(AutoSyncPromptModifier(isPresented: isPresented))
    }
}
