import XCTest
@testable import Re_Hearse_v1

final class TestSignedURLSigner: SignedURLSigning {
    override func createSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        URL(string: "https://signed.example/\(bucket)/\(path)")!
    }
}

final class SignedAssetResolverTests: XCTestCase {
    func test_normalizePublicSupabaseURL_extractsBucketAndPath() throws {
        let resolver = SignedAssetResolver(
            signer: TestSignedURLSigner(),
            supabaseBaseURL: URL(string: "https://demo.supabase.co")!
        )

        let asset = try resolver.normalizeAssetReference(
            "https://demo.supabase.co/storage/v1/object/public/pdf_uploads/user-1/file.pdf"
        )

        XCTAssertEqual(asset.bucket, "pdf_uploads")
        XCTAssertEqual(asset.path, "user-1/file.pdf")
    }

    func test_normalizeLegacyDiscoverPath_usesFallbackBuckets() throws {
        let resolver = SignedAssetResolver(
            signer: TestSignedURLSigner(),
            supabaseBaseURL: URL(string: "https://demo.supabase.co")!
        )

        let original = try resolver.normalizeAssetReference("/users/a/original.pdf", fallbackBucket: "pdf_uploads")
        let labeled = try resolver.normalizeAssetReference("/users/a/labeled.pdf", fallbackBucket: "sheet_data")
        let json = try resolver.normalizeAssetReference("/users/a/output.json", fallbackBucket: "sheet_data")

        XCTAssertEqual(original.bucket, "pdf_uploads")
        XCTAssertEqual(original.path, "users/a/original.pdf")
        XCTAssertEqual(labeled.bucket, "sheet_data")
        XCTAssertEqual(labeled.path, "users/a/labeled.pdf")
        XCTAssertEqual(json.bucket, "sheet_data")
        XCTAssertEqual(json.path, "users/a/output.json")
    }

    func test_signedURL_callsSignerWithNormalizedBucketAndPath() async throws {
        let signer = RecordingSignedURLSigner()
        let resolver = SignedAssetResolver(
            signer: signer,
            supabaseBaseURL: URL(string: "https://demo.supabase.co")!
        )

        let url = try await resolver.signedURL(
            for: "https://demo.supabase.co/storage/v1/object/public/pdf_uploads/user-1/file.pdf",
            fallbackBucket: "pdf_uploads"
        )

        XCTAssertEqual(url.absoluteString, "https://signed.example/pdf_uploads/user-1/file.pdf")
        XCTAssertEqual(signer.calls.first?.bucket, "pdf_uploads")
        XCTAssertEqual(signer.calls.first?.path, "user-1/file.pdf")
    }

    func test_resolvedCoverImageURL_signsRelativeStoragePath() async throws {
        let song = Song(
            id: UUID(),
            userId: nil,
            title: "Cover Test",
            composer: "Composer",
            level: 1,
            tempo: "slow",
            hands: "both",
            skillTags: [],
            skillDescription: "",
            initials: "CT",
            sheetFileId: nil,
            isFree: true,
            isActive: true,
            sortOrder: 1,
            sheetUrl: nil,
            jsonUrl: nil,
            originalPdfPath: nil,
            labeledPdfPath: nil,
            outputJsonPath: nil,
            coverImageUrl: "cover/user-1/song.png"
        )

        let url = try await song.resolvedCoverImageURL(
            using: SignedAssetResolver(
                signer: RecordingSignedURLSigner(),
                supabaseBaseURL: URL(string: "https://demo.supabase.co")!
            )
        )

        XCTAssertEqual(url?.absoluteString, "https://signed.example/Sheets/cover/user-1/song.png")
    }

    func test_maybeSignedURL_signsPlaylistCoverStoragePath() async throws {
        let resolver = SignedAssetResolver(
            signer: RecordingSignedURLSigner(),
            supabaseBaseURL: URL(string: "https://demo.supabase.co")!
        )

        let url = try await resolver.maybeSignedURL(
            for: "playlist-covers/user-1/cover.png",
            fallbackBucket: "PlayListCover"
        )

        XCTAssertEqual(url?.absoluteString, "https://signed.example/PlayListCover/playlist-covers/user-1/cover.png")
    }

    func test_discoverAssetBuckets_followConfiguredStorageLayout() {
        let song = Song(
            id: UUID(),
            userId: nil,
            title: "Discover Song",
            composer: "Composer",
            level: 1,
            tempo: "90",
            hands: "both",
            skillTags: [],
            skillDescription: "",
            initials: "DS",
            sheetFileId: nil,
            isFree: true,
            isActive: true,
            sortOrder: 1,
            sheetUrl: "developer/song.pdf",
            jsonUrl: "developer/song.json",
            originalPdfPath: "user/job/input.pdf",
            labeledPdfPath: "user/job/labeled.pdf",
            outputJsonPath: "user/job/output.json",
            coverImageUrl: "developer/cover.png"
        )

        XCTAssertEqual(song.discoverCoverFallbackBucket, "Sheets")
        XCTAssertEqual(song.discoverPDFSource?.fallbackBucket, "pdf_uploads")
        XCTAssertEqual(song.discoverPDFSource?.rawValue, "user/job/labeled.pdf")
        XCTAssertEqual(song.discoverJSONSource?.fallbackBucket, "sheet_data")
        XCTAssertEqual(song.discoverJSONSource?.rawValue, "user/job/output.json")
    }

    func test_discoverDeveloperAssets_fallBackToSheetsBucket() {
        let song = Song(
            id: UUID(),
            userId: nil,
            title: "Developer Song",
            composer: "Composer",
            level: 1,
            tempo: "90",
            hands: "both",
            skillTags: [],
            skillDescription: "",
            initials: "DD",
            sheetFileId: nil,
            isFree: true,
            isActive: true,
            sortOrder: 1,
            sheetUrl: "developer/song.pdf",
            jsonUrl: "developer/song.json",
            originalPdfPath: nil,
            labeledPdfPath: nil,
            outputJsonPath: nil,
            coverImageUrl: "developer/cover.png"
        )

        XCTAssertEqual(song.discoverPDFSource?.fallbackBucket, "Sheets")
        XCTAssertEqual(song.discoverPDFSource?.rawValue, "developer/song.pdf")
        XCTAssertEqual(song.discoverJSONSource?.fallbackBucket, "Sheets")
        XCTAssertEqual(song.discoverJSONSource?.rawValue, "developer/song.json")
    }
}

final class RecordingSignedURLSigner: SignedURLSigning {
    struct Call {
        let bucket: String
        let path: String
        let expiresIn: Int
    }

    private(set) var calls: [Call] = []

    override init() {
        super.init()
    }

    override func createSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        calls.append(Call(bucket: bucket, path: path, expiresIn: expiresIn))
        return URL(string: "https://signed.example/\(bucket)/\(path)")!
    }
}
