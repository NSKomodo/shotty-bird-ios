//
//  AppDelegate.swift
//  Shotty Bird iOS
//
//  Copyright © 2023 Komodo Life. All rights reserved.
//

import GameKit
import SpriteKit
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        GameCenterHelper.shared.authenticateLocalPlayer(presentingViewController: window?.rootViewController) { success in
            if success {
                print("Game Center authentication completed as \(GKLocalPlayer.local.displayName)")
            } else {
                print("Game Center authentication failed...")
            }
        }
        return true
    }
}

