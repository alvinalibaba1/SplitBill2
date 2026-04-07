//
//  BillRepository.swift
//  SplitBill
//

import Foundation
import Combine

class BillRepository: BillRepositoryProtocol {
    private let dataSource: LocalDataSource
    private let historySubject = CurrentValueSubject<[BillHistory], Never>([])

    // In-memory cache synced with dataSource
    private var currentHistory: [BillHistory] = [] {
        didSet {
            historySubject.send(currentHistory)
            dataSource.saveHistoryList(currentHistory)
        }
    }

    var historyPublisher: AnyPublisher<[BillHistory], Never> {
        historySubject.eraseToAnyPublisher()
    }

    init(dataSource: LocalDataSource = LocalDataSource()) {
        self.dataSource = dataSource
        self.fetchHistory()
    }

    func fetchHistory() {
        currentHistory = dataSource.loadHistoryList()
    }

    func saveHistory(_ bill: BillHistory) {
        var newHistory = currentHistory
        newHistory.insert(bill, at: 0)

        // Keep only last 50 items
        if newHistory.count > 50 {
            newHistory = Array(newHistory.prefix(50))
        }

        currentHistory = newHistory
    }

    func deleteHistory(at offsets: IndexSet) {
        var newHistory = currentHistory
        newHistory.remove(atOffsets: offsets)
        currentHistory = newHistory
    }

    func clearAllHistory() {
        currentHistory.removeAll()
    }

    func updateHistory(_ bill: BillHistory) {
        if let index = currentHistory.firstIndex(where: { $0.id == bill.id }) {
            var newHistory = currentHistory
            newHistory[index] = bill
            currentHistory = newHistory
        }
    }
}
