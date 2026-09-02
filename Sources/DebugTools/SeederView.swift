#if DEBUG
import HealthKit
import SwiftUI

struct SeederView: View {
    @State private var log: String = ""
    private let store: HealthStoring = RealHealthStore.shared

    @available(*, deprecated, message: "内部按钮调用了 deprecated 的 seedProblem/seedAlreadyComplete/seedUnsupportedActivity")
    var body: some View {
        List {
            Section("生成测试数据") {
                Button("生成问题训练（骑行 15km，无独立距离）") { seedProblem() }
                Button("生成已补全训练（骑行 8km，已有独立距离）") { seedAlreadyComplete() }
                Button("生成无距离语义训练（力量训练）") { seedUnsupportedActivity() }
            }
            Section("清理") {
                Button("清空本 App 写入的数据", role: .destructive) {
                    Task {
                        await WorkoutSeeder.clearAllAppData(using: store)
                        log = "已清空"
                    }
                }
            }
            if !log.isEmpty {
                Section("日志") {
                    Text(log).font(.footnote)
                }
            }
        }
        .navigationTitle("调试工具")
    }

    @available(*, deprecated, message: "调用了 deprecated 的 WorkoutSeeder.seedProblemWorkout")
    private func seedProblem() {
        runSeed { try await WorkoutSeeder.seedProblemWorkout(using: store) }
    }

    @available(*, deprecated, message: "调用了 deprecated 的 WorkoutSeeder.seedAlreadyCompleteWorkout")
    private func seedAlreadyComplete() {
        runSeed { try await WorkoutSeeder.seedAlreadyCompleteWorkout(using: store) }
    }

    @available(*, deprecated, message: "调用了 deprecated 的 WorkoutSeeder.seedUnsupportedActivityWorkout")
    private func seedUnsupportedActivity() {
        runSeed { try await WorkoutSeeder.seedUnsupportedActivityWorkout(using: store) }
    }

    private func runSeed(_ action: @escaping () async throws -> HKWorkout) {
        Task {
            do {
                let workout = try await action()
                log = "已写入训练：\(workout.uuid.uuidString.prefix(8))"
            } catch {
                log = "失败：\(error.localizedDescription)"
            }
        }
    }
}
#endif
