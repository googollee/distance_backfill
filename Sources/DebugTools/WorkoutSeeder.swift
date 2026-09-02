#if DEBUG
import HealthKit

/// 仅 DEBUG 编译。用于在没有真机/真实 Zepp 数据的情况下，在模拟器里复现
/// "训练有距离统计、但没有独立距离 sample" 的场景，验证 backfill 逻辑是否真的生效。
///
/// 关键点：必须用旧式 HKWorkout(activityType:...totalDistance:...) 初始化器（把距离存成
/// workout 自身的聚合属性），不能用 HKWorkoutBuilder.addSamples —— 后者会顺带写入一条真正
/// 独立的 sample，无法复现要修的问题。
enum WorkoutSeeder {
    @available(*, deprecated, message: "刻意使用已废弃的 HKWorkout 旧式初始化器以复现 Zepp 的写入 bug，见函数上方注释")
    static func seedProblemWorkout(
        activityType: HKWorkoutActivityType = .cycling,
        distanceMeters: Double = 15000,
        start: Date = Date().addingTimeInterval(-3600),
        end: Date = Date(),
        using store: HealthStoring
    ) async throws -> HKWorkout {
        let workout = HKWorkout(
            activityType: activityType,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
            device: nil,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )
        try await store.save(workout)
        return workout
    }

    /// 对照组：训练本身已经有一条独立距离 sample，用于验证"判重后跳过"分支。
    @available(*, deprecated, message: "调用了已废弃的 seedProblemWorkout")
    static func seedAlreadyCompleteWorkout(
        activityType: HKWorkoutActivityType = .cycling,
        distanceMeters: Double = 8000,
        start: Date = Date().addingTimeInterval(-7200),
        end: Date = Date().addingTimeInterval(-5400),
        using store: HealthStoring
    ) async throws -> HKWorkout {
        let workout = try await seedProblemWorkout(
            activityType: activityType, distanceMeters: distanceMeters, start: start, end: end, using: store
        )
        if let distanceType = WorkoutActivityDistanceMapping.quantityType(for: activityType) {
            let sample = HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
                start: start,
                end: end
            )
            try await store.save(sample)
        }
        return workout
    }

    /// 对照组：无距离语义的运动类型（力量训练），用于验证"不处理"分支。
    @available(*, deprecated, message: "刻意使用已废弃的 HKWorkout 旧式初始化器以复现 Zepp 的写入 bug")
    static func seedUnsupportedActivityWorkout(
        start: Date = Date().addingTimeInterval(-1800),
        end: Date = Date(),
        using store: HealthStoring
    ) async throws -> HKWorkout {
        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: nil,
            device: nil,
            metadata: nil
        )
        try await store.save(workout)
        return workout
    }

    /// 直接查询打印指定时间窗口内某类型的独立距离 sample 数量/总和。
    /// 模拟器没有 Health.app，无法肉眼查看汇总，只能靠这个确认 backfill 是否生效。
    static func inspectDistanceSamples(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        using store: HealthStoring
    ) async -> String {
        guard let distanceType = WorkoutActivityDistanceMapping.quantityType(for: activityType) else {
            return "该运动类型无对应距离类型"
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        guard let samples = try? await store.samples(of: distanceType, predicate: predicate, limit: HKObjectQueryNoLimit) else {
            return "查询失败"
        }
        let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
        let total = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .meter()) }
        return "找到 \(quantitySamples.count) 条独立距离数据，合计 \(String(format: "%.1f", total)) 米"
    }

    /// 清空所有本 App 写入的数据（按 HKSource.default() 限定），方便反复测试。
    static func clearAllAppData(using store: HealthStoring) async {
        let predicate = HKQuery.predicateForObjects(from: .default())
        for quantityType in WorkoutActivityDistanceMapping.allDistanceQuantityTypes {
            _ = try? await store.deleteObjects(of: quantityType, predicate: predicate)
        }
    }
}
#endif
