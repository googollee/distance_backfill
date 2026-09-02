import SwiftUI

struct SettingsView: View {
    @AppStorage(AutoSyncPreference.enabledKey) private var autoSyncEnabled = false

    var body: some View {
        List {
            Section("权限") {
                NavigationLink("健康数据权限") {
                    PermissionsView()
                }
            }
            Section {
                Toggle("自动补全新训练", isOn: $autoSyncEnabled)
                    .onChange(of: autoSyncEnabled) { _, newValue in
                        Task { await ObserverRegistrar.syncRegistration(enabled: newValue) }
                    }
            } footer: {
                Text("开启后，新训练同步进健康 App 会在后台自动补全距离，不需要手动操作。关闭时仍然可以随时用「扫描历史」手动补全。")
            }
            Section("说明") {
                Text("后台自动补全依赖 iOS 系统调度，不保证实时；如果长时间没有自动生效，可以手动使用「扫描历史」，或者重新打开一次本 App。")
                Text("卸载重装本 App 后，本地写入记录会丢失，此前写入健康 App 的数据仍然有效，但无法再通过本 App 撤销。")
            }
            #if DEBUG
            Section("调试") {
                NavigationLink("调试工具") {
                    SeederView()
                }
            }
            #endif
        }
        .navigationTitle("设置")
    }
}
