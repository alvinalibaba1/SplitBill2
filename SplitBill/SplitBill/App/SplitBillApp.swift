//
//  SplitBillApp.swift
//  SplitBill
//

import SwiftUI
import UIKit

@main
struct SplitBillApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        AppTheme.Fonts.register()

        // Adaptive background — follows system dark/light
        let bg = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "0A0E16")
                : UIColor(hex: "F4F6FA")
        }
        let surface = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "111620")
                : UIColor.white
        }
        let textPrimary = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "E8EDF5")
                : UIColor(hex: "0B1220")
        }
        let textSecondary = UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "8A97AD")
                : UIColor(hex: "5A6578")
        }
        let accent = UIColor { t in
            t.userInterfaceStyle == .dark ? UIColor(hex: "6E9CE6") : UIColor(hex: "22416F")
        }

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
        UITabBar.appearance().unselectedItemTintColor = textSecondary

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
