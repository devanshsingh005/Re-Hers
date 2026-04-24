import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct PreparedImage {
    let data: Data
    let mimeType: String
    let fileExtension: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum ImageValidationError: Error {
    case unsupportedType
    case fileTooLarge
    case unreadable
    case processingFailed

    var userMessage: String {
        switch self {
        case .unsupportedType:
            return "Please choose a JPEG, PNG, HEIC, or WEBP image."
        case .fileTooLarge:
            return "Image must be under 10 MB."
        case .unreadable:
            return "We couldn't read that image. Please try a different one."
        case .processingFailed:
            return "We couldn't prepare that image. Please try another one."
        }
    }
}

enum ImageValidator {
    static let maxImageSizeBytes = 10 * 1024 * 1024
    static let maxPixelDimension = 4096

    static let allowedImageTypes: [UTType] = [
        .jpeg,
        .png,
        .heic,
        UTType("org.webmproject.webp")
    ].compactMap { $0 }

    static func preferredSupportedTypeIdentifier(from identifiers: [String]) -> String? {
        identifiers.first { identifier in
            guard let type = UTType(identifier) else { return false }
            return allowedImageTypes.contains { type.conforms(to: $0) }
        }
    }

    static func validateAndPrepareImageData(_ data: Data, typeIdentifier: String? = nil) -> Result<PreparedImage, ImageValidationError> {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return .failure(.unreadable)
        }

        guard let detectedType = resolvedType(from: source, preferredIdentifier: typeIdentifier) else {
            return .failure(.unsupportedType)
        }

        guard allowedImageTypes.contains(where: { detectedType.conforms(to: $0) }) else {
            return .failure(.unsupportedType)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return .failure(.unreadable)
        }

        let shouldDownsample = width > maxPixelDimension || height > maxPixelDimension
        let maxDimension = max(width, height)
        let sourceOptions: [CFString: Any] = shouldDownsample
            ? [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            : [:]

        let image = (shouldDownsample
                     ? CGImageSourceCreateThumbnailAtIndex(source, 0, sourceOptions as CFDictionary)
                     : CGImageSourceCreateImageAtIndex(source, 0, nil))

        guard let image else {
            return .failure(.processingFailed)
        }

        let finalWidth = shouldDownsample ? min(width, maxPixelDimension) : width
        let finalHeight = shouldDownsample ? min(height, maxPixelDimension) : height
        let targetDimensions = shouldDownsample ? maxPixelDimension : maxDimension

        let qualities: [CGFloat] = data.count > maxImageSizeBytes ? [0.75, 0.6, 0.5] : [0.82, 0.75, 0.6]

        for quality in qualities {
            if let prepared = encodeJPEG(from: image, compressionQuality: quality, width: finalWidth, height: finalHeight),
               prepared.data.count <= maxImageSizeBytes {
                return .success(prepared)
            }
        }

        if targetDimensions > 2048,
           let downsampled = downsample(source: source, maxPixelSize: 2048),
           let prepared = encodeJPEG(from: downsampled, compressionQuality: 0.6, width: min(width, 2048), height: min(height, 2048)),
           prepared.data.count <= maxImageSizeBytes {
            return .success(prepared)
        }

        return .failure(.fileTooLarge)
    }

    private static func resolvedType(from source: CGImageSource, preferredIdentifier: String?) -> UTType? {
        if let preferredIdentifier, let preferred = UTType(preferredIdentifier) {
            return preferred
        }
        guard let sourceType = CGImageSourceGetType(source) else { return nil }
        return UTType(sourceType as String)
    }

    private static func downsample(source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encodeJPEG(from image: CGImage, compressionQuality: CGFloat, width: Int, height: Int) -> PreparedImage? {
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return PreparedImage(
            data: destinationData as Data,
            mimeType: "image/jpeg",
            fileExtension: "jpg",
            pixelWidth: width,
            pixelHeight: height
        )
    }
}
