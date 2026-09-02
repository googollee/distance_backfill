import HealthKit
import XCTest
@testable import DistanceBackfill

final class StalenessCheckerTests: XCTestCase {
    private func makeRecord(sourceWorkoutUUID: UUID, value: Double) -> SyncRecord {
        SyncRecord(
            writtenSampleUUID: UUID(),
            sourceWorkoutUUID: sourceWorkoutUUID,
            quantityTypeIdentifier: HKQuantityTypeIdentifier.distanceCycling.rawValue,
            value: value,
            unitString: HKUnit.meter().unitString,
            workoutStartDate: Date(timeIntervalSince1970: 1_000_000),
            workoutEndDate: Date(timeIntervalSince1970: 1_003_600)
        )
    }

    @available(*, deprecated, message: "构造纯内存 HKWorkout 没有非 deprecated 的等价写法")
    private func makeWorkout(totalDistanceMeters: Double?) -> HKWorkout {
        HKWorkout(
            activityType: .cycling,
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: totalDistanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) },
            device: nil,
            metadata: nil
        )
    }

    func testMarksStaleWhenSourceWorkoutMissing() async {
        let fakeStore = FakeHealthStore()
        fakeStore.workoutsToReturn = []
        let record = makeRecord(sourceWorkoutUUID: UUID(), value: 10_000)

        let result = await StalenessChecker().checkStaleness(records: [record], using: fakeStore)

        XCTAssertEqual(result[record.writtenSampleUUID], true)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testMarksStaleWhenValueChangedBeyondTolerance() async {
        let fakeStore = FakeHealthStore()
        let workout = makeWorkout(totalDistanceMeters: 12_000)
        fakeStore.workoutsToReturn = [workout]
        let record = makeRecord(sourceWorkoutUUID: workout.uuid, value: 10_000)

        let result = await StalenessChecker().checkStaleness(records: [record], using: fakeStore)

        XCTAssertEqual(result[record.writtenSampleUUID], true)
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testNotStaleWhenValueMatches() async {
        let fakeStore = FakeHealthStore()
        let workout = makeWorkout(totalDistanceMeters: 10_000)
        fakeStore.workoutsToReturn = [workout]
        let record = makeRecord(sourceWorkoutUUID: workout.uuid, value: 10_000)

        let result = await StalenessChecker().checkStaleness(records: [record], using: fakeStore)

        XCTAssertEqual(result[record.writtenSampleUUID], false)
    }
}
