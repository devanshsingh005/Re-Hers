import XCTest
@testable import Re_Hearse_v1

final class DiscoverModerationPayloadTests: XCTestCase {
    func test_song_decodesUserIdentifierForBlocking() throws {
        let json = """
        {
          "id":"11111111-1111-1111-1111-111111111111",
          "title":"Prelude",
          "composer":"Bach",
          "level":1,
          "tempo":"90",
          "hands":"both",
          "skill_tags":["timing"],
          "skill_description":"desc",
          "initials":"JSB",
          "sheet_file_id":null,
          "is_free":true,
          "is_active":true,
          "sort_order":1,
          "sheet_url":null,
          "json_url":null,
          "original_pdf_path":"orig/file.pdf",
          "labeled_pdf_path":"label/file.pdf",
          "output_json_path":"json/file.json",
          "cover_image_url":"cover/file.png",
          "user_id":"22222222-2222-2222-2222-222222222222"
        }
        """.data(using: .utf8)!

        let song = try JSONDecoder().decode(Song.self, from: json)

        XCTAssertEqual(song.userId?.uuidString, "22222222-2222-2222-2222-222222222222")
    }

    func test_discoverSongFilter_excludesBlockedUsers() {
        let blockedUserID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let visibleUserID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

        let songs = [
            makeSong(title: "Hidden Song", userID: blockedUserID),
            makeSong(title: "Visible Song", userID: visibleUserID)
        ]

        let result = DiscoverSongFilter.visibleSongs(
            from: songs,
            blockedUserIDs: [blockedUserID],
            selectedLevel: nil,
            selectedSkill: nil,
            query: nil
        )

        XCTAssertEqual(result.map(\.title), ["Visible Song"])
    }

    func test_discoverReportRequest_encodesReportsPayload() throws {
        let request = DiscoverReportRequest(
            reporterID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            contentID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            contentType: "song",
            reason: "offensive_content"
        )

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]

        XCTAssertEqual(json?["reporter_id"], "66666666-6666-6666-6666-666666666666")
        XCTAssertEqual(json?["content_id"], "77777777-7777-7777-7777-777777777777")
        XCTAssertEqual(json?["content_type"], "song")
        XCTAssertEqual(json?["reason"], "offensive_content")
    }

    private func makeSong(title: String, userID: UUID) -> Song {
        Song(
            id: UUID(),
            userId: userID,
            title: title,
            composer: "Composer",
            level: 1,
            tempo: "90",
            hands: "both",
            skillTags: ["timing"],
            skillDescription: "desc",
            initials: "AA",
            sheetFileId: nil,
            isFree: true,
            isActive: true,
            sortOrder: 1,
            sheetUrl: nil,
            jsonUrl: nil,
            originalPdfPath: nil,
            labeledPdfPath: nil,
            outputJsonPath: nil,
            coverImageUrl: nil
        )
    }
}

final class ReviewAccessConfigurationTests: XCTestCase {
    func test_reviewAccessConfiguration_readsEmailAndPasswordFromDictionary() {
        let config = ReviewAccessConfiguration(dictionary: [
            "REVIEW_ACCESS_EMAIL": "reviewer@example.com",
            "REVIEW_ACCESS_PASSWORD": "review-pass-123"
        ])

        XCTAssertEqual(config.email, "reviewer@example.com")
        XCTAssertEqual(config.password, "review-pass-123")
        XCTAssertTrue(config.isConfigured)
    }

    @MainActor
    func test_handleSuccessfulLogin_routesImmediately() {
        let sut = AuthViewController()
        var routed = false
        sut.postLoginRouteHandler = {
            routed = true
        }

        sut.handleSuccessfulLogin()

        XCTAssertTrue(routed)
    }
}

final class DiscoverLayoutMetricsTests: XCTestCase {
    func test_scrollBottomInset_addsSafeAreaAndExtraPadding() {
        let inset = DiscoverLayoutMetrics.scrollBottomInset(safeAreaBottom: 34)

        XCTAssertEqual(inset, 58)
    }

    func test_scrollBottomInset_usesMinimumPaddingWithoutSafeArea() {
        let inset = DiscoverLayoutMetrics.scrollBottomInset(safeAreaBottom: 0)

        XCTAssertEqual(inset, 24)
    }
}

final class DiscoverSongDetailAccessPolicyTests: XCTestCase {
    func test_guestUsersCanOpenPlayAlongFromDiscoverDetail() {
        XCTAssertTrue(DiscoverSongDetailAccessPolicy.allowsGuestPlayAlong)
    }

    func test_guestUsersCanOpenAnimationFromDiscoverDetail() {
        XCTAssertTrue(DiscoverSongDetailAccessPolicy.allowsGuestAnimation)
    }
}
