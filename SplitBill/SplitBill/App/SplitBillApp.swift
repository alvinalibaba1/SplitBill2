//
//  SplitBillApp.swift
//  SplitBill
//

import SwiftUI
import UIKit

@main
struct SplitBillApp: App {

    init() {
        // Adaptive background — follows system dark/light
        let bg = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "0D0D14")
                : UIColor(hex: "F3F2FD")
        }
        let surface = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "15151F")
                : UIColor.white
        }
        let textPrimary = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "EEEAF8")
                : UIColor(hex: "0D0B1A")
        }
        let textSecondary = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "8A86AA")
                : UIColor(hex: "6B6785")
        }
        let accent = UIColor(hex: "6C63F5")

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = bg
        tabAppearance.stackedLayoutAppearance.normal.iconColor       = textSecondary
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes   = [.foregroundColor: textSecondary]
        tabAppearance.stackedLayoutAppearance.selected.iconColor     = accent
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        UITabBar.appearance().standardAppearance   = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor  = surface
        navAppearance.shadowColor      = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont(name: "Inter-SemiBold", size: 17) ?? UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: UIFont(name: "Inter-Bold", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor            = accent
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
