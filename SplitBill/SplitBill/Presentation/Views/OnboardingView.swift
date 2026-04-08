//
//  OnboardingView.swift
//  SplitBill
//

import SwiftUI

// MARK: - Data

private struct OnboardingPageData {
    let icon: String
    let title: String
    let subtitle: String
    let iconBg: Color
    let iconFg: Color
}

private let onboardingPages: [OnboardingPageData] = [
    OnboardingPageData(
        icon: "camera.viewfinder",
        title: "Snap Your Bill",
        subtitle: "Point your camera at any receipt and we'll pull out the items automatically.",
        iconBg: Color.appPrimary.opacity(0.12),
        iconFg: Color.appPrimary
    ),
    OnboardingPageData(
        icon: "person.2.fill",
        title: "Split with Anyone",
        subtitle: "Add people, assign items, and split the total exactly how you want.",
        iconBg: Color.appSecondary.opacity(0.12),
        iconFg: Color.appSecondary
    ),
    OnboardingPageData(
        icon: "bolt.fill",
        title: "Done in Seconds",
        subtitle: "Share results instantly. No more back-and-forth over who owes what.",
        iconBg: Color(hex: "FDCB6E").opacity(0.15),
        iconFg: Color(hex: "E67E22")
    )
]

// MARK: - OnboardingView

struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentPage = onboardingPages.count - 1
                        }
                    }
                    .font(AppTheme.Fonts.inter(15, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                    .opacity(currentPage < onboardingPages.count - 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
                .frame(height: 44)
                .padding(.horizontal, 28)

                // Swipeable pages
                TabView(selection: $currentPage) {
                    ForEach(onboardingPages.indices, id: \.self) { i in
                        OnboardingPageView(
                            page: onboardingPages[i],
                            isActive: currentPage == i
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentPage)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(onboardingPages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.appPrimary : Color.appPrimary.opacity(0.2))
                            .frame(width: i == currentPage ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.38, dampingFraction: 0.68), value: currentPage)
                    }
                }
                .padding(.bottom, 36)

                // Next / Get Started button
                Button(action: advance) {
                    Text(currentPage < onboardingPages.count - 1 ? "Next" : "Get Started")
                }
                .primaryButtonStyle()
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }

    private func advance() {
        if currentPage < onboardingPages.count - 1 {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                hasSeenOnboarding = true
            }
        }
    }
}

// MARK: - Page Content

private struct OnboardingPageView: View {

    let page: OnboardingPageData
    let isActive: Bool

    @State private var iconScale: CGFloat = 0.55
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -8
    @State private var textOffset: CGFloat = 28
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Floating icon card
            ZStack {
                // Soft outer ring
                Circle()
                    .fill(page.iconBg.opacity(0.5))
                    .frame(width: 160, height: 160)

                // Inner circle
                Circle()
                    .fill(page.iconBg)
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(AppTheme.Fonts.inter(50, weight: .medium))
                    .foregroundColor(page.iconFg)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
            .rotationEffect(.degrees(iconRotation))

            Spacer().frame(height: 52)

            // Text block
            VStack(spacing: 14) {
                Text(page.title)
                    .font(AppTheme.Fonts.inter(30, weight: .bold))
                    .foregroundColor(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(AppTheme.Fonts.inter(16, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 36)
            }
            .offset(y: textOffset)
            .opacity(textOpacity)

            Spacer()
        }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
        .onAppear {
            if isActive { animateIn() }
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.62).delay(0.04)) {
            iconScale = 1
            iconOpacity = 1
            iconRotation = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.16)) {
            textOffset = 0
            textOpacity = 1
        }
    }

    private func reset() {
        iconScale = 0.55
        iconOpacity = 0
        iconRotation = -8
        textOffset = 28
        textOpacity = 0
    }
}

#Preview {
    OnboardingView()
}
