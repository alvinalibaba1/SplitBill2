//
//  ProfileView.swift
//  SplitBill
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @AppStorage("userName")          private var userName          = ""
    @AppStorage("userBio")           private var userBio           = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    @ObservedObject private var historyVM = HistoryViewModel.shared

    @State private var profileImage: UIImage?        = ProfileImageStore.load()
    @State private var photoItem: PhotosPickerItem?  = nil
    @State private var showResetConfirm              = false
    @State private var bankAccounts: [BankAccount]   = BankAccountStore.load()
    @State private var editingAccount: BankAccount?  = nil
    @State private var showAddAccount                = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    private var totalBills: Int   { historyVM.history.count }
    private var totalSplit: Double { historyVM.history.reduce(0) { $0 + $1.totalAmount } }
    private var totalPeople: Int  {
        Set(historyVM.history.flatMap { $0.people.map { $0.name } }).count
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    heroCard
                    statsCard
                    personalCard
                    paymentCard
                    appCard
                    resetCard

                    Text("Made with ♥ by Alvin")
                        .font(AppTheme.Fonts.inter(13, weight: .regular))
                        .foregroundColor(Color.textSecondary.opacity(0.4))
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAccount) {
            BankAccountFormSheet(
                account: BankAccount(bankName: "", accountNumber: "", accountName: "")
            ) { saved in
                bankAccounts.append(saved)
                BankAccountStore.save(bankAccounts)
            }
        }
        .sheet(item: $editingAccount) { acct in
            BankAccountFormSheet(account: acct) { saved in
                if let idx = bankAccounts.firstIndex(where: { $0.id == saved.id }) {
                    bankAccounts[idx] = saved
                    BankAccountStore.save(bankAccounts)
                }
            }
        }
        .confirmationDialog(
            "This will restart the onboarding flow.",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Replay Onboarding", role: .destructive) { hasSeenOnboarding = false }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HStack(spacing: 16) {

            // Avatar picker
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
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
                    .overlay(Circle().stroke(Color.appPrimary.opacity(0.12), lineWidth: 2))

                    // Camera badge
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.appPrimary.opacity(0.3), radius: 4, y: 2)
                        Image(systemName: "camera.fill")
                            .font(AppTheme.Fonts.inter(10, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: 2)
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

            // Name + bio + bank pill
            VStack(alignment: .leading, spacing: 6) {
                Text(userName.isEmpty ? "Set your name →" : userName)
                    .roundedFont(20, weight: .bold)
                    .foregroundColor(userName.isEmpty ? Color.textSecondary : Color.textPrimary)

                if !userBio.isEmpty {
                    Text(userBio)
                        .roundedFont(13, weight: .regular)
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(2)
                }

                if let first = bankAccounts.first {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(AppTheme.Fonts.inter(10))
                            .foregroundColor(Color.appPrimary.opacity(0.7))
                        Text(bankAccounts.count > 1
                             ? "\(first.bankName) +\(bankAccounts.count - 1) more"
                             : "\(first.bankName) · \(maskedNumber(first.accountNumber))")
                            .roundedFont(11, weight: .medium)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.appPrimary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.appPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appPrimary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCell(value: "\(totalBills)", label: "Bills")
            dividerLine
            statCell(value: "\(totalPeople)", label: "People")
            dividerLine
            statCell(value: totalSplit.toCurrency(), label: "Total Split")
        }
        .padding(.vertical, 18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.textSecondary.opacity(0.12))
            .frame(width: 1, height: 36)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .roundedFont(17, weight: .bold)
                .foregroundColor(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .roundedFont(11, weight: .regular)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Personal Card

    private var personalCard: some View {
        cardSection(label: "PERSONAL") {
            VStack(spacing: 0) {
                inlineField(
                    icon: "person.fill",
                    iconColor: Color.appPrimary,
                    title: "Name",
                    placeholder: "Your name",
                    text: $userName
                )

                cardDivider

                inlineField(
                    icon: "text.quote",
                    iconColor: Color.appSecondary,
                    title: "Bio",
                    placeholder: "Short bio",
                    text: $userBio
                )
            }
        }
    }

    // MARK: - Payment Info Card

    private var paymentCard: some View {
        cardSection(label: "PAYMENT INFO") {
            VStack(spacing: 0) {
                ForEach(bankAccounts) { account in
                    Button(action: { editingAccount = account }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "F59E0B").opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "building.columns.fill")
                                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                                    .foregroundColor(Color(hex: "F59E0B"))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.bankName)
                                    .roundedFont(15, weight: .semibold)
                                    .foregroundColor(Color.textPrimary)
                                Text(maskedNumber(account.accountNumber))
                                    .roundedFont(12, weight: .regular)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            Text(account.accountName)
                                .roundedFont(13, weight: .regular)
                                .foregroundColor(Color.textSecondary)
                                .lineLimit(1)

                            Image(systemName: "chevron.right")
                                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                                .foregroundColor(Color.textSecondary.opacity(0.3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if account.id != bankAccounts.last?.id {
                        cardDivider
                    }
                }

                if !bankAccounts.isEmpty { cardDivider }

                // Add button
                Button(action: { showAddAccount = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appPrimary.opacity(0.10))
                                .frame(width: 40, height: 40)
                            Image(systemName: "plus")
                                .font(AppTheme.Fonts.inter(16, weight: .semibold))
                                .foregroundColor(Color.appPrimary)
                        }

                        Text("Add Bank Account")
                            .roundedFont(15, weight: .medium)
                            .foregroundColor(Color.appPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - App Card

    private var appCard: some View {
        cardSection(label: "APP") {
            VStack(spacing: 0) {
                appRow(icon: "info.circle.fill", iconColor: Color.appPrimary, title: "Version", trailing: {
                    Text(appVersion)
                        .roundedFont(14, weight: .regular)
                        .foregroundColor(Color.textSecondary)
                })

                cardDivider

                Button(action: {
                    if let url = URL(string: "itms-apps://itunes.apple.com/app/id") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    appRow(icon: "star.fill", iconColor: Color(hex: "F59E0B"), title: "Rate Splitzy", trailing: {
                        Image(systemName: "chevron.right")
                            .font(AppTheme.Fonts.inter(11, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.3))
                    })
                }
                .buttonStyle(.plain)

                cardDivider

                Button(action: {
                    if let url = URL(string: "mailto:feedback@splitzy.app") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    appRow(icon: "envelope.fill", iconColor: Color.appSecondary, title: "Send Feedback", trailing: {
                        Image(systemName: "chevron.right")
                            .font(AppTheme.Fonts.inter(11, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.3))
                    })
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Reset Card

    private var resetCard: some View {
        cardSection(label: "RESET") {
            Button(action: { showResetConfirm = true }) {
                appRow(icon: "arrow.counterclockwise", iconColor: Color.orange, title: "Replay Onboarding", trailing: {
                    Image(systemName: "chevron.right")
                        .font(AppTheme.Fonts.inter(11, weight: .semibold))
                        .foregroundColor(Color.textSecondary.opacity(0.3))
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
    private func inlineField(icon: String, iconColor: Color, title: String, placeholder: String, text: Binding<String>) -> some View {
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

            TextField(placeholder, text: text)
                .roundedFont(15, weight: .regular)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
