//
//  OnboardingView.swift
//  SplitBill
//

import SwiftUI
import PhotosUI

// MARK: - Profile Image Helper

enum ProfileImageStore {
    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profileImage.jpg")
    }

    static func save(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
        }
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: url.path)
    }
}

// MARK: - Onboarding Page Data

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

private let totalPages = onboardingPages.count + 1   // +1 for profile setup page
private let profilePageIndex = onboardingPages.count  // = 3

// MARK: - OnboardingView

struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip button — hidden on profile page
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            currentPage = profilePageIndex
                        }
                    }
                    .font(AppTheme.Fonts.inter(15, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                    .opacity(currentPage < profilePageIndex ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
                .frame(height: 44)
                .padding(.horizontal, 28)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(onboardingPages.indices, id: \.self) { i in
                        OnboardingPageView(
                            page: onboardingPages[i],
                            isActive: currentPage == i
                        )
                        .tag(i)
                    }

                    // Profile Setup Page
                    ProfileSetupPageView(isActive: currentPage == profilePageIndex)
                        .tag(profilePageIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentPage)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0 ..< totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.appPrimary : Color.appPrimary.opacity(0.2))
                            .frame(width: i == currentPage ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.38, dampingFraction: 0.68), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Next / Get Started button
                Button(action: advance) {
                    Text(currentPage < profilePageIndex ? "Next" : "Get Started →")
                }
                .primaryButtonStyle()
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }

    private func advance() {
        if currentPage < profilePageIndex {
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

// MARK: - Existing Info Page

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

            ZStack {
                Circle()
                    .fill(page.iconBg.opacity(0.5))
                    .frame(width: 160, height: 160)
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
        .onAppear { if isActive { animateIn() } }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.62).delay(0.04)) {
            iconScale = 1; iconOpacity = 1; iconRotation = 0
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.16)) {
            textOffset = 0; textOpacity = 1
        }
    }

    private func reset() {
        iconScale = 0.55; iconOpacity = 0; iconRotation = -8
        textOffset = 28; textOpacity = 0
    }
}

// MARK: - Profile Setup Page

private struct ProfileSetupPageView: View {

    let isActive: Bool

    @AppStorage("userName") private var userName = ""
    @AppStorage("userBio")  private var userBio  = ""

    @State private var profileImage: UIImage? = ProfileImageStore.load()
    @State private var photoItem: PhotosPickerItem? = nil

    @State private var contentOpacity: Double  = 0
    @State private var contentOffset: CGFloat  = 32
    @State private var bankAccounts: [BankAccount] = BankAccountStore.load()
    @State private var showAddBank = false

    @FocusState private var focusedField: ProfileField?

    enum ProfileField { case name, bio }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // Header
                VStack(spacing: 8) {
                    Text("Set Up Your Profile")
                        .font(AppTheme.Fonts.inter(28, weight: .bold))
                        .foregroundColor(Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Add your info so others know who to pay back.")
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Avatar picker
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        // Avatar circle
                        Group {
                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.appPrimary.opacity(0.1)
                                    if userName.isEmpty {
                                        Image(systemName: "person.fill")
                                            .font(AppTheme.Fonts.inter(44, weight: .medium))
                                            .foregroundColor(Color.appPrimary.opacity(0.5))
                                    } else {
                                        Text(String(userName.prefix(1)).uppercased())
                                            .font(AppTheme.Fonts.inter(52, weight: .bold))
                                            .foregroundColor(Color.appPrimary)
                                    }
                                }
                            }
                        }
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appPrimary.opacity(0.15), lineWidth: 2))

                        // Camera badge
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 34, height: 34)
                                .shadow(color: Color.appPrimary.opacity(0.4), radius: 6, y: 2)
                            Image(systemName: "camera.fill")
                                .font(AppTheme.Fonts.inter(14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: photoItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run {
                                profileImage = img
                                ProfileImageStore.save(img)
                            }
                        }
                    }
                }

                // Form fields
                VStack(spacing: 16) {

                    // Personal info
                    formSection(title: "PERSONAL") {
                        formField(
                            icon: "person.fill",
                            iconColor: Color.appPrimary,
                            placeholder: "Your name",
                            text: $userName,
                            field: .name,
                            keyboard: .default
                        )

                        Divider().padding(.leading, 52)

                        formField(
                            icon: "text.quote",
                            iconColor: Color.appSecondary,
                            placeholder: "Short bio (optional)",
                            text: $userBio,
                            field: .bio,
                            keyboard: .default
                        )
                    }

                    // Bank info
                    formSection(title: "PAYMENT INFO") {
                        // Existing accounts (read-only rows)
                        ForEach(bankAccounts) { account in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "F59E0B").opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "building.columns.fill")
                                        .font(AppTheme.Fonts.inter(15, weight: .medium))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.bankName)
                                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                        .foregroundColor(Color.textPrimary)
                                    Text(account.accountNumber)
                                        .font(AppTheme.Fonts.inter(12, weight: .regular))
                                        .foregroundColor(Color.textSecondary)
                                }
                                Spacer()
                                Text(account.accountName)
                                    .font(AppTheme.Fonts.inter(13, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 52)
                        }

                        // Add Bank Account button
                        Button(action: { showAddBank = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.appPrimary.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "plus")
                                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                        .foregroundColor(Color.appPrimary)
                                }
                                Text("Add Bank Account")
                                    .font(AppTheme.Fonts.inter(15, weight: .regular))
                                    .foregroundColor(Color.appPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // You can skip hint
                Text("You can update this anytime in Profile")
                    .font(AppTheme.Fonts.inter(13, weight: .regular))
                    .foregroundColor(Color.textSecondary.opacity(0.6))
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .opacity(contentOpacity)
        .offset(y: contentOffset)
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
        .onAppear { if isActive { animateIn() } }
        .onTapGesture { focusedField = nil }
        .sheet(isPresented: $showAddBank) {
            BankAccountFormSheet(
                account: BankAccount(bankName: "", accountNumber: "", accountName: "")
            ) { saved in
                bankAccounts.append(saved)
                BankAccountStore.save(bankAccounts)
            }
        }
    }

    // MARK: - Form Section

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Form Field

    @ViewBuilder
    private func formField(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        field: ProfileField,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(AppTheme.Fonts.inter(15, weight: .medium))
                    .foregroundColor(iconColor)
            }

            TextField(placeholder, text: text)
                .font(AppTheme.Fonts.inter(15, weight: .regular))
                .foregroundColor(Color.textPrimary)
                .keyboardType(keyboard)
                .focused($focusedField, equals: field)
                .submitLabel(field == .bio ? .done : .next)
                .onSubmit {
                    switch field {
                    case .name: focusedField = .bio
                    case .bio:  focusedField = nil
                    }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Animation

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.08)) {
            contentOpacity = 1
            contentOffset  = 0
        }
    }

    private func reset() {
        contentOpacity = 0
        contentOffset  = 32
    }
}

#Preview {
    OnboardingView()
}
