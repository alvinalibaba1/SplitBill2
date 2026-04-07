//
//  BillRepositoryProtocol.swift
//  SplitBill
//

import Foundation
import Combine

protocol BillRepositoryProtocol {
    var historyPublisher: AnyPublisher<[BillHistory], Never> { get }
    func fetchHistory()
    func saveHistory(_ bill: BillHistory)
    func deleteHistory(at offsets: IndexSet)
    func clearAllHistory()
    func updateHistory(_ bill: BillHistory)
}
