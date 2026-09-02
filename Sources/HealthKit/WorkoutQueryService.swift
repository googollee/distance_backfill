import HealthKit

/// 训练记录查询的两条路径：历史全量扫描（手动触发）、增量查询（后台观察者触发）。
/// 只负责查询，不负责持久化 anchor —— anchor 的读写由调用方（ScanViewModel / ObserverRegistrar）决定。
final class WorkoutQueryService {
    /// 传 nil anchor 即可拿到当前所有训练记录，用于"扫描历史"手动入口。
    func fetchAllWorkouts(using store: HealthStoring) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        try await store.anchoredWorkouts(anchor: nil)
    }

    /// 传已保存的 anchor，只拿到自上次以来新增/变更的训练记录，用于后台观察者回调。
    func fetchNewWorkouts(anchor: HKQueryAnchor?, using store: HealthStoring) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        try await store.anchoredWorkouts(anchor: anchor)
    }
}
