//
//  BankAccountFormSheet.swift
//  SplitBill
//

import SwiftUI

struct BankAccountFormSheet: View {

    @Environment(\.dismiss) private var dismiss

    var account: BankAccount
    var onSave: (BankAccount) -> Void

    @State private var bankName:       String
    @State private var accountNumber:  String
    @State private var accountName:    String

    private var isEditing: Bool {
        !account.bankName.isEmpty || !account.accountNumber.isEmpty || !account.accountName.isEmpty
    }

    init(account: BankAccount, onSave: @escaping (BankAccount) -> Void) {
        self.account  = account
        self.onSave   = onSave
        _bankName      = State(initialValue: account.bankName)
        _accountNumber = State(initialValue: account.accountNumber)
        _accountName   = State(initialValue: account.accountName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Bank Name
                        formSection {
                            formRow(
                                icon: "building.columns.fill",
                                iconColor: Color(hex: "F59E0B"),
                                placeholder: "e.g. BCA, Mandiri, GoPay",
                                text: $bankName,
                                keyboard: .default
                            )

                            Divider().padding(.leading, 52)

                            formRow(
                                icon: "creditcard.fill",
                                iconColor: Color(hex: "8B5CF6"),
                                placeholder: "Account number",
                                text: $accountNumber,
                                keyboard: .numberPad
                            )

                            Divider().padding(.leading, 52)

                            formRow(
                                icon: "person.text.rectangle.fill",
                                iconColor: Color(hex: "10B981"),
                                placeholder: "Name on account",
                                text: $accountName,
                                keyboard: .default
                            )
                        }

                        Spacer(minLength: 32)

                        // Save button
                        Button(action: saveAndDismiss) {
                            Text("Save")
                                .roundedFont(16, weight: .semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(bankName.isEmpty ? Color.appPrimary.opacity(0.4) : Color.appPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(bankName.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle(isEditing ? "Edit Bank Account" : "Add Bank Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndDismiss() }
                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                        .foregroundColor(bankName.isEmpty ? Color.appPrimary.opacity(0.4) : Color.appPrimary)
                        .disabled(bankName.isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func saveAndDismiss() {
        guard !bankName.isEmpty else { return }
        var saved = account
        saved.bankName      = bankName
        saved.accountNumber = accountNumber
        saved.accountName   = accountName
        onSave(saved)
        dismiss()
    }

    @ViewBuilder
    private func formSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func formRow(
        icon: String,
        iconColor: Color,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
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

            TextField(placeholder, text: text)
                .font(AppTheme.Fonts.inter(15, weight: .regular))
                .foregroundColor(Color.textPrimary)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

#Preview {
    BankAccountFormSheet(
        account: BankAccount(bankName: "", accountNumber: "", accountName: "")
    ) { _ in }
}
