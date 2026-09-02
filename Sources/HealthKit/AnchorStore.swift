import Foundation
import HealthKit

/// 持久化增量查询用的 HKQueryAnchor（HKQueryAnchor 遵循 NSSecureCoding）。
struct AnchorStore {
    private static let key = "im.googol.DistanceBackfill.workoutQueryAnchor"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    func save(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
