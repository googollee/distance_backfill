import HealthKit

/// 对 HKHealthStore 的最小接口封装，只暴露本 App 用到的能力，便于测试用 Fake 实现替换。
protocol HealthStoring: AnyObject {
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func execute(_ query: HKQuery)
    func stop(_ query: HKQuery)
    func save(_ object: HKObject) async throws
    /// 返回删除的对象数量；为 0 表示目标对象已不存在（悬空场景）。
    func deleteObjects(of objectType: HKSampleType, predicate: NSPredicate) async throws -> Int
    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func samples(of sampleType: HKSampleType, predicate: NSPredicate?, limit: Int) async throws -> [HKSample]
    func workouts(predicate: NSPredicate?, limit: Int) async throws -> [HKWorkout]
    /// 增量查询：传 nil anchor 表示"从头开始"（用于历史全量扫描），传已保存的 anchor 表示"只要新增/变更的部分"。
    func anchoredWorkouts(anchor: HKQueryAnchor?) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?)
}

/// 真实 HealthKit 实现：用组合而不是 `extension HKHealthStore: HealthStoring`，
/// 避免和系统自动桥接出的同名 async 方法（requestAuthorization/save/enableBackgroundDelivery）
/// 发生重声明或自递归。所有调用都显式走 completion-handler 版本 + continuation 转换。
final class RealHealthStore: HealthStoring {
    static let shared = RealHealthStore()

    private let store = HKHealthStore()

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: typesToShare, read: typesToRead) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func execute(_ query: HKQuery) {
        store.execute(query)
    }

    func stop(_ query: HKQuery) {
        store.stop(query)
    }

    func save(_ object: HKObject) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(object) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteObjects(of objectType: HKSampleType, predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            store.deleteObjects(of: objectType, predicate: predicate) { _, deletedCount, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: deletedCount)
                }
            }
        }
    }

    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: type, frequency: frequency) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func disableBackgroundDelivery(for type: HKObjectType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.disableBackgroundDelivery(for: type) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func samples(of sampleType: HKSampleType, predicate: NSPredicate?, limit: Int) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
    }

    func workouts(predicate: NSPredicate?, limit: Int) async throws -> [HKWorkout] {
        let result = try await samples(of: .workoutType(), predicate: predicate, limit: limit)
        return result.compactMap { $0 as? HKWorkout }
    }

    func anchoredWorkouts(anchor: HKQueryAnchor?) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: .workoutType(),
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    continuation.resume(returning: (workouts, newAnchor))
                }
            }
            store.execute(query)
        }
    }
}
