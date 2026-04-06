//
//  RouterDestination.swift
//  SplitBill
//

import Foundation

enum RouterDestination: Hashable {
    case historyDetail(BillHistory)
    case manualInput
    case scanReview(ScannedBillData)
    case billResult(ScannedBillData)
}
