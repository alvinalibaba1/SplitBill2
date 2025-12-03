//
//  StorageManager.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

class StorageManager: ObservableObject {
    static let shared = StorageManager()

    @Published var history: [BillHistory] = []

    private let historyKey = "bill_history"

    init() {
        loadHistory()
    }

    func saveHistory(_ bill: BillHistory) {
        history.insert(bill, at: 0)

        // Keep only last 50 items
        if history.count > 50 {
            history = Array(history.prefix(50))
        }

        saveToUserDefaults()
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveToUserDefaults()
    }

    func clearAllHistory() {
        history.removeAll()
        saveToUserDefaults()
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([BillHistory].self, from: data) {
            history = decoded
        }
    }
}
