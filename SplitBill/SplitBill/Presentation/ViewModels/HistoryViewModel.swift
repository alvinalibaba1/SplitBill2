//
//  HistoryViewModel.swift
//  SplitBill
//

import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    @Published var history: [BillHistory] = []
    private var cancellables = Set<AnyCancellable>()
    
    private let repository: BillRepositoryProtocol
    
    // Singleton for easy replacement of StorageManager.shared in views
    static let shared = HistoryViewModel()
    
    init(repository: BillRepositoryProtocol = BillRepository(dataSource: LocalDataSource())) {
        self.repository = repository
        
        repository.historyPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.history, on: self)
            .store(in: &cancellables)
    }
    
    func saveHistory(_ bill: BillHistory) {
        repository.saveHistory(bill)
    }
    
    func deleteHistory(at offsets: IndexSet) {
        repository.deleteHistory(at: offsets)
    }
    
    func clearAllHistory() {
        repository.clearAllHistory()
    }

    func updateHistory(_ bill: BillHistory) {
        repository.updateHistory(bill)
    }

    /// Toggle paid status for a single person inside a bill, then persist.
    func markPersonPaid(billId: UUID, personId: UUID, isPaid: Bool) {
        guard let billIndex = history.firstIndex(where: { $0.id == billId }) else { return }
        var bill = history[billIndex]
        guard let personIndex = bill.people.firstIndex(where: { $0.id == personId }) else { return }
        var updatedPeople = bill.people
        updatedPeople[personIndex].isPaid = isPaid
        let updatedBill = BillHistory(
            id: bill.id,
            date: bill.date,
            title: bill.title,
            totalAmount: bill.totalAmount,
            people: updatedPeople,   // [HistoryPerson] — uses the preserving init
            splitAmount: bill.splitAmount
        )
        repository.updateHistory(updatedBill)
    }
}
