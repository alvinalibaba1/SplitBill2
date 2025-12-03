//
//  BillItem.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

struct BillItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var price: Double
    var personId: UUID
    var quantity: Int = 1
}
