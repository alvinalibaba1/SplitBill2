//
//  LoadingState.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 10/12/25.
//

import Foundation
import Combine

class LoadingState: ObservableObject {
    static let shared = LoadingState()

    @Published var isProcessingScan: Bool = false

    private init() {}
}
