#if canImport(CoreGraphics) && canImport(ImageIO)
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import OemerCore

/// A photo prepared for the models: upright, resized to oemer's working size (3.0–4.35 MP),
/// stored as 8-bit BGRA rows.
struct PreparedImage {
    let width: Int
    let height: Int
    /// BGRA pixels, row-major, `width * 4` bytes per row.
    var pixels: [UInt8]
    /// Size of the upright original image in pixels.
    let originalWidth: Int
    let originalHeight: Int

    /// processed / original
    var scaleX: Double { Double(width) / Double(originalWidth) }
    var scaleY: Double { Double(height) / Double(originalHeight) }
}

enum ImagePreparation {
    /// oemer `resize_image`: aim for the middle of 3.0M–4.35M pixels, keeping the aspect ratio.
    static func targetSize(width w: Int, height h: Int) -> (width: Int, height: Int) {
        let pixels = Double(w * h)
        let lb = 3_000_000 / pixels
        let ub = 4_350_000 / pixels
        let ratio = ((lb + ub) / 2).squareRoot()
        return (max(1, pyRound(ratio * Double(w))), max(1, pyRound(ratio * Double(h))))
    }

    /// Decodes an image file, applying its EXIF orientation and downsampling while decoding
    /// (cheap even for 48 MP photos).
    static func load(url: URL) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw OMRError.imageDecodingFailed }
        return try load(source: source)
    }

    static func load(data: Data) throws -> PreparedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw OMRError.imageDecodingFailed }
        return try load(source: source)
    }

    private static func load(source: CGImageSource) throws -> PreparedImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pw = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let ph = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else { throw OMRError.imageDecodingFailed }
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        let rotated = orientation >= 5  // 5...8 swap width and height
        let ow = rotated ? ph : pw
        let oh = rotated ? pw : ph
        let target = targetSize(width: ow, height: oh)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            // never above the image's own size: iOS logs an error for that (and returns the full image anyway)
            kCGImageSourceThumbnailMaxPixelSize: min(max(target.width, target.height), max(pw, ph)),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw OMRError.imageDecodingFailed
        }
        return try render(image, originalWidth: ow, originalHeight: oh, target: target)
    }

    /// Prepares an in-memory image. `orientation` describes how the pixel data must be
    /// rotated/flipped to appear upright (same meaning as the EXIF tag).
    static func prepare(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> PreparedImage {
        var upright = image
        if orientation != .up {
            let ci = CIImage(cgImage: image).oriented(orientation)
            let ctx = CIContext(options: [.useSoftwareRenderer: false])
            guard let cg = ctx.createCGImage(ci, from: ci.extent) else { throw OMRError.imageDecodingFailed }
            upright = cg
        }
        let target = targetSize(width: upright.width, height: upright.height)
        return try render(upright, originalWidth: upright.width, originalHeight: upright.height, target: target)
    }

    /// Draws `image` (already upright) into a white BGRA buffer of the target size.
    private static func render(_ image: CGImage, originalWidth: Int, originalHeight: Int,
                               target: (width: Int, height: Int)) throws -> PreparedImage
    {
        let w = target.width, h = target.height
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * h)
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ok: Bool = pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
            else { return false }
            ctx.interpolationQuality = .high
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { throw OMRError.imageDecodingFailed }
        return PreparedImage(width: w, height: h, pixels: pixels, originalWidth: originalWidth, originalHeight: originalHeight)
    }
}
#endif
