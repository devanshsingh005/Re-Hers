import Foundation

enum InputValidator {
    static let nameMaxLength = 100
    static let bioMaxLength = 500
    static let searchMaxLength = 200
    static let singleLineMaxLength = 150
    static let passwordMinLength = 8

    private static let emailPattern = "^[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"

    static func limit(_ input: String, maxLength: Int) -> String {
        String(input.prefix(maxLength))
    }

    static func trimOnSubmit(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validateRequired(_ input: String, message: String) -> String? {
        trimOnSubmit(input).isEmpty ? message : nil
    }

    static func validateEmail(_ input: String) -> String? {
        let trimmed = trimOnSubmit(input)
        guard !trimmed.isEmpty else { return "Email is required." }
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return predicate.evaluate(with: trimmed) ? nil : "Invalid email"
    }

    static func validatePassword(_ input: String) -> String? {
        trimOnSubmit(input).count >= passwordMinLength ? nil : "Password must be at least 8 characters."
    }
}
