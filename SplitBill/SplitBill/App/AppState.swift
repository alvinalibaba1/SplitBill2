//
//  AppState.swift
//  SplitBill
//

import Foundation

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var pendingBillId: UUID? = nil
    private init() {}
}
