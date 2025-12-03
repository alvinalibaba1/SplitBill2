//
//  BillHistory.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

struct BillHistory: Identifiable, Codable {
    let id: UUID
    let date: Date
    let title: String
    let totalAmount: Double
    let people: [HistoryPerson]
    let splitAmount: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String = "",
        totalAmount: Double,
        people: [Person],
        splitAmount: Double
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.totalAmount = totalAmount
        self.people = people.map { HistoryPerson(name: $0.name, amount: $0.amount) }
        self.splitAmount = splitAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        people = try container.decode([HistoryPerson].self, forKey: .people)
        splitAmount = try container.decode(Double.self, forKey: .splitAmount)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

struct HistoryPerson: Identifiable, Codable {
    let id: UUID
    let name: String
    let amount: Double

    init(id: UUID = UUID(), name: String, amount: Double) {
        self.id = id
        self.name = name
        self.amount = amount
    }
}
