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

        // Synchronous check: Do we believe the user is logged in?
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")

        if isLoggedIn {
            // User is already logged in. Instantly go to the Home Page.
            // We run the async session check in the background just to be safe,
            // but we don't block the UI with a loading screen anymore.
            showMainApp()
            window.makeKeyAndVisible()

            Task {
                do {
                    _ = try await SupabaseManager.shared.client.auth.session
                    // Session is valid, stay on main app.
                } catch {
                    // Session invalid/expired. Reset flag and bounce back to login via splash.
                    await MainActor.run {
                        UserDefaults.standard.set(false, forKey: "isLoggedIn")
                        self.showGetStartedSplash()
                    }
                }
            }
        } else {
            // New user or logged-out user: show the animated SwiftUI splash screen.
            showGetStartedSplash()
            window.makeKeyAndVisible()
        }
    }

    // MARK: - Navigation Helpers

    /// Route to the main dashboard (already authenticated)
    func showMainApp() {
        let tabBar = MainTabBarController()
        setRootViewController(tabBar)
    }

    /// Route to the "Get Started" splash screen (unauthenticated)
    func showGetStartedSplash() {
        let splashView = SplashScreenView { [weak self] in
            self?.transitionToAuth()
        }
        let hostingController = UIHostingController(rootView: splashView)
        setRootViewController(hostingController)
    }

    /// Route to the login / sign-up screen
    func showLoginScreen() {
        let authVC = AuthViewController()
        let nav = UINavigationController(rootViewController: authVC)
        nav.setNavigationBarHidden(true, animated: false)
        setRootViewController(nav)
    }

    /// Smoothly swap the root view controller with a cross-dissolve
    private func setRootViewController(_ vc: UIViewController) {
        guard let window = self.window else { return }
        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = vc },
                          completion: nil)
    }

    func transitionToAuth() {
        guard let window = self.window else { return }
        
        // Transition to AuthViewController (or your primary entry point)
        let authVC = AuthViewController()
        
        UIView.transition(with: window,
                          duration: 0.6,
                          options: .transitionCrossDissolve,
                          animations: {
            window.rootViewController = authVC
        }, completion: nil)
    }


    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // ASWebAuthenticationSession handles its own callbacks directly.
        // We do NOT call SupabaseManager.shared.client.auth.handle(url) here
        // as it causes a race condition and "Auth session missing" error
        // when both attempt to consume the single-use OAuth callback.
    }

}

