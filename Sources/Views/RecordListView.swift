import SwiftData
import SwiftUI

struct RecordListView: View {
    @Query(sort: \SyncRecord.syncedAt, order: .reverse) private var records: [SyncRecord]
    @StateObject private var viewModel = RecordListViewModel()
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()

    var body: some View {
        List(selection: $selection) {
            ForEach(records, id: \.writtenSampleUUID) { record in
                RecordRowView(record: record, isStale: viewModel.staleness[record.writtenSampleUUID] ?? false)
                    .tag(record.writtenSampleUUID)
                    .swipeActions {
                        Button("撤销", role: .destructive) {
                            Task { await viewModel.undo(record) }
                        }
                    }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("已写入记录")
        .toolbar {
            if editMode.isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        selection.removeAll()
                        editMode = .inactive
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("删除", role: .destructive) {
                        let toDelete = records.filter { selection.contains($0.writtenSampleUUID) }
                        Task {
                            await viewModel.undoAll(toDelete)
                            selection.removeAll()
                            editMode = .inactive
                        }
                    }
                    .disabled(selection.isEmpty)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("编辑") {
                        editMode = .active
                    }
                }
            }
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("还没有写入记录", systemImage: "tray")
            }
        }
        .task(id: records.map(\.writtenSampleUUID)) {
            await viewModel.refreshStaleness(records: records)
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
