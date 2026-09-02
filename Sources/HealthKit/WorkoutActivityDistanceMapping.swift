import HealthKit

/// 运动类型 → 距离数据类型的静态映射表（对应 ADR-001 方案设计 1）。
/// 只覆盖具备"距离"语义的运动类型；不在表中的类型（力量训练、瑜伽等）视为不处理。
enum WorkoutActivityDistanceMapping {
    static let table: [HKWorkoutActivityType: HKQuantityTypeIdentifier] = [
        .cycling: .distanceCycling,
        .handCycling: .distanceCycling,

        .running: .distanceWalkingRunning,
        .walking: .distanceWalkingRunning,
        .hiking: .distanceWalkingRunning,

        .swimming: .distanceSwimming,

        .rowing: .distanceRowing,

        .paddleSports: .distancePaddleSports,

        .skatingSports: .distanceSkatingSports,

        .crossCountrySkiing: .distanceCrossCountrySkiing,

        .downhillSkiing: .distanceDownhillSnowSports,

        .wheelchairRunPace: .distanceWheelchair,
        .wheelchairWalkPace: .distanceWheelchair,
    ]

    static func distanceTypeIdentifier(for activityType: HKWorkoutActivityType) -> HKQuantityTypeIdentifier? {
        table[activityType]
    }

    static func quantityType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        guard let identifier = distanceTypeIdentifier(for: activityType) else { return nil }
        return HKQuantityType.quantityType(forIdentifier: identifier)
    }

    /// 映射表涉及到的全部距离类型集合（去重），用于统一申请读写权限。
    static var allDistanceQuantityTypes: Set<HKQuantityType> {
        Set(table.values.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }
}
