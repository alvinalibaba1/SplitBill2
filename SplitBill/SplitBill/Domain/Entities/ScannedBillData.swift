//
//  ScannedBillData.swift
//  SplitBill
//

import Foundation

struct ScannedBillData: Identifiable, Hashable {
    let id = UUID()
    let billName: String
    let total: String
    let items: [(name: String, price: Double)]
    let adjustments: [(name: String, amount: Double)]
    var parsedByAI: Bool = false   // true = Gemini answered

    static func == (lhs: ScannedBillData, rhs: ScannedBillData) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
