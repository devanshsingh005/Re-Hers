import XCTest
@testable import Rehearse_v1

final class AppConfigServiceTests: XCTestCase {
    private func config(min: String, latest: String) -> RemoteAppConfig {
        RemoteAppConfig(
            minSupportedVersion: min,
            latestVersion: latest,
            updateRequiredMessage: "required",
            updateAvailableMessage: "available",
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

    func test_requirement_belowMinimumIsRequired() {
        XCTAssertEqual(AppVersion.requirement(for: config(min: "1.2", latest: "1.3"), installed: "1.1"), .required(message: "required"))
    }

    func test_requirement_betweenMinimumAndLatestIsAvailable() {
        XCTAssertEqual(
            AppVersion.requirement(for: config(min: "1.1", latest: "1.3"), installed: "1.2"),
            .available(latestVersion: "1.3", message: "available")
        )
    }

    func test_requirement_atOrAboveLatestIsNone() {
        XCTAssertEqual(AppVersion.requirement(for: config(min: "1.0", latest: "1.1"), installed: "1.1"), .none)
        XCTAssertEqual(AppVersion.requirement(for: config(min: "1.0", latest: "1.1"), installed: "1.2"), .none)
    }

    func test_requirement_malformedConfigNeverBlocks() {
        XCTAssertEqual(AppVersion.requirement(for: config(min: "oops", latest: "nope"), installed: "1.1"), .none)
    }

    func test_decodesPublishedRow() throws {
        let json = #"{"min_supported_version":"1.0","latest_version":"1.1","update_required_message":"a","update_available_message":"b","version":3}"#
        let decoded = try JSONDecoder().decode(RemoteAppConfig.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, RemoteAppConfig(minSupportedVersion: "1.0", latestVersion: "1.1", updateRequiredMessage: "a", updateAvailableMessage: "b", version: 3))
    }
}
