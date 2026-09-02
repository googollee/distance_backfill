import HealthKit
import XCTest
@testable import DistanceBackfill

final class WorkoutActivityDistanceMappingTests: XCTestCase {
    func testCyclingMapsToDistanceCycling() {
        XCTAssertEqual(
            WorkoutActivityDistanceMapping.distanceTypeIdentifier(for: .cycling),
            .distanceCycling
        )
    }

    func testRunningAndWalkingAndHikingMapToDistanceWalkingRunning() {
        for activity: HKWorkoutActivityType in [.running, .walking, .hiking] {
            XCTAssertEqual(
                WorkoutActivityDistanceMapping.distanceTypeIdentifier(for: activity),
                .distanceWalkingRunning
            )
        }
    }

    func testUnsupportedActivityHasNoMapping() {
        XCTAssertNil(WorkoutActivityDistanceMapping.distanceTypeIdentifier(for: .traditionalStrengthTraining))
        XCTAssertNil(WorkoutActivityDistanceMapping.distanceTypeIdentifier(for: .yoga))
    }

    func testQuantityTypeResolvesForMappedActivity() {
        XCTAssertNotNil(WorkoutActivityDistanceMapping.quantityType(for: .cycling))
    }

    func testAllDistanceQuantityTypesIsNonEmptyAndDeduplicated() {
        let types = WorkoutActivityDistanceMapping.allDistanceQuantityTypes
        // cycling/handCycling 都映射到 distanceCycling，去重后应少于映射表条目数
        XCTAssertLessThan(types.count, WorkoutActivityDistanceMapping.table.count)
        XCTAssertFalse(types.isEmpty)
    }
}
