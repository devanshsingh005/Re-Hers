//
//  ViewControllerPresentation.swift
//  Re-Hearse_v1
//
//  Presentation helpers several screens share: the guest gate, sign-up / log-in, and photo
//  library access.
//

import UIKit
import Photos

extension UIViewController {
    /// Sign-up or log-in, full screen. It waits one run loop so it can follow a sheet that is
    /// dismissing (such as the guest gate) and does nothing if something is still presented.
    func presentAuthentication(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let nav = UINavigationController(rootViewController: AuthViewController(initialMode: mode))
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
    }

    /// The "sign up to use <feature>" sheet for guests; its buttons open sign-up or log-in.
    func presentGuestGate(featureName: String) {
        let modal = GuestFeatureGateModal(
            featureName: featureName,
            onSignUp: { [weak self] in self?.presentAuthentication(mode: .signUp) },
            onLogIn: { [weak self] in self?.presentAuthentication(mode: .logIn) }
        )
        present(modal, animated: true)
    }
}

/// Read/write access to the photo library (for choosing playlist covers and profile photos).
enum PhotoLibraryAccess {
    static var status: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Asks for access; `completion` runs on the main queue.
    static func request(_ completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async { completion(status) }
        }
    }
}
