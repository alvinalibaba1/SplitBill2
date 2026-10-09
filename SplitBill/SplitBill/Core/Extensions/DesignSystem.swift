//
//  DesignSystem.swift
//  SplitBill
//

import SwiftUI

// MARK: - Hex helpers

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Adaptive Purple Theme (dark + light)

extension Color {
    // Backgrounds
    static let appBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "0A0E16")   // deep dark
            : UIColor(hex: "F4F6FA")   // light lavender
    })
    static let appSurface = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "111620")
            : UIColor.white
    })
    static let appCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "171D2A")
            : UIColor.white
    })

    // Brand — same in both modes
    static let appPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "6E9CE6") : UIColor(hex: "22416F")
    })
    static let appSecondary = Color(hex: "8FAAD0")

    // Champagne gold — use sparingly for premium touches
    static let appAccent = Color(hex: "C8A96A")

    // Readable brand color for text on card surfaces (≈6.9:1 on white)
    static let appBrandText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "FFFFFF")
            : UIColor(hex: "14305A")
    })
    // Soft purple circle behind icons
    static let appIconChip = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "1A2A44")
            : UIColor(hex: "E6EDF7")
    })
    // Card border
    static let appCardBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "253044")
            : UIColor(hex: "DCE3EE")
    })
    // Pending / unpaid status pill
    static let appWarningText = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "FBBF24") : UIColor(hex: "B45309")
    })
    static let appWarningBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "3A2E12") : UIColor(hex: "FEF3C7")
    })
    // Money semantics
    static let appSuccess = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "34D399") : UIColor(hex: "16A34A")
    })
    static let appDanger = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "F87171") : UIColor(hex: "EF5B5B")
    })

    // Text
    static let textPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "E8EDF5")
            : UIColor(hex: "0B1220")
    })
    static let textSecondary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "8A97AD")
            : UIColor(hex: "5A6578")
    })
}

// MARK: - AppTheme

struct AppTheme {

    struct Colors {
        static let primary      = Color.appPrimary
        static let primaryDark  = Color(hex: "14305A")
        static let primaryLight = Color(hex: "22416F").opacity(0.15)
        static let secondary    = Color.appSecondary
        static let background   = Color.appBackground
        static let surface      = Color.appSurface
        static let textPrimary  = Color.textPrimary
        static let textSecondary = Color.textSecondary
        static let success      = Color(hex: "34D399")
        static let error        = Color(hex: "F87171")
        static let warning      = Color(hex: "FBBF24")
    }

    struct Dimensions {
        static let cornerRadius: CGFloat = 20
        static let padding: CGFloat      = 20
        static let buttonHeight: CGFloat = 56
    }

    // MARK: - Plus Jakarta Sans (variable font, registered at launch)
    struct Fonts {
        /// Registers the bundled font file. Call once at app start.
        static func register() {
            guard let url = Bundle.main.url(forResource: "PlusJakartaSans", withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        /// Name kept as `inter` so existing call sites keep working.
        static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.custom("Plus Jakarta Sans", size: size).weight(weight)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.inter(17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.buttonHeight)
            .background(
                LinearGradient(
                    colors: [Color(hex: "22416F"), Color(hex: "14305A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.14, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: Color(hex: "22416F").opacity(0.4), radius: 14, x: 0, y: 6)
    }
}

/// Use on any button that should spring-scale on press
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.14, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers

struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.13), Color.appSecondary.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.cornerRadius)
                    .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(AppTheme.Dimensions.cornerRadius)
            .shadow(color: Color.appPrimary.opacity(0.2), radius: 24, x: 0, y: 0)
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }

    func primaryButtonStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    /// Applies Inter font (roundedFont alias kept for compatibility)
    func roundedFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(AppTheme.Fonts.inter(size, weight: weight))
    }

    func interFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(AppTheme.Fonts.inter(size, weight: weight))
    }
}
