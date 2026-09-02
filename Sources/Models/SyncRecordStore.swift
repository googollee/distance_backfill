import Foundation
import SwiftData

/// 供后台/非 UI 代码（backfill、undo、staleness 检查）访问 SyncRecord 的抽象，
/// 便于单元测试用内存实现替换，不依赖真实 SwiftData 容器。
protocol SyncRecordStoring: Sendable {
    func insert(_ record: SyncRecordDTO) async
    func fetchAll() async -> [SyncRecordDTO]
    func delete(writtenSampleUUID: UUID) async
}

/// 用 @ModelActor 而不是手动包一个 ModelContext：这是 SwiftData 官方提供的、专门给
/// 后台代码用的模式，能保证这里的写入和 View 层 @Query 用的主 context 之间正确同步/合并，
/// 不需要自己处理跨 context 的变更通知。
@ModelActor
actor SwiftDataSyncRecordStore: SyncRecordStoring {
    static let shared = SwiftDataSyncRecordStore(modelContainer: PersistenceController.shared.container)

    func insert(_ record: SyncRecordDTO) async {
        modelContext.insert(SyncRecord(dto: record))
        try? modelContext.save()
    }

    func fetchAll() async -> [SyncRecordDTO] {
        let descriptor = FetchDescriptor<SyncRecord>(sortBy: [SortDescriptor(\.syncedAt, order: .reverse)])
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.asDTO)
    }

    func delete(writtenSampleUUID: UUID) async {
        let descriptor = FetchDescriptor<SyncRecord>(
            predicate: #Predicate { $0.writtenSampleUUID == writtenSampleUUID }
        )
        guard let records = try? modelContext.fetch(descriptor) else { return }
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}
