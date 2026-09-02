import XCTest
@testable import DistanceBackfill

final class AutoSyncPreferenceTests: XCTestCase {
    private func makeIsolatedPreference() -> AutoSyncPreference {
        let suiteName = "AutoSyncPreferenceTests-\(UUID().uuidString)"
        return AutoSyncPreference(defaults: UserDefaults(suiteName: suiteName)!)
    }

    func testDefaultsAreFalse() {
        let preference = makeIsolatedPreference()
        XCTAssertFalse(preference.isEnabled)
        XCTAssertFalse(preference.hasPrompted)
    }

    func testSetAndGetRoundTrip() {
        let preference = makeIsolatedPreference()
        preference.isEnabled = true
        preference.hasPrompted = true

        XCTAssertTrue(preference.isEnabled)
        XCTAssertTrue(preference.hasPrompted)
    }
}
