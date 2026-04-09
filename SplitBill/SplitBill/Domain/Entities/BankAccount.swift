//
//  BankAccount.swift
//  SplitBill
//

import Foundation

struct BankAccount: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var bankName: String
    var accountNumber: String
    var accountName: String
}

enum BankAccountStore {
    private static let key = "bankAccounts"

    static func load() -> [BankAccount] {
        // Migration: if new key doesn't exist yet, check old AppStorage keys
        if UserDefaults.standard.data(forKey: key) == nil {
            let oldBankName    = UserDefaults.standard.string(forKey: "bankName") ?? ""
            let oldAccNumber   = UserDefaults.standard.string(forKey: "bankAccountNumber") ?? ""
            let oldAccName     = UserDefaults.standard.string(forKey: "bankAccountName") ?? ""

            if !oldBankName.isEmpty || !oldAccNumber.isEmpty || !oldAccName.isEmpty {
                let migrated = BankAccount(
                    bankName:      oldBankName,
                    accountNumber: oldAccNumber,
                    accountName:   oldAccName
                )
                save([migrated])
                // Clear old keys
                UserDefaults.standard.removeObject(forKey: "bankName")
                UserDefaults.standard.removeObject(forKey: "bankAccountNumber")
                UserDefaults.standard.removeObject(forKey: "bankAccountName")
                return [migrated]
            }
            return []
        }

        guard let data = UserDefaults.standard.data(forKey: key),
              let accounts = try? JSONDecoder().decode([BankAccount].self, from: data) else {
            return []
        }
        return accounts
    }

    static func save(_ accounts: [BankAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
