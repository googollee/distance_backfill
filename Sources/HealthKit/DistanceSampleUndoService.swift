import HealthKit

enum UndoOutcome: Equatable {
    case deleted
    case danglingCleanedUp
    case failed(String)
}

/// 撤销（对应 PRD-001 功能需求4 / ADR-001 方案设计 4）：
/// 按 writtenSampleUUID 一步完成"查找+删除"，deletedCount == 0 即视为悬空场景，静默清理本地记录不报错。
final class DistanceSampleUndoService {
    private let recordStore: SyncRecordStoring

    init(recordStore: SyncRecordStoring) {
        self.recordStore = recordStore
    }

    func undo(_ record: SyncRecord, using store: HealthStoring) async -> UndoOutcome {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: record.quantityTypeIdentifier)) else {
            return .failed(String(localized: "未知的数据类型：\(record.quantityTypeIdentifier)"))
        }

        let predicate = HKQuery.predicateForObject(with: record.writtenSampleUUID)
        do {
            let deletedCount = try await store.deleteObjects(of: quantityType, predicate: predicate)
            await recordStore.delete(writtenSampleUUID: record.writtenSampleUUID)
            return deletedCount > 0 ? .deleted : .danglingCleanedUp
        } catch {
            AppLogger.undo.error("撤销失败: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    func undoBatch(_ records: [SyncRecord], using store: HealthStoring) async -> [UUID: UndoOutcome] {
        var outcomes: [UUID: UndoOutcome] = [:]
        for record in records {
            outcomes[record.writtenSampleUUID] = await undo(record, using: store)
        }
        return outcomes
    }
}
