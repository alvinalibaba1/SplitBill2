//
//  Adjustment.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

struct Adjustment: Identifiable, Codable {
    let id = UUID()
    var name: String
    var amount: Double
    var isDiscount: Bool
}
