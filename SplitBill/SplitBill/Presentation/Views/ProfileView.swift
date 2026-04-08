//
//  ProfileView.swift
//  SplitBill
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @AppStorage("userName")          private var userName          = ""
    @AppStorage("userBio")           private var userBio           = ""
    @AppStorage("bankName")          private var bankName          = ""
    @AppStorage("bankAccountNumber") private var bankAccountNumber = ""
    @AppStorage("bankAccountName")   private var bankAccountName   = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    @ObservedObject private var historyVM = HistoryViewModel.shared

    @State private var profileImage: UIImage? = ProfileImageStore.load()
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showResetConfirm = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private var totalBills: Int { historyVM.history.count }
    private var totalSplit: Double { historyVM.history.reduce(0) { $0 + $1.totalAmount } }
    private var totalPeople: Int {
        Set(historyVM.history.flatMap { $0.people.map { $0.name } }).count
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Avatar + Name
                    VStack(spacing: 14) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                // Avatar
                                Group {
                                    if let img = profileImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        ZStack {
                                            Color.appPrimary.opacity(0.12)
                                            if userName.isEmpty {
                                                Image(systemName: "person.fill")
                                                    .font(AppTheme.Fonts.inter(42, weight: .medium))
                                                    .foregroundColor(Color.appPrimary)
                                            } else {
                                                Text(String(userName.prefix(1)).uppercased())
                                                    .roundedFont(40, weight: .bold)
                                                    .foregroundColor(Color.appPrimary)
                                            }
                                        }
                                    }
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.appPrimary.opacity(0.15), lineWidth: 2))

                                // Camera badge
                                ZStack {
                                    Circle()
                                        .fill(Color.appPrimary)
                                        .frame(width: 30, height: 30)
                                        .shadow(color: Color.appPrimary.opacity(0.35), radius: 5, y: 2)
                                    Image(systemName: "camera.fill")
                                        .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 3, y: 3)
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

                        VStack(spacing: 4) {
                            Text(userName.isEmpty ? "Set Your Name" : userName)
                                .roundedFont(22, weight: .bold)
                                .foregroundColor(userName.isEmpty ? Color.textSecondary : Color.textPrimary)

                            if !userBio.isEmpty {
                                Text(userBio)
                                    .roundedFont(14, weight: .regular)
                                    .foregroundColor(Color.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            if !bankName.isEmpty && !bankAccountNumber.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "building.columns.fill")
                                        .font(AppTheme.Fonts.inter(11))
                                        .foregroundColor(Color.appPrimary.opacity(0.7))
                                    Text("\(bankName) · \(bankAccountNumber)")
                                        .roundedFont(12, weight: .medium)
                                        .foregroundColor(Color.textSecondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.appPrimary.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    // MARK: - Quick Stats
                    HStack(spacing: 0) {
                        statPill(value: "\(totalBills)", label: "Bills")
                        Divider()
                            .frame(height: 36)
                            .background(Color.textSecondary.opacity(0.15))
                        statPill(value: "\(totalPeople)", label: "People")
                        Divider()
                            .frame(height: 36)
                            .background(Color.textSecondary.opacity(0.15))
                        statPill(value: totalSplit.toCurrency(), label: "Total Split")
                    }
                    .padding(.vertical, 16)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // MARK: - Personal Section
                    sectionHeader("PERSONAL")

                    VStack(spacing: 0) {
                        settingsRow(icon: "person.fill", iconColor: Color.appPrimary, title: "Name") {
                            TextField("Your name", text: $userName)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.next)
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(icon: "text.quote", iconColor: Color.appSecondary, title: "Bio") {
                            TextField("Short bio", text: $userBio)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)

                    // MARK: - Payment Info Section
                    sectionHeader("PAYMENT INFO")

                    VStack(spacing: 0) {
                        settingsRow(icon: "building.columns.fill", iconColor: Color(hex: "F59E0B"), title: "Bank") {
                            TextField("e.g. BCA, Mandiri", text: $bankName)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.next)
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(icon: "creditcard.fill", iconColor: Color(hex: "8B5CF6"), title: "Account No.") {
                            TextField("Account number", text: $bankAccountNumber)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(icon: "person.text.rectangle.fill", iconColor: Color(hex: "10B981"), title: "Account Name") {
                            TextField("Holder name", text: $bankAccountName)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                        }
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)

                    // MARK: - App Section
                    sectionHeader("APP")

                    VStack(spacing: 0) {
                        settingsRow(icon: "info.circle", iconColor: Color.appPrimary, title: "Version") {
                            Text(appVersion)
                                .font(AppTheme.Fonts.inter(15, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                        }

                        Divider().padding(.leading, 52)

                        Button(action: {
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/id") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            settingsRow(icon: "star.fill", iconColor: Color(hex: "F59E0B"), title: "Rate Splitzy") {
                                Image(systemName: "chevron.right")
                                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                    .foregroundColor(Color.textSecondary.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 52)

                        Button(action: {
                            if let url = URL(string: "mailto:feedback@splitzy.app") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            settingsRow(icon: "envelope.fill", iconColor: Color.appSecondary, title: "Send Feedback") {
                                Image(systemName: "chevron.right")
                                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                    .foregroundColor(Color.textSecondary.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)

                    // MARK: - Reset Section
                    sectionHeader("RESET")

                    VStack(spacing: 0) {
                        Button(action: { showResetConfirm = true }) {
                            settingsRow(icon: "arrow.counterclockwise", iconColor: Color.orange, title: "Replay Onboarding") {
                                Image(systemName: "chevron.right")
                                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                    .foregroundColor(Color.textSecondary.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 16)

                    // Footer
                    Text("Made with ♥ by Alvin")
                        .font(AppTheme.Fonts.inter(13, weight: .regular))
                        .foregroundColor(Color.textSecondary.opacity(0.5))
                        .padding(.top, 36)
                        .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "This will restart the onboarding flow.",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Replay Onboarding", role: .destructive) {
                hasSeenOnboarding = false
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .roundedFont(16, weight: .bold)
                .foregroundColor(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .roundedFont(11, weight: .regular)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(AppTheme.Fonts.inter(16, weight: .medium))
                        .foregroundColor(iconColor)
                )

            Text(title)
                .font(AppTheme.Fonts.inter(16, weight: .regular))
                .foregroundColor(Color.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
