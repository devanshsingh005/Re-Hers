import XCTest
import UIKit
@testable import Rehearse_v1

final class SheetMusicViewRenderTests: XCTestCase {
    func test_loadData_rerendersVisibleNotes_afterAsyncParseCompletes() {
        let view = SheetMusicView(frame: CGRect(x: 0, y: 0, width: 900, height: 320))

        view.setNeedsLayout()
        view.layoutIfNeeded()

        XCTAssertEqual(renderedNoteHeadCount(in: view), 0)

        view.loadData(Self.sampleSheetJSON)

        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline && renderedNoteHeadCount(in: view) == 0 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertGreaterThan(
            renderedNoteHeadCount(in: view),
            0,
            "SheetMusicView should rerender note heads after async JSON parsing completes."
        )
    }

    private func renderedNoteHeadCount(in view: SheetMusicView) -> Int {
        guard let contentLayer = view.layer.sublayers?.first else { return 0 }
        return countShapeLayers(in: contentLayer)
    }

    private func countShapeLayers(in layer: CALayer) -> Int {
        let current = layer is CAShapeLayer ? 1 : 0
        let childCount = (layer.sublayers ?? []).reduce(0) { partialResult, child in
            partialResult + countShapeLayers(in: child)
        }
        return current + childCount
    }

    private static let sampleSheetJSON = Data(
        """
        {
          "score-partwise": {
            "part": {
              "measure": [
                {
                  "@number": "1",
                  "attributes": {
                    "divisions": "1",
                    "time": {
                      "beats": "4",
                      "beat-type": "4"
                    }
                  },
                  "note": [
                    {
                      "pitch": {
                        "step": "C",
                        "octave": "4"
                      },
                      "duration": "2",
                      "voice": "1",
                      "staff": "1"
                    },
                    {
                      "pitch": {
                        "step": "E",
                        "octave": "4"
                      },
                      "duration": "2",
                      "voice": "1",
                      "staff": "1"
                    }
                  ]
                }
              ]
            }
          }
        }
        """.utf8
    )
}
