//
//  NoteLabelRenderer.swift
//  Re-Hearse_v1
//
//  English note names under the notes of a recognized page, placed by the same rules the
//  old server-side label_notes.py used, but from the note and staff positions OemerKit found
//  on the page itself instead of from the MusicXML layout.
//

import OemerKit
import UIKit

nonisolated enum NoteLabelRenderer {
    /// One note name, in the pixel coordinates of the recognized page image.
    struct Label {
        let text: String
        /// Horizontal center and text baseline.
        let x: CGFloat
        let baseline: CGFloat
        let fontSize: CGFloat
    }

    /// label_notes.py: label height 1.3 staff spaces, baseline 2.5 staff spaces below the
    /// staff's bottom line; a label closer than 2.2 label heights to one already placed on the
    /// same staff moves down by 1.8 label heights.
    static let fontScale: CGFloat = 1.3
    static let offsetBelowStaff: CGFloat = 2.5
    static let minGapScale: CGFloat = 2.2
    static let lineHeightScale: CGFloat = 1.8

    /// Lays out one label per note: "A4", "G#5", "Bb4" (the name OemerKit reports).
    static func layout(_ notes: [LocatedNote]) -> [Label] {
        struct StaffKey: Hashable { let system: Int; let staff: Int }
        var labels: [Label] = []
        let byStaff = Dictionary(grouping: notes) { StaffKey(system: $0.system, staff: $0.staff) }
        for key in byStaff.keys.sorted(by: { ($0.system, $0.staff) < ($1.system, $1.staff) }) {
            var placed: [(x: CGFloat, y: CGFloat)] = []
            for note in byStaff[key]!.sorted(by: { $0.rect.midX < $1.rect.midX }) {
                let space = CGFloat(note.staffSpace)
                guard space > 0, space.isFinite else { continue }
                let fontSize = space * fontScale
                let minGap = fontSize * minGapScale
                let lineHeight = fontSize * lineHeightScale
                let x = note.rect.midX
                var y = CGFloat(note.staffBottom) + space * offsetBelowStaff
                for p in placed where abs(x - p.x) < minGap && abs(y - p.y) < lineHeight {
                    y = p.y + lineHeight
                }
                placed.append((x, y))
                labels.append(Label(text: note.name, x: x, baseline: y, fontSize: fontSize))
            }
        }
        return labels
    }

    /// Draws labels into the current UIKit context. `scale` converts page-image pixels to the
    /// context's units (e.g. PDF points).
    static func draw(_ labels: [Label], scale: CGFloat) {
        for label in labels {
            let size = label.fontSize * scale
            let font = UIFont(name: "Helvetica", size: size) ?? .systemFont(ofSize: size)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
            let text = label.text as NSString
            let width = text.size(withAttributes: attrs).width
            // draw(at:) takes the top-left of the line box; the baseline sits `ascender` below it
            let origin = CGPoint(x: label.x * scale - width / 2, y: label.baseline * scale - font.ascender)
            text.draw(at: origin, withAttributes: attrs)
        }
    }
}
