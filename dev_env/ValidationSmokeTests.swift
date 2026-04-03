import Foundation

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if condition() {
        print("PASS: \(message)")
        return true
    } else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func expectEqual<T: Equatable>(_ lhs: @autoclosure () -> T, _ rhs: @autoclosure () -> T, _ message: String) {
    let left = lhs()
    let right = rhs()
    if left == right {
        print("PASS: \(message)")
    } else {
        fputs("FAIL: \(message) | got: \(left) expected: \(right)\n", stderr)
        exit(1)
    }
}

func runValidationSmokeTests() {
    expectEqual(InputValidator.limit("abcdef", maxLength: 3), "abc", "limit truncates strings")
    expectEqual(InputValidator.trimOnSubmit("  hello  "), "hello", "trimOnSubmit trims edge whitespace")
    expect(InputValidator.validateEmail("user@example.com") == nil, "validateEmail accepts valid emails")
    expectEqual(InputValidator.validateEmail("bad-email"), "Invalid email", "validateEmail rejects malformed emails")
    expectEqual(InputValidator.validatePassword("short"), "Password must be at least 8 characters.", "validatePassword enforces minimum length")
    expectEqual(InputValidator.digitsOnly("12a-3"), "123", "digitsOnly strips non-digits")
    expectEqual(InputValidator.sanitizeHTMLUnsafe(#"<a>"b'c`"#), "&lt;a&gt;&quot;b&#39;c&#96;", "sanitizeHTMLUnsafe escapes dangerous characters")

    let oversized = URL(fileURLWithPath: "/tmp/fifty-one-mb.pdf")
    var oversizedData = Data("%PDF-1.7\n".utf8)
    oversizedData.append(Data(repeating: 0, count: Int(FileValidator.maxDocumentSizeBytes + 1)))
    try? oversizedData.write(to: oversized)
    defer { try? FileManager.default.removeItem(at: oversized) }
    switch FileValidator.validateDocument(at: oversized) {
    case .failure(.fileTooLarge):
        print("PASS: validateDocument rejects files larger than 50 MB")
    default:
        fputs("FAIL: validateDocument should reject files larger than 50 MB\n", stderr)
        exit(1)
    }
}

@main
struct ValidationSmokeTestRunner {
    static func main() {
        runValidationSmokeTests()
    }
}
