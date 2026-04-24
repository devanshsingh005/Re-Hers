//
//  AppDelegate.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        configureGlobalAppearance()
        return true
    }

    // MARK: - Global Appearance

    /// Applies component-level color tokens to every UINavigationBar in the app.
    /// Called once at launch so all screens inherit correct branding automatically.
    private func configureGlobalAppearance() {
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.backgroundColor          = ComponentColors.NavBar.background.withAlphaComponent(0.85)
        standardAppearance.shadowColor              = ComponentColors.NavBar.separator
        standardAppearance.titleTextAttributes      = [.foregroundColor: ComponentColors.NavBar.title]
        standardAppearance.largeTitleTextAttributes = [.foregroundColor: ComponentColors.NavBar.title]

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.titleTextAttributes      = [.foregroundColor: ComponentColors.NavBar.title]
        scrollEdgeAppearance.largeTitleTextAttributes = [.foregroundColor: ComponentColors.NavBar.title]

        UINavigationBar.appearance().standardAppearance   = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdgeAppearance
        UINavigationBar.appearance().compactAppearance    = standardAppearance
        UINavigationBar.appearance().tintColor            = ComponentColors.NavBar.rightButton
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}
