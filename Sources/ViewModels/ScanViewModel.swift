import Foundation

struct ScanSummary {
    var written = 0
    var skippedExisting = 0
    var skippedNoDistance = 0
    var skippedUnsupported = 0
    var failed = 0
}

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var progress: (done: Int, total: Int) = (0, 0)
    @Published var summary: ScanSummary?
    @Published var errorMessage: String?

    private let store: HealthStoring
    private let queryService = WorkoutQueryService()
    private let backfillService: DistanceBackfillService
    private let anchorStore = AnchorStore()
    private let batchSize = 50

    init(
        store: HealthStoring = RealHealthStore.shared,
        backfillService: DistanceBackfillService = .shared
    ) {
        self.store = store
        self.backfillService = backfillService
    }

    /// 对应 PRD-001 功能需求3"手动批量"：一次性处理所有历史训练中缺失的部分。
    func scanHistory() async {
        isScanning = true
        summary = nil
        errorMessage = nil
        defer { isScanning = false }

        do {
            let (workouts, newAnchor) = try await queryService.fetchAllWorkouts(using: store)
            progress = (0, workouts.count)

            var result = ScanSummary()
            for batchStart in stride(from: 0, to: workouts.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, workouts.count)
                let batch = Array(workouts[batchStart..<batchEnd])
                let outcomes = await backfillService.processBatch(workouts: batch, using: store)
                for (_, outcome) in outcomes {
                    switch outcome {
                    case .written: result.written += 1
                    case .skippedAlreadyExists: result.skippedExisting += 1
                    case .skippedNoDistanceStatistic: result.skippedNoDistance += 1
                    case .skippedUnsupportedActivity: result.skippedUnsupported += 1
                    case .failed: result.failed += 1
                    }
                }
                progress = (batchEnd, workouts.count)
            }

            if let newAnchor {
                anchorStore.save(newAnchor)
            }
            summary = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
