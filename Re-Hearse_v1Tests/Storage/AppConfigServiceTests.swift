import XCTest
@testable import Rehearse_v1

final class AppConfigServiceTests: XCTestCase {
    private func config(min: String, latest: String, maintenance: Bool = false, endsAt: String? = nil) -> RemoteAppConfig {
        RemoteAppConfig(
            minSupportedVersion: min,
            latestVersion: latest,
            updateRequiredMessage: "required",
            updateAvailableMessage: "available",
            maintenanceEnabled: maintenance,
            maintenanceTitle: "Down",
            maintenanceMessage: "Back soon",
            maintenanceEndsAt: endsAt,
            version: 1
        )
    }

    func test_compare_ordersNumerically() {
        XCTAssertEqual(AppVersion.compare("1.9", "1.10"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("1.0", "1"), .orderedSame)
        XCTAssertEqual(AppVersion.compare("1.0", "1.0.1"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("2.0", "1.99.99"), .orderedDescending)
    }

    func test_compare_rejectsMalformedVersions() {
        XCTAssertNil(AppVersion.compare("1.0-beta", "1.0"))
        XCTAssertNil(AppVersion.compare("", "1.0"))
        XCTAssertNil(AppVersion.compare("1..0", "1.0"))
        XCTAssertNil(AppVersion.compare("1.2.3.4", "1.0"))
    }

    func test_gate_belowMinimumIsRequired() {
        XCTAssertEqual(AppVersion.gate(for: config(min: "1.2", latest: "1.3"), installed: "1.1"), .updateRequired(message: "required"))
    }

    func test_gate_betweenMinimumAndLatestIsAvailable() {
        XCTAssertEqual(
            AppVersion.gate(for: config(min: "1.1", latest: "1.3"), installed: "1.2"),
            .available(latestVersion: "1.3", message: "available")
        )
    }

    func test_gate_atOrAboveLatestIsNone() {
        XCTAssertEqual(AppVersion.gate(for: config(min: "1.0", latest: "1.1"), installed: "1.1"), .none)
        XCTAssertEqual(AppVersion.gate(for: config(min: "1.0", latest: "1.1"), installed: "1.2"), .none)
    }

    func test_gate_malformedConfigNeverBlocks() {
        XCTAssertEqual(AppVersion.gate(for: config(min: "oops", latest: "nope"), installed: "1.1"), .none)
    }

    func test_gate_maintenanceWinsOverUpdates() {
        XCTAssertEqual(
            AppVersion.gate(for: config(min: "9.0", latest: "9.0", maintenance: true), installed: "1.1"),
            .maintenance(title: "Down", message: "Back soon", endsAt: nil)
        )
    }

    func test_gate_maintenanceKeepsFutureEndAndDropsPastEnd() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = config(min: "1.0", latest: "1.0", maintenance: true, endsAt: "2027-01-15T10:30:00.5+00:00")
        let past = config(min: "1.0", latest: "1.0", maintenance: true, endsAt: "2020-01-01T00:00:00+00:00")
        guard case .maintenance(_, _, let end) = AppVersion.gate(for: future, installed: "1.1", now: now) else {
            return XCTFail("expected maintenance")
        }
        XCTAssertNotNil(end)
        XCTAssertEqual(AppVersion.gate(for: past, installed: "1.1", now: now), .maintenance(title: "Down", message: "Back soon", endsAt: nil))
    }

    func test_decodesPublishedRow() throws {
        let json = #"{"min_supported_version":"1.0","latest_version":"1.1","update_required_message":"a","update_available_message":"b","maintenance_enabled":true,"maintenance_title":"T","maintenance_message":"M","maintenance_ends_at":null,"version":3}"#
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, RemoteAppConfig(minSupportedVersion: "1.0", latestVersion: "1.1", updateRequiredMessage: "a", updateAvailableMessage: "b", maintenanceEnabled: true, maintenanceTitle: "T", maintenanceMessage: "M", version: 3))
    }

    func test_decodesConfigCachedBeforeMaintenanceExisted() throws {
        let json = #"{"min_supported_version":"1.0","latest_version":"1.1","update_required_message":"a","update_available_message":"b","version":2}"#
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.maintenanceEnabled)
        XCTAssertEqual(decoded.theme, "default")
    }

    // MARK: Seasonal theme

    func test_decodesTheme() throws {
        let json = #"{"min_supported_version":"1.0","latest_version":"1.1","update_required_message":"a","update_available_message":"b","maintenance_enabled":false,"maintenance_title":"T","maintenance_message":"M","maintenance_ends_at":null,"theme":"christmas","version":4}"#
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.theme, "christmas")
        XCTAssertEqual(SeasonalTheme(remoteValue: decoded.theme), .christmas)
    }

    func test_themeOfTheWrongTypeKeepsTheRestOfTheConfig() throws {
        let json = #"{"min_supported_version":"1.0","latest_version":"1.1","update_required_message":"a","update_available_message":"b","maintenance_enabled":true,"theme":7,"version":4}"#
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.maintenanceEnabled)
        XCTAssertEqual(SeasonalTheme(remoteValue: decoded.theme), .default)
    }

    func test_cachedConfigRoundTripsTheTheme() throws {
        let config = RemoteAppConfig(minSupportedVersion: "1.0", latestVersion: "1.0", updateRequiredMessage: "a",
                                     updateAvailableMessage: "b", theme: "christmas", version: 9)
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded, config)
    }

    func test_unknownOrMissingThemeIsDefault() {
        XCTAssertEqual(SeasonalTheme(remoteValue: nil), .default)
        XCTAssertEqual(SeasonalTheme(remoteValue: ""), .default)
        XCTAssertEqual(SeasonalTheme(remoteValue: "halloween"), .default)
        XCTAssertEqual(SeasonalTheme(remoteValue: " Christmas "), .christmas)
    }

    func test_themeNeverBlocksTheApp() {
        let config = RemoteAppConfig(minSupportedVersion: "1.0", latestVersion: "1.0", updateRequiredMessage: "a",
                                     updateAvailableMessage: "b", theme: "christmas", version: 9)
        XCTAssertEqual(AppVersion.gate(for: config, installed: "1.1"), .none)
    }
}
