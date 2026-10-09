//
//  EditProfileView.swift
//  SplitBill
//
//  Opened from the Profile hero card. Photo, name and bank accounts in one place.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {

    @AppStorage("userName") private var userName = ""

    @State private var profileImage: UIImage?       = ProfileImageStore.load()
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var bankAccounts: [BankAccount]  = BankAccountStore.load()
    @State private var showBankSheet                = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    avatarSection
                    nameCard
                    bankCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBankSheet) {
            BankListSheet(bankAccounts: $bankAccounts)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: showBankSheet) { _, isShown in
            if !isShown { bankAccounts = BankAccountStore.load() }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
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
                                        .font(AppTheme.Fonts.inter(40, weight: .medium))
                                        .foregroundColor(Color.appPrimary)
                                } else {
                                    Text(String(userName.prefix(1)).uppercased())
                                        .roundedFont(40, weight: .bold)
                                        .foregroundColor(Color.appPrimary)
                                }
                            }
                        }
                    }
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appCardBorder, lineWidth: 2))

                    ZStack {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                        Image(systemName: "camera.fill")
                            .font(AppTheme.Fonts.inter(14, weight: .semibold))
                            .foregroundColor(.white)
                    }
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

            Text("Change photo")
                .roundedFont(14, weight: .semibold)
                .foregroundColor(Color.appBrandText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Name

    private var nameCard: some View {
        section(label: "NAME") {
            HStack(spacing: 14) {
                iconChip("person.fill", color: Color.appPrimary)

                TextField("Your name", text: $userName)
                    .roundedFont(16, weight: .medium)
                    .foregroundColor(Color.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { nameFocused = false }

                if !userName.isEmpty && nameFocused {
                    Button {
                        userName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.textSecondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Bank accounts

    private var bankCard: some View {
        section(label: "PAYMENT INFO") {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showBankSheet = true
            } label: {
                HStack(spacing: 14) {
                    iconChip("building.columns.fill", color: Color(hex: "D97706"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bank accounts")
                            .roundedFont(16, weight: .medium)
                            .foregroundColor(Color.textPrimary)
                        Text(bankSummary)
                            .roundedFont(13, weight: .regular)
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(AppTheme.Fonts.inter(12, weight: .semibold))
                        .foregroundColor(Color.textSecondary.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var bankSummary: String {
        guard let first = bankAccounts.first else { return "Add an account so friends can pay you" }
        return bankAccounts.count > 1
            ? "\(first.bankName) +\(bankAccounts.count - 1) more"
            : first.bankName
    }

    // MARK: - Helpers

    private func section<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
                .padding(.leading, 4)

            content()
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
        }
    }

    private func iconChip(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: name)
                .font(AppTheme.Fonts.inter(16, weight: .medium))
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack { EditProfileView() }
}
