import Foundation

@MainActor
final class RecordListViewModel: ObservableObject {
    @Published var staleness: [UUID: Bool] = [:]
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let store: HealthStoring
    private let undoService: DistanceSampleUndoService
    private let stalenessChecker = StalenessChecker()

    init(
        store: HealthStoring = RealHealthStore.shared,
        recordStore: SyncRecordStoring = SwiftDataSyncRecordStore.shared
    ) {
        self.store = store
        self.undoService = DistanceSampleUndoService(recordStore: recordStore)
    }

    func refreshStaleness(records: [SyncRecord]) async {
        staleness = await stalenessChecker.checkStaleness(records: records, using: store)
    }

    func undo(_ record: SyncRecord) async {
        isBusy = true
        defer { isBusy = false }
        let outcome = await undoService.undo(record, using: store)
        if case .failed(let message) = outcome {
            errorMessage = message
        }
    }

    func undoAll(_ records: [SyncRecord]) async {
        isBusy = true
        defer { isBusy = false }
        let outcomes = await undoService.undoBatch(records, using: store)
        let failures = outcomes.values.compactMap { outcome -> String? in
            if case .failed(let message) = outcome { return message }
            return nil
        }
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
    }
}
