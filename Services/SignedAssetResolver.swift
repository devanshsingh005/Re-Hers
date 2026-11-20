import Foundation

public struct SignedAssetReference: Equatable {
    public let bucket: String
    public let path: String

    public init(bucket: String, path: String) {
        self.bucket = bucket
        self.path = path
    }
}

public enum SignedAssetResolverError: Error {
    case emptyPath
    case invalidReference
}

public final class SignedAssetResolver: NSObject {
    private let signer: SignedURLSigning
    private let supabaseBaseURL: URL

    public init(signer: SignedURLSigning, supabaseBaseURL: URL) {
        self.signer = signer
        self.supabaseBaseURL = supabaseBaseURL
    }

    public func normalizeAssetReference(_ rawValue: String, fallbackBucket: String? = nil) throws -> SignedAssetReference {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SignedAssetResolverError.emptyPath }

        if let url = URL(string: trimmed), url.host == supabaseBaseURL.host {
            let components = url.pathComponents
            if let publicIndex = components.firstIndex(of: "public"),
               components.count > publicIndex + 2 {
                let bucket = components[publicIndex + 1]
                let path = components[(publicIndex + 2)...].joined(separator: "/")
                return SignedAssetReference(bucket: bucket, path: path)
            }
        }

        if let fallbackBucket {
            let path = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
            return SignedAssetReference(bucket: fallbackBucket, path: path)
        }

        throw SignedAssetResolverError.invalidReference
    }

    public func signedURL(for rawValue: String, fallbackBucket: String, expiresIn: Int = 300) async throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        let asset = try normalizeAssetReference(rawValue, fallbackBucket: fallbackBucket)
        return try await signer.createSignedURL(bucket: asset.bucket, path: asset.path, expiresIn: expiresIn)
    }

    public func maybeSignedURL(
        for rawValue: String?,
        fallbackBucket: String,
        expiresIn: Int = 300
    ) async throws -> URL? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else { return nil }

        if let url = URL(string: rawValue), url.scheme != nil {
            return url
        }

        if rawValue.hasPrefix("doc_") || rawValue.hasPrefix("icon_") {
            return nil
        }

        guard rawValue.contains("/") || rawValue.contains(".") else {
            return nil
        }

        return try await signedURL(for: rawValue, fallbackBucket: fallbackBucket, expiresIn: expiresIn)
    }
}
