import XCTest
@testable import Rehearse_v1

/// An account suspended from the admin dashboard must be told so, not "check your details".
@MainActor
final class SuspendedAccountMessageTests: XCTestCase {
    private struct FakeAuthError: LocalizedError {
        let errorDescription: String?
    }

    func test_bannedAccount_getsSuspendedMessage() {
        let vc = AuthViewController(showBackButton: false)
        let message = vc.userFacingAuthErrorMessage(FakeAuthError(errorDescription: "User is banned"), mode: .logIn)
        XCTAssertTrue(message.contains("suspended"), message)
    }

    func test_wrongPassword_keepsGenericMessage() {
        let vc = AuthViewController(showBackButton: false)
        let message = vc.userFacingAuthErrorMessage(FakeAuthError(errorDescription: "Invalid login credentials"), mode: .logIn)
        XCTAssertFalse(message.contains("suspended"), message)
    }
}
