import Foundation

open class SignedURLSigning: NSObject {
    public override init() {}

    open func createSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> URL {
        fatalError("Subclasses must override createSignedURL(bucket:path:expiresIn:)")
    }
}
