//
//  SplitBillViewModel.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation
import Combine

class SplitBillViewModel: ObservableObject {
    @Published var totalAmount: String
    @Published var billTitle: String
    @Published var people: [Person] = []
    @Published var items: [BillItem] = []
    @Published var adjustments: [Adjustment] = []
    @Published var scannedItems: [(name: String, price: Double)] = [] // Items from OCR scan

    init(billTitle: String = "", totalAmount: String = "", scannedItems: [(name: String, price: Double)] = []) {
        self.billTitle = billTitle
        self.totalAmount = totalAmount
        self.scannedItems = scannedItems
    }

    var totalAmountDouble: Double {
        Double(totalAmount) ?? 0.0
    }

    var computedTotal: Double {
        let peopleSum = people.reduce(0) { $0 + $1.amount }
        if peopleSum > 0 { return peopleSum }

        let itemSum = items.reduce(0) { $0 + $1.price }
        let adjustmentSum = adjustments.reduce(0) { $0 + ($1.isDiscount ? -$1.amount : $1.amount) }
        if itemSum + adjustmentSum > 0 { return itemSum + adjustmentSum }

        return 0
    }

    var totalForSplit: Double {
        computedTotal > 0 ? computedTotal : totalAmountDouble
    }

    var hasValidSplit: Bool {
        !people.isEmpty && totalForSplit > 0
    }

    var averageAmount: Double {
        guard !people.isEmpty else { return 0 }
        return totalForSplit / Double(people.count)
    }

    func addPerson(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var defaultAmount: Double = 0

        // If user provided a total and current amounts are uniform (or zero), prefill evenly.
        let uniqueAmounts = Set(people.map { $0.amount })
        let canEvenSplit = uniqueAmounts.count <= 1 && totalAmountDouble > 0
        if canEvenSplit {
            let evenAmount = totalAmountDouble / Double(max(people.count + 1, 1))
            for index in people.indices {
                people[index].amount = evenAmount
            }
            defaultAmount = evenAmount
        }
        let person = Person(name: name, amount: defaultAmount)
        people.append(person)
        recalcTotals()
    }

    func removePerson(at offsets: IndexSet) {
        let ids = offsets.compactMap { people[$0].id }
        people.remove(atOffsets: offsets)
        items.removeAll { ids.contains($0.personId) }
        recalcTotals()
    }

    func updatePersonAmount(id: UUID, amount: Double) {
        if let index = people.firstIndex(where: { $0.id == id }) {
            people[index].amount = amount
        }
    }

    func addItem(name: String, price: Double, personId: UUID, quantity: Int = 1) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, price > 0 else { return }
        let item = BillItem(name: name, price: price, personId: personId, quantity: max(1, quantity))
        items.append(item)
        recalcTotals()
    }

    func assignScannedItem(_ scanned: (name: String, price: Double), to personId: UUID) {
        addItem(name: scanned.name, price: scanned.price, personId: personId, quantity: 1)
        removeScannedItem(named: scanned.name, price: scanned.price)
    }

    func removeScannedItem(named name: String, price: Double) {
        if let idx = scannedItems.firstIndex(where: { $0.name.lowercased() == name.lowercased() && abs($0.price - price) < 0.01 }) {
            scannedItems.remove(at: idx)
        }
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        recalcTotals()
    }

    func copyItem(_ item: BillItem, to personId: UUID) {
        let copy = BillItem(name: item.name, price: item.price, personId: personId, quantity: item.quantity)
        items.append(copy)
        recalcTotals()
    }

    func removeItem(name: String, price: Double, personId: UUID) {
        if let idx = items.firstIndex(where: { $0.personId == personId && $0.name == name && $0.price == price }) {
            items.remove(at: idx)
            recalcTotals()
        }
    }

    func addAdjustment(name: String, amount: Double, isDiscount: Bool) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, amount > 0 else { return }
        let adj = Adjustment(name: name, amount: amount, isDiscount: isDiscount)
        adjustments.append(adj)
        recalcTotals()
    }

    func removeAdjustment(id: UUID) {
        adjustments.removeAll { $0.id == id }
        recalcTotals()
    }

    func recalcTotals() {
        guard !people.isEmpty else { return }

        var totals: [UUID: Double] = [:]

        for item in items {
            totals[item.personId, default: 0] += item.price * Double(item.quantity)
        }

        let adjustmentSum = adjustments.reduce(0) { $0 + ($1.isDiscount ? -$1.amount : $1.amount) }
        let perPersonAdj = adjustmentSum / Double(max(people.count, 1))

        for index in people.indices {
            let pid = people[index].id
            let base = totals[pid] ?? 0
            people[index].amount = base + perPersonAdj
        }
    }

    func reset() {
        totalAmount = ""
        billTitle = ""
        people = []
        items = []
        adjustments = []
        scannedItems = []
    }
}
