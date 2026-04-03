import Foundation
import UniformTypeIdentifiers

struct ValidatedFile {
    let url: URL
    let type: UTType
    let sizeInBytes: Int64
}

enum FileValidationError: Error {
    case unsupportedType
    case fileTooLarge
    case unreadable

    var userMessage: String {
        switch self {
        case .unsupportedType:
            return "This file type isn't supported."
        case .fileTooLarge:
            return "File must be under 50 MB."
        case .unreadable:
            return "We couldn't read that file. Please try another one."
        }
    }
}

enum FileValidator {
    static let maxDocumentSizeBytes: Int64 = 50 * 1024 * 1024
    static let allowedDocumentTypes: [UTType] = [.pdf]
    static let allowedDocumentExtensions: Set<String> = ["pdf"]

    static func validateDocument(at url: URL) -> Result<ValidatedFile, FileValidationError> {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.unreadable)
            }
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileExtension = url.pathExtension.lowercased()
            guard allowedDocumentExtensions.contains(fileExtension) else {
                return .failure(.unsupportedType)
            }
            let type = UTType.pdf

            let attributeSize = (fileAttributes[.size] as? NSNumber)?.int64Value ?? 0
            let size = attributeSize
            guard size > 0 else {
                return .failure(.unreadable)
            }
            guard size <= maxDocumentSizeBytes else {
                return .failure(.fileTooLarge)
            }

            return .success(ValidatedFile(url: url, type: type, sizeInBytes: size))
        } catch {
            return .failure(.unreadable)
        }
    }
}
