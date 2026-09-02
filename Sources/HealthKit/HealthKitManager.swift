import HealthKit

enum HealthKitManager {
    static let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        types.formUnion(WorkoutActivityDistanceMapping.allDistanceQuantityTypes)
        return types
    }()

    static let writeTypes: Set<HKSampleType> = WorkoutActivityDistanceMapping.allDistanceQuantityTypes

    static func requestAuthorizationIfNeeded(using store: HealthStoring) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.healthDataUnavailable
        }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }
}
