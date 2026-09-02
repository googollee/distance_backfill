import HealthKit
import XCTest
@testable import DistanceBackfill

final class DistanceBackfillServiceTests: XCTestCase {
    @available(*, deprecated, message: "构造纯内存 HKWorkout 没有非 deprecated 的等价写法")
    private func makeWorkout(
        activityType: HKWorkoutActivityType,
        totalDistanceMeters: Double?
    ) -> HKWorkout {
        HKWorkout(
            activityType: activityType,
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: totalDistanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            device: nil,
            metadata: nil
        )
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testSkipsUnsupportedActivity() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .traditionalStrengthTraining, totalDistanceMeters: nil)

        let outcome = await service.process(workout: workout, using: fakeStore)

        XCTAssertEqual(outcome, .skippedUnsupportedActivity)
        XCTAssertTrue(fakeStore.savedObjects.isEmpty)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testSkipsWhenNoDistanceStatistic() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .cycling, totalDistanceMeters: nil)

        let outcome = await service.process(workout: workout, using: fakeStore)

        XCTAssertEqual(outcome, .skippedNoDistanceStatistic)
        XCTAssertTrue(fakeStore.savedObjects.isEmpty)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testSkipsWhenAlreadyExists() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .cycling, totalDistanceMeters: 10_000)

        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else {
            return XCTFail("distanceCycling 类型不可用")
        }
        let existingSample = HKQuantitySample(
            type: distanceType,
            quantity: HKQuantity(unit: .meter(), doubleValue: 5_000),
            start: workout.startDate,
            end: workout.endDate
        )
        fakeStore.existingSamplesByType[distanceType] = [existingSample]

        let outcome = await service.process(workout: workout, using: fakeStore)

        XCTAssertEqual(outcome, .skippedAlreadyExists)
        XCTAssertTrue(fakeStore.savedObjects.isEmpty)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testWritesNewSampleWhenMissing() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .cycling, totalDistanceMeters: 10_000)

        let outcome = await service.process(workout: workout, using: fakeStore)

        guard case .written(_, let value, let unit) = outcome else {
            return XCTFail("期望 .written，实际是 \(outcome)")
        }
        XCTAssertEqual(value, 10_000, accuracy: 0.001)
        XCTAssertEqual(unit, "m")
        XCTAssertEqual(fakeStore.savedObjects.count, 1)

        let records = await recordStore.fetchAll()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.sourceWorkoutUUID, workout.uuid)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testSaveFailurePropagatesAsFailedOutcome() async {
        let fakeStore = FakeHealthStore()
        fakeStore.saveError = NSError(domain: "test", code: 1)
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .cycling, totalDistanceMeters: 10_000)

        let outcome = await service.process(workout: workout, using: fakeStore)

        guard case .failed = outcome else {
            return XCTFail("期望 .failed，实际是 \(outcome)")
        }
        let records = await recordStore.fetchAll()
        XCTAssertTrue(records.isEmpty)
    }

    /// 对应 ADR-004 第2条：手动扫描和后台自动是两个独立的执行上下文，如果各自并发调用
    /// process()，靠共享同一个 DistanceBackfillService actor 实例来保证不会重复写入。
    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testConcurrentProcessCallsOnSharedInstanceDoNotWriteDuplicates() async {
        let fakeStore = FakeHealthStore()
        fakeStore.shouldYield = true
        let recordStore = FakeSyncRecordStore()
        let service = DistanceBackfillService(recordStore: recordStore)
        let workout = makeWorkout(activityType: .cycling, totalDistanceMeters: 10_000)

        // 模拟手动扫描和后台自动同时处理同一条训练
        async let first: BackfillOutcome = service.process(workout: workout, using: fakeStore)
        async let second: BackfillOutcome = service.process(workout: workout, using: fakeStore)
        _ = await (first, second)

        let records = await recordStore.fetchAll()
        XCTAssertEqual(records.count, 1, "共享 actor 应该保证并发调用也只写入一条记录，但实际写入了 \(records.count) 条")
    }
}
