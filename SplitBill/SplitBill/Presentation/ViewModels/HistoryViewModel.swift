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
}
