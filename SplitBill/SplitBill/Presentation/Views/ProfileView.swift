//
//  ProfileView.swift
//  SplitBill
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @AppStorage("userName") private var userName = ""

    @ObservedObject private var historyVM = HistoryViewModel.shared

    @State private var profileImage: UIImage?        = ProfileImageStore.load()
    @State private var photoItem: PhotosPickerItem?  = nil
    @State private var bankAccounts: [BankAccount]   = BankAccountStore.load()
    @State private var showBankSheet                 = false

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBankSheet) {
            BankListSheet(bankAccounts: $bankAccounts)
                .presentationDetents([.medium, .large])
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
            inlineField(
                icon: "person.fill",
                iconColor: Color.appPrimary,
                title: "Name",
                placeholder: "Your name",
                text: $userName
            )
        }
    }

    // MARK: - Payment Info Card

    private var paymentCard: some View {
        cardSection(label: "PAYMENT INFO") {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showBankSheet = true
            }) {
                appRow(icon: "building.columns.fill", iconColor: Color(hex: "F59E0B"), title: "Bank", trailing: {
                    HStack(spacing: 6) {
                        Text(bankAccounts.isEmpty
                             ? "No accounts"
                             : "\(bankAccounts.count) account\(bankAccounts.count == 1 ? "" : "s")")
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

    // MARK: - App Card

    private var appCard: some View {
        cardSection(label: "APP") {
            // Rate Splitin — Coming Soon
            appRow(icon: "star.fill", iconColor: Color(hex: "F59E0B"), title: "Rate Splitin", trailing: {
                Text("Coming Soon")
                    .roundedFont(12, weight: .medium)
                    .foregroundColor(Color.textSecondary.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.textSecondary.opacity(0.08))
                    .clipShape(Capsule())
            })
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
