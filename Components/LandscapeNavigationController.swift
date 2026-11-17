//
//  LandscapeNavigationController.swift
//  Re-Hearse_v1
//

import UIKit

/// A navigation controller that forces its top view controller into landscape orientation.
/// Used for screens like Play Along and Animation that require a horizontal layout.
final class LandscapeNavigationController: UINavigationController {
    // phone only: an iPad keeps whatever orientation it is held in
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { DeviceLayout.isPad ? .all : .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        DeviceLayout.isPad ? super.preferredInterfaceOrientationForPresentation : .landscapeRight
    }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { topViewController?.prefersStatusBarHidden ?? true }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // When this landscape controller is dismissed, force the system back to portrait
        if DeviceLayout.isPad {
            // the iPad was never turned
        } else if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }
}
