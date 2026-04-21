//
//  BankListSheet.swift
//  SplitBill
//

import SwiftUI

struct BankListSheet: View {

    @Binding var bankAccounts: [BankAccount]

    @Environment(\.dismiss) private var dismiss
    @State private var editingAccount: BankAccount? = nil
    @State private var showAddAccount               = false

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            Capsule()
                .fill(Color.textSecondary.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack {
                Text("Bank Accounts")
                    .roundedFont(20, weight: .bold)
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Done")
                        .roundedFont(16, weight: .semibold)
                        .foregroundColor(Color.appPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()
                .background(Color.textSecondary.opacity(0.1))

            // List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if bankAccounts.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(bankAccounts) { account in
                                accountRow(account)

                                if account.id != bankAccounts.last?.id {
                                    Divider()
                                        .background(Color.textSecondary.opacity(0.08))
                                        .padding(.leading, 70)
                                }
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
                    }

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
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
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
    }

    // MARK: - Account Row

    @ViewBuilder
    private func accountRow(_ account: BankAccount) -> some View {
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

            // Edit button
            Button(action: { editingAccount = account }) {
                Image(systemName: "pencil")
                    .font(AppTheme.Fonts.inter(14, weight: .medium))
                    .foregroundColor(Color.appPrimary)
                    .padding(8)
                    .background(Color.appPrimary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    bankAccounts.removeAll { $0.id == account.id }
                    BankAccountStore.save(bankAccounts)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(AppTheme.Fonts.inter(44))
                .foregroundColor(Color.textSecondary.opacity(0.25))

            Text("No bank accounts yet")
                .roundedFont(16, weight: .semibold)
                .foregroundColor(Color.textSecondary)

            Text("Add your bank account so others know where to transfer.")
                .roundedFont(13, weight: .regular)
                .foregroundColor(Color.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func maskedNumber(_ number: String) -> String {
        number.count <= 4 ? number : "•••• \(number.suffix(4))"
    }
}

#Preview("With Accounts") {
    BankListSheet(bankAccounts: .constant([
        BankAccount(bankName: "BCA",     accountNumber: "1234567890", accountName: "Alvin R."),
        BankAccount(bankName: "Mandiri", accountNumber: "9876543210", accountName: "Alvin R.")
    ]))
}

#Preview("Empty") {
    BankListSheet(bankAccounts: .constant([]))
}
