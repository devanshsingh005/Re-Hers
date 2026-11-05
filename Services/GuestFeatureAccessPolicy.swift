import Foundation

enum GuestFeatureAccessPolicy {
    static let allowsUploadTab = true
    static let requiresAuthenticationForSheetUpload = true
    static let allowsPlayAlong = true
    static let allowsAnimation = true
    static let allowsChordRecognition = true

    static func shouldGateSheetUploadActions(forGuest isGuest: Bool) -> Bool {
        isGuest && requiresAuthenticationForSheetUpload
    }
}
