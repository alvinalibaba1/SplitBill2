//
//  SplitBillApp.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import UIKit

@main
struct SplitBillApp: App {

    init() {
        // Option 1: Soft Minimal — #F8F9FA
        let bg = UIColor(red: 0.973, green: 0.976, blue: 0.980, alpha: 1.0)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bg
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.176, green: 0.204, blue: 0.212, alpha: 1)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(red: 0.176, green: 0.204, blue: 0.212, alpha: 1)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
    }
}
