//
//  SplitBillApp.swift
//  SplitBill
//

import SwiftUI
import UIKit

@main
struct SplitBillApp: App {

    init() {
        // Force dark mode app-wide
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = .dark }

        let bg          = UIColor(hex: "0D0D14")
        let surface     = UIColor(hex: "15151F")
        let textPrimary = UIColor(hex: "EEEAF8")

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bg
        UITabBar.appearance().standardAppearance  = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(hex: "8A86AA")

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor           = surface
        navAppearance.shadowColor               = .clear
        navAppearance.titleTextAttributes       = [
            .foregroundColor: textPrimary,
            .font: UIFont(name: "Inter-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes  = [
            .foregroundColor: textPrimary,
            .font: UIFont(name: "Inter-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor            = UIColor(hex: "7C6FF7")
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
        .defaultAppStorage(.standard)
    }
}
