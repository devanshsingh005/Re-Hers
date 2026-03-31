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
        performAuthRouting()
    }

    private func performAuthRouting() {
        Task {
            let client = SupabaseManager.shared.client
            let session = try? await client.auth.session
            let hasSession = session != nil

            if hasSession, let validSession = session {
                do {
                    let userId = validSession.user.id.uuidString

                    // Check onboarding status
                    struct OnboardingRow: Decodable {
                        let genres: [String]?
                    }

                    let row: OnboardingRow? = try? await client
                        .from("user_onboarding")
                        .select("genres")
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value

                    await MainActor.run {
                        if let genres = row?.genres, !genres.isEmpty {
                            self.showMainApp()
                        } else {
                            self.showLoginScreen()
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showLoginScreen()
                    }
                }
            } else {
                await MainActor.run {
                    self.showLoginScreen()
                }
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

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // ASWebAuthenticationSession handles its own callbacks directly.
        // We do NOT call SupabaseManager.shared.client.auth.handle(url) here
        // as it causes a race condition and "Auth session missing" error
        // when both attempt to consume the single-use OAuth callback.
    }

}
