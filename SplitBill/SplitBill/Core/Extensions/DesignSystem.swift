//
//  DesignSystem.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 21/01/26.
//

import SwiftUI

// MARK: - App Theme (Option 1: Soft Minimal)
struct AppTheme {
    struct Colors {
        // Primary Brand Color - Soft Indigo
        static let primary = Color(hex: "6C5CE7")
        static let primaryDark = Color(hex: "5A4BD1")
        static let primaryLight = Color(hex: "E8E5FC")

        // Secondary - Mint Green
        static let secondary = Color(hex: "00CEC9")

        // Backgrounds
        static let background = Color(hex: "F8F9FA")
        static let surface = Color.white

        // Text
        static let textPrimary = Color(hex: "2D3436") // Dark Charcoal
        static let textSecondary = Color(hex: "636E72") // Cool Gray

        // Semantic
        static let success = Color(hex: "00CEC9")
        static let error = Color(hex: "EF4444")
        static let warning = Color(hex: "F59E0B")
    }

    struct Dimensions {
        static let cornerRadius: CGFloat = 20
        static let padding: CGFloat = 20
        static let buttonHeight: CGFloat = 56
    }

    // MARK: - Inter Font
    struct Fonts {
        static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            let weightName: String
            switch weight {
            case .black: weightName = "Inter-Black"
            case .bold: weightName = "Inter-Bold"
            case .semibold: weightName = "Inter-SemiBold"
            case .medium: weightName = "Inter-Medium"
            case .regular: weightName = "Inter-Regular"
            case .light: weightName = "Inter-Light"
            case .thin: weightName = "Inter-Thin"
            default: weightName = "Inter-Regular"
            }
            return Font.custom(weightName, size: size)
        }
    }
}

// MARK: - Custom Modifiers
struct GlassBackgroundModifier: ViewModifier {
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial)
//            .background(Color.white.opacity(opacity)) // Fallback/Addition
            .cornerRadius(AppTheme.Dimensions.cornerRadius)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.inter(17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.buttonHeight)
            .background(
                LinearGradient(
                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Extensions
extension View {
    func glassBackground(opacity: Double = 0.6) -> some View {
        modifier(GlassBackgroundModifier(opacity: opacity))
    }
    
    func primaryButtonStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }
    
    /// Applies Inter font
    func roundedFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(AppTheme.Fonts.inter(size, weight: weight))
    }

    /// Applies Inter font (named alias)
    func interFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(AppTheme.Fonts.inter(size, weight: weight))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Static accessors for the new theme
    static let appPrimary = AppTheme.Colors.primary
    static let appSecondary = AppTheme.Colors.secondary
    static let appBackground = AppTheme.Colors.background
    static let appSurface = AppTheme.Colors.surface
    static let textPrimary = AppTheme.Colors.textPrimary
    static let textSecondary = AppTheme.Colors.textSecondary
}
