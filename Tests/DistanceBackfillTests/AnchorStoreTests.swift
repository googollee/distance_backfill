import HealthKit
import XCTest
@testable import DistanceBackfill

final class AnchorStoreTests: XCTestCase {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AnchorStoreTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func testLoadReturnsNilWhenNothingSaved() {
        let store = AnchorStore(defaults: makeIsolatedDefaults())
        XCTAssertNil(store.load())
    }

    func testSaveThenLoadRoundTrips() {
        let defaults = makeIsolatedDefaults()
        let store = AnchorStore(defaults: defaults)
        let anchor = HKQueryAnchor(fromValue: 42)

        store.save(anchor)

        XCTAssertNotNil(store.load())
    }
}
