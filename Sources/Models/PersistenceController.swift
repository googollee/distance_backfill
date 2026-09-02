import SwiftData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        container = try! ModelContainer(for: SyncRecord.self)
    }
}
