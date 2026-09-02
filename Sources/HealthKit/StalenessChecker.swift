import HealthKit

/// 过期提示（对应 PRD-001 功能需求6 / ADR-001 已知风险第2条）：
/// 比较训练记录当前的距离统计值与本地记录里保存的 value 是否一致，判断是否需要标记"可能已过期"。
final class StalenessChecker {
    private let relativeTolerance = 0.005 // 0.5%

    func checkStaleness(records: [SyncRecord], using store: HealthStoring) async -> [UUID: Bool] {
        var results: [UUID: Bool] = [:]
        for record in records {
            results[record.writtenSampleUUID] = await isStale(record, using: store)
        }
        return results
    }

    private func isStale(_ record: SyncRecord, using store: HealthStoring) async -> Bool {
        guard let quantityType = HKQuantityType.quantityType(
            forIdentifier: HKQuantityTypeIdentifier(rawValue: record.quantityTypeIdentifier)
        ) else {
            return false
        }

        let predicate = HKQuery.predicateForObject(with: record.sourceWorkoutUUID)
        guard let workouts = try? await store.workouts(predicate: predicate, limit: 1),
              let workout = workouts.first else {
            // 源训练记录本身查不到了（可能已被删除），一并标记为需要关注
            return true
        }

        guard let currentSum = workout.statistics(for: quantityType)?.sumQuantity() else {
            return true
        }

        let currentValue = currentSum.doubleValue(for: HKUnit(from: record.unitString))
        guard record.value != 0 else {
            return currentValue != 0
        }
        let relativeDiff = abs(currentValue - record.value) / abs(record.value)
        return relativeDiff > relativeTolerance
    }
}
