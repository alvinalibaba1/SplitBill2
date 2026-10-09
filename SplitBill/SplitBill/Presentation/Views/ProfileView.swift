//
//  ProfileView.swift
//  SplitBill
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @AppStorage("userName") private var userName = ""

    @AppStorage("appLanguage") private var currentLanguage: String = "en"

    @State private var profileImage: UIImage?        = ProfileImageStore.load()
    @State private var bankAccounts: [BankAccount]   = BankAccountStore.load()
    @State private var showLanguageSheet             = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    NavigationLink(destination: EditProfileView()) {
                        heroCard
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))

                    preferencesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profileImage = ProfileImageStore.load()
            bankAccounts = BankAccountStore.load()
        }
        .sheet(isPresented: $showLanguageSheet) {
            LanguagePickerSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HStack(spacing: 16) {

            // Avatar
            Group {
                if let img = profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.appIconChip
                        if userName.isEmpty {
                            Image(systemName: "person.fill")
                                .font(AppTheme.Fonts.inter(30, weight: .medium))
                                .foregroundColor(Color.appPrimary)
                        } else {
                            Text(String(userName.prefix(1)).uppercased())
                                .roundedFont(30, weight: .bold)
                                .foregroundColor(Color.appPrimary)
                        }
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.appCardBorder, lineWidth: 2))

            // Name + bio + bank pill
            VStack(alignment: .leading, spacing: 6) {
                Text(userName.isEmpty ? "Set up your profile" : userName)
                    .roundedFont(20, weight: .bold)
                    .foregroundColor(userName.isEmpty ? Color.textSecondary : Color.textPrimary)

                if let first = bankAccounts.first {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(AppTheme.Fonts.inter(10))
                            .foregroundColor(Color.appPrimary)
                        Text(bankAccounts.count > 1
                             ? "\(first.bankName) +\(bankAccounts.count - 1) more"
                             : "\(first.bankName) · \(maskedNumber(first.accountNumber))")
                            .roundedFont(11, weight: .medium)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appIconChip)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTheme.Fonts.inter(13, weight: .semibold))
                .foregroundColor(Color.textSecondary.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.appPrimary.opacity(0.08), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }


    // MARK: - Preferences Card

    private var preferencesCard: some View {
        cardSection(label: "profile.section.prefs".localized) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showLanguageSheet = true
            }) {
                appRow(icon: "globe", iconColor: Color.appPrimary, title: "profile.language".localized, trailing: {
                    HStack(spacing: 6) {
                        Text(currentLanguage == "id" ? "🇮🇩" : "🇬🇧")
                            .font(.system(size: 14))
                        Text(currentLanguage == "id" ? "Indonesia" : "English")
                            .roundedFont(14, weight: .regular)
                            .foregroundColor(Color.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(AppTheme.Fonts.inter(11, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.3))
                    }
                })
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    private func cardSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
                .padding(.leading, 4)

            content()
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
        }
    }

    private var cardDivider: some View {
        Divider()
            .background(Color.textSecondary.opacity(0.08))
            .padding(.leading, 70)
    }

    @ViewBuilder
    private func appRow<Trailing: View>(icon: String, iconColor: Color, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .roundedFont(15, weight: .regular)
                .foregroundColor(Color.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func maskedNumber(_ number: String) -> String {
        number.count <= 4 ? number : "•••• \(number.suffix(4))"
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
