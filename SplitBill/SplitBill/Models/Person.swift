//
//  Person.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

struct Person: Identifiable, Equatable, Hashable {
    let id = UUID()
    var name: String
    var amount: Double = 0.0

    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }
}
