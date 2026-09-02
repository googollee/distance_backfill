import HealthKit

/// 后台自动补全的入口（对应 PRD-001 功能需求3"后台自动" / ADR-001 方案设计 5 / ADR-005）。
/// 外部一律通过 syncRegistration(enabled:) 按偏好值对齐状态，不直接调用 registerAndEnableBackgroundDelivery()/disable()。
/// AppDelegate.didFinishLaunchingWithOptions 必须调用一次 syncRegistration(enabled:)，
/// 这是唯一保证每次进程启动（无论用户手动打开还是系统后台唤醒）都会执行到的钩子。
///
/// 用 actor 而不是普通 class：HKObserverQuery 可能针对同一批变更并发触发多次 updateHandler，
/// handleUpdate() 内部有多次 await（判重、写入之间不是原子操作），普通 class 里两次并发调用
/// 会各自读到同一个旧 anchor、各自完成"判重→写入"，导致同一条训练被写入两次重复记录。
/// actor 保证 isHandlingUpdate 这个标记的检查和设置本身线程安全，从而实现正确的串行化保护。
actor ObserverRegistrar {
    static let shared = ObserverRegistrar()

    private let store: HealthStoring
    private let anchorStore: AnchorStore
    private let queryService: WorkoutQueryService
    private let backfillService: DistanceBackfillService

    /// 必须被持有，否则 HKObserverQuery 会被 ARC 提前释放，静默收不到后续回调。
    private var observerQuery: HKObserverQuery?

    /// 同一时间只允许一次 handleUpdate() 真正在处理，防止并发触发写入重复记录。
    private var isHandlingUpdate = false

    init(
        store: HealthStoring = RealHealthStore.shared,
        anchorStore: AnchorStore = AnchorStore(),
        queryService: WorkoutQueryService = WorkoutQueryService(),
        backfillService: DistanceBackfillService = .shared
    ) {
        self.store = store
        self.anchorStore = anchorStore
        self.queryService = queryService
        self.backfillService = backfillService
    }

    func registerAndEnableBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // 幂等保护：AppDelegate、RootView、PermissionsView 等多处调用点都可能在同一次运行中
        // 触发这个方法。若不做保护，重复调用会各自创建一个新的 HKObserverQuery 并覆盖
        // observerQuery，导致前一个查询既没被 stop() 也不再被引用，disable() 也只能停到
        // 最后一个——已注册就直接跳过，避免出现脱离追踪的查询。
        guard observerQuery == nil else { return }

        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }
            if let error {
                AppLogger.observer.error("HKObserverQuery 回调出错: \(error.localizedDescription)")
                completionHandler()
                return
            }
            Task {
                await self.handleUpdate()
                completionHandler()
            }
        }
        observerQuery = query
        store.execute(query)

        Task {
            do {
                try await store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)
            } catch {
                AppLogger.observer.error("enableBackgroundDelivery 失败: \(error.localizedDescription)")
            }
        }
    }

    /// 关闭自动补全（对应 ADR-003）：停掉当前存活的观察者查询，并显式撤销系统的后台投递——
    /// enableBackgroundDelivery 的效果是系统持久化的，仅仅不再注册不会让系统主动停止投递。
    func disable() async {
        if let observerQuery {
            store.stop(observerQuery)
        }
        observerQuery = nil

        do {
            try await store.disableBackgroundDelivery(for: .workoutType())
        } catch {
            AppLogger.observer.error("disableBackgroundDelivery 失败: \(error.localizedDescription)")
        }
    }

    /// 按偏好值对齐注册状态（对应 ADR-005 决策2）：开则 register，关则 disable。
    /// 两个方法各自已经能安全地被多次调用（ADR-005 决策1），调用方不需要自己判断是否已经调用过。
    static func syncRegistration(enabled: Bool) async {
        if enabled {
            await shared.registerAndEnableBackgroundDelivery()
        } else {
            await shared.disable()
        }
    }

    func handleUpdate() async {
        guard !isHandlingUpdate else {
            AppLogger.sync.info("已有一次同步在处理中，跳过这次重复触发")
            return
        }
        isHandlingUpdate = true
        defer { isHandlingUpdate = false }

        let anchor = anchorStore.load()
        do {
            let (workouts, newAnchor) = try await queryService.fetchNewWorkouts(anchor: anchor, using: store)

            guard anchor != nil else {
                // 首次建立 anchor 基线：不把当前已存在的训练当"新数据"处理（对应 ADR-002）
                if let newAnchor {
                    anchorStore.save(newAnchor)
                }
                AppLogger.sync.info("首次建立 anchor 基线，跳过 \(workouts.count) 条已存在训练")
                return
            }

            let results = await backfillService.processBatch(workouts: workouts, using: store)
            if let newAnchor {
                anchorStore.save(newAnchor)
            }
            AppLogger.sync.info("后台同步处理了 \(results.count) 条训练记录")
        } catch {
            AppLogger.observer.error("后台增量查询失败: \(error.localizedDescription)")
        }
    }
}
