import XCTest
@testable import Rehearse_v1

/// Files uploaded from the admin dashboard reach every app. A bad score.json must make the app show an
/// error, never crash. Each case either parses or throws; reaching the end of the test means no crash.
final class DashboardUploadSafetyTests: XCTestCase {
    private func parse(_ json: String) -> Result<ScoreTimeline, Error> {
        Result { try ScoreTimeline.parse(data: Data(json.utf8)) }
    }

    func test_scoreParser_survivesMalformedUploads() {
        let cases = [
            "",
            "not json",
            "[]",
            "{}",
            #"{"score-partwise": null}"#,
            #"{"score-partwise": {}}"#,
            #"{"score-partwise": {"part": []}}"#,
            #"{"score-partwise": {"part": "oops"}}"#,
            #"{"score-partwise": {"part": {"measure": "oops"}}}"#,
            #"{"score-partwise": {"part": {"measure": [1, 2, 3]}}}"#,
            #"{"score-partwise": {"part": {"measure": [{"note": "x"}]}}}"#,
            #"{"score-partwise": {"part": {"measure": [{"note": [{"pitch": {"step": "Q", "octave": "-99"}, "duration": "-5"}]}]}}}"#,
            #"{"score-partwise": {"part": {"measure": [{"attributes": {"divisions": "0"}, "note": [{"pitch": {"step": "C", "octave": "4"}, "duration": "0"}]}]}}}"#,
            #"{"score-partwise": {"part": {"measure": [{"attributes": {"divisions": "999999999"}, "sound": {"@tempo": "0"}, "note": [{"pitch": {"step": "C", "octave": "4"}, "duration": "999999999"}]}]}}}"#,
            #"{"score-partwise": {"part": {"measure": [{"direction": {"sound": {"@tempo": "-40"}}, "note": [{"rest": {}, "duration": "4"}]}]}}}"#,
            #"{"score-partwise": {"part": [{"measure": []}, {"measure": [{"note": {"chord": {}, "duration": "2"}}]}]}}"#,
        ]
        var outcomes: [String] = []
        for json in cases {
            switch parse(json) {
            case .success(let timeline): outcomes.append("parsed \(timeline.measures.count) measures")
            case .failure: outcomes.append("rejected")
            }
        }
        XCTAssertEqual(outcomes.count, cases.count)
        XCTAssertEqual(outcomes[0], "rejected")
        XCTAssertEqual(outcomes[1], "rejected")
    }
}
