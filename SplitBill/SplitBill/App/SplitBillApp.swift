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
        // Option 2: Ocean Blue + Coral — adaptive dark mode
        let bg = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "0F172A")
                : UIColor(hex: "FAFAFA")
        }
        let textPrimary = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: "F1F5F9")
                : UIColor(hex: "1E293B")
        }

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bg
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.titleTextAttributes = [.foregroundColor: textPrimary]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: textPrimary]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                TabBarView()
            } else {
                OnboardingView()
            }
        }
    }
}
