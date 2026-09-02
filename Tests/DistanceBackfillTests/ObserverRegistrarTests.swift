import HealthKit
import XCTest
@testable import DistanceBackfill

final class ObserverRegistrarTests: XCTestCase {
    private func makeIsolatedAnchorStore() -> AnchorStore {
        let suiteName = "ObserverRegistrarTests-\(UUID().uuidString)"
        return AnchorStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    @available(*, deprecated, message: "构造纯内存 HKWorkout 没有非 deprecated 的等价写法")
    private func makeWorkoutWithDistance() -> HKWorkout {
        HKWorkout(
            activityType: .cycling,
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            workoutEvents: nil,
            totalEnergyBurned: nil,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 10_000),
            device: nil,
            metadata: nil
        )
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testFirstRunEstablishesBaselineWithoutProcessing() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let anchorStore = makeIsolatedAnchorStore()
        let newAnchor = HKQueryAnchor(fromValue: 1)
        fakeStore.anchoredResult = (workouts: [makeWorkoutWithDistance()], newAnchor: newAnchor)

        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: anchorStore,
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: recordStore)
        )

        await registrar.handleUpdate()

        let records = await recordStore.fetchAll()
        XCTAssertTrue(records.isEmpty, "首次运行不应该处理任何训练")
        XCTAssertNotNil(anchorStore.load(), "首次运行应该把这次的 anchor 存下来作为基线")
    }

    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testSubsequentRunProcessesNewWorkouts() async {
        let fakeStore = FakeHealthStore()
        let recordStore = FakeSyncRecordStore()
        let anchorStore = makeIsolatedAnchorStore()
        anchorStore.save(HKQueryAnchor(fromValue: 0))   // 模拟"不是第一次运行"
        fakeStore.anchoredResult = (workouts: [makeWorkoutWithDistance()], newAnchor: HKQueryAnchor(fromValue: 1))

        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: anchorStore,
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: recordStore)
        )

        await registrar.handleUpdate()

        let records = await recordStore.fetchAll()
        XCTAssertEqual(records.count, 1, "非首次运行应该正常处理查到的训练")
    }

    /// 复现代码审查发现的问题：AppDelegate、RootView、PermissionsView 等多处调用点都可能在
    /// 同一次运行中触发注册，若不做幂等保护，每次调用都会新建一个 HKObserverQuery 并覆盖
    /// observerQuery，导致前一个查询脱离追踪、disable() 也只能停到最后一个。
    func testRegisterIsIdempotent() async {
        let fakeStore = FakeHealthStore()
        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: makeIsolatedAnchorStore(),
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: FakeSyncRecordStore())
        )

        await registrar.registerAndEnableBackgroundDelivery()
        await registrar.registerAndEnableBackgroundDelivery()
        await registrar.registerAndEnableBackgroundDelivery()

        XCTAssertEqual(fakeStore.executeCallCount, 1, "重复调用不应该创建多个 HKObserverQuery")

        await registrar.disable()
        XCTAssertEqual(fakeStore.stopCallCount, 1, "disable() 应该能停掉唯一那个存活的查询")

        // disable() 之后重新注册应该能正常生效，不会被幂等保护误挡住
        await registrar.registerAndEnableBackgroundDelivery()
        XCTAssertEqual(fakeStore.executeCallCount, 2, "disable() 之后应该允许重新注册")
    }

    /// 对应 ADR-005 决策1：disable() 不靠短路实现幂等，而是每一步本身对"已经是目标状态"的
    /// 输入天然无害——重复调用不应该崩溃，也不应该产生错误状态。
    func testDisableIsSafeToCallRepeatedly() async {
        let fakeStore = FakeHealthStore()
        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: makeIsolatedAnchorStore(),
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: FakeSyncRecordStore())
        )

        await registrar.disable()
        await registrar.disable()

        XCTAssertEqual(fakeStore.stopCallCount, 0, "从未注册过，没有可停的查询")
        XCTAssertEqual(fakeStore.disableBackgroundDeliveryCallCount, 2, "每次调用都应该真正对系统发出撤销请求")
    }

    func testDisableStopsQueryAndDisablesBackgroundDelivery() async {
        let fakeStore = FakeHealthStore()
        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: makeIsolatedAnchorStore(),
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: FakeSyncRecordStore())
        )

        await registrar.registerAndEnableBackgroundDelivery()
        await registrar.disable()

        XCTAssertEqual(fakeStore.stopCallCount, 1, "应该停掉当前存活的 HKObserverQuery")
        XCTAssertEqual(fakeStore.disableBackgroundDeliveryCallCount, 1, "应该显式撤销系统的后台投递")
    }

    /// 复现用户反馈的问题：HKObserverQuery 可能针对同一批变更并发触发多次 updateHandler，
    /// handleUpdate() 目前没有并发保护，会导致同一条训练被处理两次、写入两条重复记录。
    @available(*, deprecated, message: "依赖上面的 deprecated fixture")
    func testConcurrentHandleUpdateCallsDoNotWriteDuplicateRecords() async {
        let fakeStore = FakeHealthStore()
        fakeStore.shouldYield = true
        let recordStore = FakeSyncRecordStore()
        let anchorStore = makeIsolatedAnchorStore()
        anchorStore.save(HKQueryAnchor(fromValue: 0))   // 不是第一次运行，走真正处理分支
        fakeStore.anchoredResult = (workouts: [makeWorkoutWithDistance()], newAnchor: HKQueryAnchor(fromValue: 1))

        let registrar = ObserverRegistrar(
            store: fakeStore,
            anchorStore: anchorStore,
            queryService: WorkoutQueryService(),
            backfillService: DistanceBackfillService(recordStore: recordStore)
        )

        // 模拟 HKObserverQuery 针对同一批变更并发触发两次 updateHandler
        async let first: Void = registrar.handleUpdate()
        async let second: Void = registrar.handleUpdate()
        _ = await (first, second)

        let records = await recordStore.fetchAll()
        XCTAssertEqual(records.count, 1, "并发触发不应该写入重复记录，但实际写入了 \(records.count) 条")
    }
}
