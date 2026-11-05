import XCTest
@testable import Rehearse_v1
import Auth

final class PasswordRecoveryFlowTests: XCTestCase {
    func test_requestOTP_withValidEmail_triggersResetPasswordForEmail() async throws {
        let spy = PasswordRecoveryAuthClientSpy()
        let sut = PasswordRecoveryService(authClient: spy)

        try await sut.requestOTP(for: "user@example.com")

        XCTAssertEqual(spy.resetPasswordEmail, "user@example.com")
    }

    func test_verifyOTP_usesRecoveryType() async throws {
        let spy = PasswordRecoveryAuthClientSpy()
        let sut = PasswordRecoveryService(authClient: spy)

        try await sut.verifyOTP(email: "user@example.com", token: "123456")

        XCTAssertEqual(spy.verifiedEmail, "user@example.com")
        XCTAssertEqual(spy.verifiedToken, "123456")
        XCTAssertEqual(spy.verifiedType, .recovery)
    }

    func test_resetPassword_withMismatchedPasswords_showsValidationError() async {
        let spy = PasswordRecoveryAuthClientSpy()
        let sut = PasswordRecoveryService(authClient: spy)

        do {
            try await sut.resetPassword(newPassword: "password123", confirmPassword: "password124")
            XCTFail("Expected mismatched passwords to throw")
        } catch let error as PasswordRecoveryService.ValidationError {
            XCTAssertEqual(error, .passwordsDoNotMatch)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(spy.updatedPassword)
    }

    func test_resetPassword_withMatchingPasswords_updatesPassword() async throws {
        let spy = PasswordRecoveryAuthClientSpy()
        let sut = PasswordRecoveryService(authClient: spy)

        try await sut.resetPassword(newPassword: "password123", confirmPassword: "password123")

        XCTAssertEqual(spy.updatedPassword, "password123")
    }

    func test_otpInputDistribution_fillsAllDigitsFromPaste() {
        let result = OTPInputDistribution.distribute(
            replacement: "123456",
            currentDigits: ["", "", "", "", "", ""],
            startingAt: 0
        )

        XCTAssertEqual(result.digits, ["1", "2", "3", "4", "5", "6"])
        XCTAssertEqual(result.nextIndex, 5)
    }

    func test_passwordRecoveryRequestGate_blocksReentryUntilFinished() {
        let gate = PasswordRecoveryRequestGate()

        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())

        gate.end()

        XCTAssertTrue(gate.begin())
    }
}

private final class PasswordRecoveryAuthClientSpy: PasswordRecoveryAuthClient {
    var resetPasswordEmail: String?
    var verifiedEmail: String?
    var verifiedToken: String?
    var verifiedType: EmailOTPType?
    var updatedPassword: String?

    func resetPasswordForEmail(_ email: String) async throws {
        resetPasswordEmail = email
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws {
        verifiedEmail = email
        verifiedToken = token
        verifiedType = type
    }

    func updatePassword(_ password: String) async throws {
        updatedPassword = password
    }
}
