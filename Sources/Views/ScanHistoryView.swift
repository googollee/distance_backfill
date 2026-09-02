import SwiftUI

struct ScanHistoryView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        List {
            Section {
                Button {
                    Task { await viewModel.scanHistory() }
                } label: {
                    if viewModel.isScanning {
                        HStack {
                            ProgressView()
                            Text("扫描中 \(viewModel.progress.done)/\(viewModel.progress.total)")
                        }
                    } else {
                        Text("扫描历史")
                    }
                }
                .disabled(viewModel.isScanning)
            } footer: {
                Text("一次性检查所有历史训练，把缺失的独立距离数据补全。")
            }

            if let summary = viewModel.summary {
                Section("本次结果") {
                    LabeledContent("新写入", value: "\(summary.written)")
                    LabeledContent("已有数据，跳过", value: "\(summary.skippedExisting)")
                    LabeledContent("无距离统计，跳过", value: "\(summary.skippedNoDistance)")
                    LabeledContent("运动类型不支持", value: "\(summary.skippedUnsupported)")
                    if summary.failed > 0 {
                        LabeledContent("失败", value: "\(summary.failed)")
                            .foregroundStyle(.red)
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("扫描历史")
    }
}
