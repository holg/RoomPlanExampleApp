/*
See LICENSE folder for this sample's licensing information.

Abstract:
A stub scene delegate for the sample app.
*/

import UIKit
import RoomPlan

@MainActor
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create new window with HomeViewController
        // Note: We allow the app to run even without LiDAR support
        // Users can still view saved rooms, access settings, etc.
        // The "Start Scan" button will be disabled if LiDAR is not available
        let window = UIWindow(windowScene: windowScene)

        // Create HomeViewController with a UINavigationController
        let homeVC = HomeViewController()
        let navController = UINavigationController(rootViewController: homeVC)
        navController.navigationBar.prefersLargeTitles = true

        window.rootViewController = navController
        window.makeKeyAndVisible()
        self.window = window
    }
}

