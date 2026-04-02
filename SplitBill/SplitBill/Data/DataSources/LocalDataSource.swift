//
//  LocalDataSource.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

class LocalDataSource {
    private let historyKey = "bill_history"

    func saveHistoryList(_ history: [BillHistory]) {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    func loadHistoryList() -> [BillHistory] {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([BillHistory].self, from: data) {
            return decoded
        }
        return []
    }
}
