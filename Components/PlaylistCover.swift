//
//  PlaylistCover.swift
//  Re-Hearse_v1
//
//  Playlist covers: a soft two-colour gradient with an outlined pair of notes, one per playlist.
//
//  The choice is stored in the playlist's `cover_image_url` as `gradient:<n>`, so it stays the
//  same on every launch and every device. Photos picked in Create Playlist are uploaded as
//  `photo-<id>.<ext>`. Any other stored cover (the stock artwork the app used to assign) shows
//  the playlist's own gradient, chosen from its id.
//

import UIKit

/// What the user picked for a new playlist's cover.
enum PlaylistCoverChoice {
    case gradient(Int)
    case photo(UIImage)
}

enum PlaylistCover {
    struct Style {
        let top: UIColor
        let bottom: UIColor
    }

    /// Light at the top, deeper at the bottom.
    static let styles: [Style] = [
        Style(top: UIColor(hex: "#C3E6CB"), bottom: UIColor(hex: "#4F9A90")),  // mint
        Style(top: UIColor(hex: "#F3CDA1"), bottom: UIColor(hex: "#D6776F")),  // peach
        Style(top: UIColor(hex: "#D9CCF2"), bottom: UIColor(hex: "#7F6BC9")),  // lavender
        Style(top: UIColor(hex: "#C4E0F5"), bottom: UIColor(hex: "#4F86C6")),  // sky
        Style(top: UIColor(hex: "#F7E3A6"), bottom: UIColor(hex: "#E0A04A")),  // butter
        Style(top: UIColor(hex: "#F6C9D4"), bottom: UIColor(hex: "#C9607E")),  // blush
        Style(top: UIColor(hex: "#DCE5C0"), bottom: UIColor(hex: "#7E9A5B")),  // sage
        Style(top: UIColor(hex: "#EFD9C3"), bottom: UIColor(hex: "#A87A5B")),  // sand
        Style(top: UIColor(hex: "#BFEAE8"), bottom: UIColor(hex: "#3E9DA6")),  // aqua
        Style(top: UIColor(hex: "#C9CBEF"), bottom: UIColor(hex: "#5B5F9E")),  // dusk
        Style(top: UIColor(hex: "#F8C2B4"), bottom: UIColor(hex: "#E06A5A")),  // coral
        Style(top: UIColor(hex: "#D3DAE3"), bottom: UIColor(hex: "#627387")),  // slate
    ]

    /// File-name prefix that marks an uploaded cover as a photo the user chose.
    static let photoFilePrefix = "photo-"
    private static let referencePrefix = "gradient:"
    private static let cache = NSCache<NSString, UIImage>()

    /// The value stored in `cover_image_url` for a gradient.
    static func reference(forStyle index: Int) -> String {
        "\(referencePrefix)\(index)"
    }

    /// The gradient a stored cover names, if it names one.
    static func styleIndex(from reference: String?) -> Int? {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines),
              reference.hasPrefix(referencePrefix),
              let index = Int(reference.dropFirst(referencePrefix.count)),
              styles.indices.contains(index) else { return nil }
        return index
    }

    /// A gradient picked from the playlist's id, the same on every launch (unlike `hashValue`).
    static func defaultStyleIndex(for id: UUID) -> Int {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let hash = bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7fff_ffff }
        return hash % styles.count
    }

    /// Whether a stored cover (path, signed URL or local file name) is a photo the user picked.
    static func isUserPhoto(_ reference: String?) -> Bool {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reference.isEmpty, styleIndex(from: reference) == nil else { return false }
        let path = URL(string: reference)?.path ?? reference
        var name = (path as NSString).lastPathComponent
        if name.hasPrefix("doc_") { name.removeFirst(4) }
        return name.hasPrefix(photoFilePrefix)
    }

    /// The gradient cover for a playlist: the one it chose, or its own default.
    /// Without the glyph it suits a wide backdrop behind the cover.
    static func image(forPlaylist id: UUID?, reference: String?, glyph: Bool = true) -> UIImage {
        image(style: styleIndex(from: reference) ?? id.map { defaultStyleIndex(for: $0) } ?? 0, glyph: glyph)
    }

    /// A gradient cover, drawn once per style, size and glyph setting.
    static func image(style index: Int, side: CGFloat = 320, glyph: Bool = true) -> UIImage {
        let style = styles[((index % styles.count) + styles.count) % styles.count]
        let key = "\(index)-\(Int(side))-\(glyph)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: [style.top.cgColor, style.bottom.cgColor] as CFArray,
                                         locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: side), options: [])
            }
            if glyph { noteGlyph(side: side).stroke() }
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Two beamed eighth notes in outline, about a third of the cover wide, centred.
    private static func noteGlyph(side: CGFloat) -> UIBezierPath {
        let unit = side * 0.0034                       // the glyph is drawn in a 100-unit box
        let origin = CGPoint(x: side / 2 - 50 * unit, y: side / 2 - 52 * unit)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        }
        let path = UIBezierPath()
        let radius = 10 * unit
        path.append(UIBezierPath(arcCenter: p(28, 76), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        path.append(UIBezierPath(arcCenter: p(72, 68), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        path.move(to: p(38, 76)); path.addLine(to: p(38, 26))     // left stem
        path.move(to: p(82, 68)); path.addLine(to: p(82, 18))     // right stem
        path.move(to: p(38, 26)); path.addLine(to: p(82, 18))     // beam
        path.lineWidth = side * 0.018
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        UIColor.white.withAlphaComponent(0.92).setStroke()
        return path
    }
}
