//
//  PasswordRecoveryService.swift
//  Re-Hearse_v1
//

import Foundation
import Auth
import Supabase

protocol PasswordRecoveryAuthClient {
    func resetPasswordForEmail(_ email: String) async throws
    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws
    func updatePassword(_ password: String) async throws
}

struct SupabasePasswordRecoveryAuthClient: PasswordRecoveryAuthClient {
    func resetPasswordForEmail(_ email: String) async throws {
        try await SupabaseManager.shared.client.auth.resetPasswordForEmail(email, captchaToken: nil)
    }

    func verifyOTP(email: String, token: String, type: EmailOTPType) async throws {
        _ = try await SupabaseManager.shared.client.auth.verifyOTP(
            email: email,
            token: token,
            type: type
        )
    }

    func updatePassword(_ password: String) async throws {
        try await SupabaseManager.shared.client.auth.update(user: UserAttributes(password: password))
    }
}

final class PasswordRecoveryService {
    enum ValidationError: Error, LocalizedError, Equatable {
        case passwordsDoNotMatch

        var errorDescription: String? {
            switch self {
            case .passwordsDoNotMatch:
                return "Passwords do not match."
            }
        }
    }

    private let authClient: PasswordRecoveryAuthClient

    init(authClient: PasswordRecoveryAuthClient = SupabasePasswordRecoveryAuthClient()) {
        self.authClient = authClient
    }

    func requestOTP(for email: String) async throws {
        try await authClient.resetPasswordForEmail(email)
    }

    func verifyOTP(email: String, token: String) async throws {
        try await authClient.verifyOTP(email: email, token: token, type: .recovery)
    }

    func resetPassword(newPassword: String, confirmPassword: String) async throws {
        guard newPassword == confirmPassword else {
            throw ValidationError.passwordsDoNotMatch
        }

        try await authClient.updatePassword(newPassword)
    }
}

final class PasswordRecoveryRequestGate {
    private var isInFlight = false

    func begin() -> Bool {
        guard !isInFlight else { return false }
        isInFlight = true
        return true
    }

    func end() {
        isInFlight = false
    }
}
