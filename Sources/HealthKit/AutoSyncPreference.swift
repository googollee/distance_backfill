import Foundation

/// 后台自动补全开关的本地偏好（对应 ADR-003）。默认关闭，用户需要主动选择打开。
///
/// 供非 View 上下文（`AppDelegate`、单元测试、`RootView`/`PermissionsView` 内的一次性读取）
/// 做实例化的读写封装；`enabledKey`/`hasPromptedKey` 同时对外暴露，作为 View 层
/// `@AppStorage` 的唯一 key 来源，避免字符串字面量在多个 View 文件里重复。
struct AutoSyncPreference {
    static let enabledKey = "im.googol.DistanceBackfill.autoSyncEnabled"
    static let hasPromptedKey = "im.googol.DistanceBackfill.autoSyncHasPrompted"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    /// 是否已经问过用户"要不要打开自动补全"，只问一次。
    var hasPrompted: Bool {
        get { defaults.bool(forKey: Self.hasPromptedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.hasPromptedKey) }
    }
}
