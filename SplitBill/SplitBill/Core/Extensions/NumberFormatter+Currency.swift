//
//  NumberFormatter+Currency.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import Foundation

extension Double {
    func toCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        if let formatted = formatter.string(from: NSNumber(value: self)) {
            return "Rp \(formatted)"
        }
        return "Rp 0"
    }
}

extension String {
    func toDouble() -> Double {
        // Remove any non-digit characters except decimal separator
        let cleaned = self.replacingOccurrences(of: ".", with: "")
                         .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0.0
    }

    func formatAsCurrency() -> String {
        // Remove non-digits
        let digits = self.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }

        // Convert to double and format
        if let number = Double(digits) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = "."
            formatter.decimalSeparator = ","
            formatter.maximumFractionDigits = 0

            return formatter.string(from: NSNumber(value: number)) ?? digits
        }

        return digits
    }
}
