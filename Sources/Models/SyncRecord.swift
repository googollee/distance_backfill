import Foundation
import SwiftData

/// 本 App 每次向健康 App 写入距离数据后留下的本地记录（对应 ADR-001 方案设计 4）。
/// 存储随 App 沙盒走：卸载重装会丢失，这是 PRD-001"已知限制"里明确接受的行为。
@Model
final class SyncRecord {
    @Attribute(.unique) var writtenSampleUUID: UUID
    var sourceWorkoutUUID: UUID
    var quantityTypeIdentifier: String
    var value: Double
    var unitString: String
    var workoutStartDate: Date
    var workoutEndDate: Date
    var syncedAt: Date

    init(
        writtenSampleUUID: UUID,
        sourceWorkoutUUID: UUID,
        quantityTypeIdentifier: String,
        value: Double,
        unitString: String,
        workoutStartDate: Date,
        workoutEndDate: Date,
        syncedAt: Date = .now
    ) {
        self.writtenSampleUUID = writtenSampleUUID
        self.sourceWorkoutUUID = sourceWorkoutUUID
        self.quantityTypeIdentifier = quantityTypeIdentifier
        self.value = value
        self.unitString = unitString
        self.workoutStartDate = workoutStartDate
        self.workoutEndDate = workoutEndDate
        self.syncedAt = syncedAt
    }
}

/// SyncRecord 是 @Model 类，实例与某个 ModelContext 绑定，不能安全地跨 actor 边界传递
/// （试过直接标 Sendable，会跟 @Model 宏自己生成的一致性冲突）。这个 DTO 镜像 SyncRecord
/// 的字段，专门用于 SyncRecordStoring 协议跨 actor 传递数据——转换只发生在持有
/// ModelContext 的那个 actor（SwiftDataSyncRecordStore）内部，SyncRecord 本身从不跨界。
struct SyncRecordDTO: Sendable, Equatable {
    let writtenSampleUUID: UUID
    let sourceWorkoutUUID: UUID
    let quantityTypeIdentifier: String
    let value: Double
    let unitString: String
    let workoutStartDate: Date
    let workoutEndDate: Date
    let syncedAt: Date

    init(
        writtenSampleUUID: UUID,
        sourceWorkoutUUID: UUID,
        quantityTypeIdentifier: String,
        value: Double,
        unitString: String,
        workoutStartDate: Date,
        workoutEndDate: Date,
        syncedAt: Date = .now
    ) {
        self.writtenSampleUUID = writtenSampleUUID
        self.sourceWorkoutUUID = sourceWorkoutUUID
        self.quantityTypeIdentifier = quantityTypeIdentifier
        self.value = value
        self.unitString = unitString
        self.workoutStartDate = workoutStartDate
        self.workoutEndDate = workoutEndDate
        self.syncedAt = syncedAt
    }
}

extension SyncRecord {
    convenience init(dto: SyncRecordDTO) {
        self.init(
            writtenSampleUUID: dto.writtenSampleUUID,
            sourceWorkoutUUID: dto.sourceWorkoutUUID,
            quantityTypeIdentifier: dto.quantityTypeIdentifier,
            value: dto.value,
            unitString: dto.unitString,
            workoutStartDate: dto.workoutStartDate,
            workoutEndDate: dto.workoutEndDate,
            syncedAt: dto.syncedAt
        )
    }

    var asDTO: SyncRecordDTO {
        SyncRecordDTO(
            writtenSampleUUID: writtenSampleUUID,
            sourceWorkoutUUID: sourceWorkoutUUID,
            quantityTypeIdentifier: quantityTypeIdentifier,
            value: value,
            unitString: unitString,
            workoutStartDate: workoutStartDate,
            workoutEndDate: workoutEndDate,
            syncedAt: syncedAt
        )
    }
}
