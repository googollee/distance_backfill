import HealthKit
@testable import DistanceBackfill

final class FakeHealthStore: HealthStoring {
    var savedObjects: [HKObject] = []
    var existingSamplesByType: [HKQuantityType: [HKSample]] = [:]
    var workoutsToReturn: [HKWorkout] = []
    var anchoredResult: (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) = ([], nil)
    var saveError: Error?
    var deleteCountOverride: Int = 0
    var deleteCalls: [(HKSampleType, NSPredicate)] = []
    var stopCallCount = 0
    var disableBackgroundDeliveryCallCount = 0
    var executeCallCount = 0

    /// 打开后，关键异步方法会真正让出执行权（`Task.yield()`），逼两个并发调用交叉执行，
    /// 用来确定性地复现竞态问题，而不是依赖偶发的调度顺序。
    var shouldYield = false

    private func maybeYield() async {
        if shouldYield {
            await Task.yield()
        }
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {}

    func execute(_ query: HKQuery) {
        executeCallCount += 1
    }

    func stop(_ query: HKQuery) {
        stopCallCount += 1
    }

    func save(_ object: HKObject) async throws {
        await maybeYield()
        if let saveError {
            throw saveError
        }
        savedObjects.append(object)
        // 保存后要能被后续的 samples(of:) 查到，才能真实模拟 HealthKit 的行为——
        // 否则并发场景下，即便调用被正确串行化，第二次判重查询也永远看不到第一次刚写的数据。
        if let sample = object as? HKQuantitySample {
            existingSamplesByType[sample.quantityType, default: []].append(sample)
        }
    }

    func deleteObjects(of objectType: HKSampleType, predicate: NSPredicate) async throws -> Int {
        deleteCalls.append((objectType, predicate))
        return deleteCountOverride
    }

    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws {}

    func disableBackgroundDelivery(for type: HKObjectType) async throws {
        disableBackgroundDeliveryCallCount += 1
    }

    func samples(of sampleType: HKSampleType, predicate: NSPredicate?, limit: Int) async throws -> [HKSample] {
        await maybeYield()
        guard let quantityType = sampleType as? HKQuantityType else { return [] }
        return existingSamplesByType[quantityType] ?? []
    }

    func workouts(predicate: NSPredicate?, limit: Int) async throws -> [HKWorkout] {
        workoutsToReturn
    }

    func anchoredWorkouts(anchor: HKQueryAnchor?) async throws -> (workouts: [HKWorkout], newAnchor: HKQueryAnchor?) {
        await maybeYield()
        return anchoredResult
    }
}

actor FakeSyncRecordStore: SyncRecordStoring {
    private(set) var records: [SyncRecordDTO] = []

    func insert(_ record: SyncRecordDTO) async {
        records.append(record)
    }

    func fetchAll() async -> [SyncRecordDTO] {
        records
    }

    func delete(writtenSampleUUID: UUID) async {
        records.removeAll { $0.writtenSampleUUID == writtenSampleUUID }
    }
}
