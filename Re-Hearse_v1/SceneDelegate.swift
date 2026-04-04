//
//  SceneDelegate.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit
import Supabase
import Auth
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Always show the animated SwiftUI splash screen as the primary entry point
        showSplashAndRoute()
        window.makeKeyAndVisible()
    }



    /// Decides where to go after the splash screen finishes
    private func performInitialRouting() {
        // Observe auth changes globally to handle sign-outs or remote session ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStatusChanged(_:)),
            name: SupabaseManager.authStatusChangedNotification,
            object: nil
        )

        // Give Supabase a tiny window (e.g. 100-200ms) to restore session from disk
        // if the client.auth.session is nil but emitLocalSessionAsInitialSession is true.
        // Or check current session immediately.
        performAuthRouting()
    }

    @objc private func handleAuthStatusChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let event = userInfo["event"] as? AuthChangeEvent else { return }

        Task { @MainActor in
            switch event {
            case .signedOut, .userDeleted:
                // Force user back to login only if they aren't already there
                if !(window?.rootViewController?.presentedViewController is AuthViewController) {
                    showLoginScreen()
                }
            default:
                break
            }
        }
    }

    private func performAuthRouting() {
        let guestSessionManager = GuestSessionManager.shared
        
        // Final sanity check before routing
        if guestSessionManager.isAuthenticated() {
            showMainApp()
            return
        }

        _ = guestSessionManager.getOrCreateGuestID()
        showMainApp()

        if !guestSessionManager.hasSeenInfoCard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showInfoCardOverlay()
            }
        }
    }

    // MARK: - Navigation Helpers

    /// Shows the animated splash screen and then routes to Login or Home
    func showSplashAndRoute() {
        let splashView = SplashScreenView { [weak self] in
            self?.performInitialRouting()
        }
        let hostingController = UIHostingController(rootView: splashView)
        setRootViewController(hostingController)
    }

    /// Route to the main dashboard
    func showMainApp() {
        let tabBar = MainTabBarController()
        setRootViewController(tabBar)
    }

    private func showInfoCardOverlay() {
        guard let root = window?.rootViewController,
              root.presentedViewController == nil else { return }

        let hostingController = UIHostingController(
            rootView: RehearsalInfoCardWrapper { [weak root] in
                GuestSessionManager.shared.hasSeenInfoCard = true
                root?.dismiss(animated: true)
            }
        )
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        root.present(hostingController, animated: true)
    }

    func showOnboarding() {
        let hostingController = UIHostingController(rootView: OnboardingFlowRoot())
        setRootViewController(hostingController)
    }

    /// Route to the login / sign-up screen
    func showLoginScreen() {
        let authVC = AuthViewController()
        let nav = UINavigationController(rootViewController: authVC)
        nav.setNavigationBarHidden(true, animated: false)
        setRootViewController(nav)
    }

    /// Smoothly swap the root view controller with a cross-dissolve if a root already exists
    private func setRootViewController(_ vc: UIViewController, animated: Bool = true) {
        guard let window = self.window else { return }
        
        // If we don't have a root yet (initial launch), don't animate to avoid a black flash.
        // If animated is false, just set it directly.
        if animated, window.rootViewController != nil {
            UIView.transition(with: window,
                              duration: 0.35,
                              options: .transitionCrossDissolve,
                              animations: { window.rootViewController = vc },
                              completion: nil)
        } else {
            window.rootViewController = vc
        }
    }


    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        SupabaseManager.shared.startAutoRefresh()
        (scene as? UIWindowScene)?.windows.first?.viewWithTag(9999)?.removeFromSuperview()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        guard let window = (scene as? UIWindowScene)?.windows.first else { return }
        if window.viewWithTag(9999) == nil {
            let overlay = UIView(frame: window.bounds)
            overlay.backgroundColor = .systemBackground
            overlay.tag = 9999
            window.addSubview(overlay)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SupabaseManager.shared.stopAutoRefresh()
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

private struct RehearsalInfoCardWrapper: View {
    let onDismiss: () -> Void

    @State private var isPresented = true

    var body: some View {
        RehearsalInfoCard(
            isPresented: Binding(
                get: { isPresented },
                set: { updatedValue in
                    let wasPresented = isPresented
                    isPresented = updatedValue

                    guard wasPresented, !updatedValue else { return }
                    onDismiss()
                }
            )
        )
    }
}
