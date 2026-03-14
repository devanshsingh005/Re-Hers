//
//  SceneDelegate.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit
import Supabase
import Auth

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
            // User is supposedly logged in. Show the seamless loading spinner while
            // the async Supabase session check completely verifies the token.
            let loadingVC = LaunchLoadingViewController()
            window.rootViewController = loadingVC
            window.makeKeyAndVisible()

            Task {
                do {
                    _ = try await SupabaseManager.shared.client.auth.session
                    await MainActor.run { self.showMainApp() }
                } catch {
                    // Token expired or invalid. Reset flag and show login.
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    await MainActor.run { self.showGetStartedSplash() }
                }
            }
        } else {
            // User is explicitly logged out or a first-time user.
            // Immediately show the onboarding/Get Started splash with NO intermediate screen.
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let splashVC = storyboard.instantiateInitialViewController() else { return }
            
            window.rootViewController = splashVC
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
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let splashVC = storyboard.instantiateInitialViewController() else { return }
        setRootViewController(splashVC)
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

