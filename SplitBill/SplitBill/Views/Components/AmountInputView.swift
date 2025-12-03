//
//  AmountInputView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AmountInputView: View {
    @Binding var amount: String
    let placeholder: String

    @FocusState private var isFocused: Bool
    @State private var displayAmount: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Rp")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)

                TextField("", text: $displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .multilineTextAlignment(.leading)
                    .autocorrectionDisabled(true)
                    .onChange(of: displayAmount) { oldValue, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        amount = digits

                        if !digits.isEmpty {
                            displayAmount = digits.formatAsCurrency()
                        }
                    }
                    .overlay(
                        Group {
                            if displayAmount.isEmpty {
                                Text(placeholder)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.3))
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .leading
                    )
            }

            Rectangle()
                .fill(isFocused ? Color.black : Color.gray.opacity(0.3))
                .frame(height: 2)
                .animation(.spring(response: 0.3), value: isFocused)
        }
        .padding()
        .onAppear {
            isFocused = true
            if !amount.isEmpty {
                displayAmount = amount.formatAsCurrency()
            }
        }
    }
}
