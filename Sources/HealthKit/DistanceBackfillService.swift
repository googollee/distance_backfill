import HealthKit

enum HealthKitMetadataKey {
    static let sourceWorkoutUUID = "im.googol.DistanceBackfill.sourceWorkoutUUID"
}

enum BackfillOutcome: Equatable {
    case written(quantityUUID: UUID, value: Double, unit: String)
    case skippedUnsupportedActivity
    case skippedNoDistanceStatistic
    case skippedAlreadyExists
    case failed(String)
}

/// 核心业务逻辑（对应 PRD-001 功能需求2 / ADR-001 方案设计 2、3）：
/// 判断运动类型对应的距离类型 → 读取训练自带统计 → 区间重叠判重 → 写入独立距离数据 → 落本地记录。
///
/// 用 actor 而不是普通 class：判重查询和写入之间隔着一次 await，不是原子操作。手动扫描
/// （ScanViewModel）和后台自动（ObserverRegistrar）是两个独立的执行上下文，如果各自持有
/// 一份独立实例，两边并发处理同一条训练时会各自查到"还不存在"、各自写入，产生重复记录
/// （对应 ADR-004）。所有调用方都应该使用 `shared` 这个共享实例，让并发调用能够串行化。
///
/// 光是 actor 还不够：actor 只保证内部状态读写不产生数据竞争，但对重入（reentrancy）不设防——
/// process() 内部有多次 await，两个并发调用一样会在这些挂起点之间交叉执行、都查到"还不存在"。
/// 这里用一个显式的异步互斥锁（acquireLock/releaseLock）包住整个 process()，保证同一时间只有
/// 一次真正在跑临界区。跟 ObserverRegistrar 的"跳过"策略不同：这里不能跳过，跳过会导致某条
/// 具体的训练永远没被处理，只能排队等待。
actor DistanceBackfillService {
    static let shared = DistanceBackfillService(recordStore: SwiftDataSyncRecordStore.shared)

    private let recordStore: SyncRecordStoring

    private var isLocked = false
    private var lockWaiters: [CheckedContinuation<Void, Never>] = []

    private func acquireLock() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            lockWaiters.append(continuation)
        }
    }

    private func releaseLock() {
        if lockWaiters.isEmpty {
            isLocked = false
        } else {
            lockWaiters.removeFirst().resume()
        }
    }

    init(recordStore: SyncRecordStoring) {
        self.recordStore = recordStore
    }

    func process(workout: HKWorkout, using store: HealthStoring) async -> BackfillOutcome {
        await acquireLock()
        defer { releaseLock() }

        guard let distanceType = WorkoutActivityDistanceMapping.quantityType(for: workout.workoutActivityType) else {
            return .skippedUnsupportedActivity
        }

        guard let sumQuantity = workout.statistics(for: distanceType)?.sumQuantity() else {
            return .skippedNoDistanceStatistic
        }

        // 判重：不加 strict 选项的 predicateForSamples 本身就是"区间有重叠即匹配"语义，
        // 不需要手写 sample.startDate < workout.endDate && sample.endDate > workout.startDate。
        let overlapPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
        do {
            let existing = try await store.samples(of: distanceType, predicate: overlapPredicate, limit: 1)
            if !existing.isEmpty {
                return .skippedAlreadyExists
            }
        } catch {
            return .failed(error.localizedDescription)
        }

        let unit = HKUnit.meter()
        let value = sumQuantity.doubleValue(for: unit)
        let sample = HKQuantitySample(
            type: distanceType,
            quantity: sumQuantity,
            start: workout.startDate,
            end: workout.endDate,
            metadata: [
                HealthKitMetadataKey.sourceWorkoutUUID: workout.uuid.uuidString,
                HKMetadataKeyWasUserEntered: false,
            ]
        )

        do {
            try await store.save(sample)
        } catch {
            return .failed(error.localizedDescription)
        }

        let record = SyncRecordDTO(
            writtenSampleUUID: sample.uuid,
            sourceWorkoutUUID: workout.uuid,
            quantityTypeIdentifier: distanceType.identifier,
            value: value,
            unitString: unit.unitString,
            workoutStartDate: workout.startDate,
            workoutEndDate: workout.endDate
        )
        await recordStore.insert(record)

        return .written(quantityUUID: sample.uuid, value: value, unit: unit.unitString)
    }

    func processBatch(workouts: [HKWorkout], using store: HealthStoring) async -> [(HKWorkout, BackfillOutcome)] {
        var results: [(HKWorkout, BackfillOutcome)] = []
        for workout in workouts {
            let outcome = await process(workout: workout, using: store)
            results.append((workout, outcome))
        }
        return results
    }
}
