import HealthKit
import SwiftUI

struct RecordRowView: View {
    let record: SyncRecord
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(distanceText).font(.headline)
                if isStale {
                    Text("可能已过期")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
            Text(record.workoutStartDate, format: .dateTime.year().month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(typeLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var distanceText: String {
        String(format: "%.2f km", record.value / 1000)
    }

    private var typeLabel: LocalizedStringKey {
        switch record.quantityTypeIdentifier {
        case HKQuantityTypeIdentifier.distanceCycling.rawValue:
            return "骑行距离"
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            return "步行+跑步距离"
        case HKQuantityTypeIdentifier.distanceSwimming.rawValue:
            return "游泳距离"
        case HKQuantityTypeIdentifier.distanceRowing.rawValue:
            return "划船距离"
        case HKQuantityTypeIdentifier.distancePaddleSports.rawValue:
            return "桨类运动距离"
        case HKQuantityTypeIdentifier.distanceSkatingSports.rawValue:
            return "滑冰距离"
        case HKQuantityTypeIdentifier.distanceCrossCountrySkiing.rawValue:
            return "越野滑雪距离"
        case HKQuantityTypeIdentifier.distanceDownhillSnowSports.rawValue:
            return "高山滑雪距离"
        case HKQuantityTypeIdentifier.distanceWheelchair.rawValue:
            return "轮椅距离"
        default:
            return "距离"
        }
    }
}
