//
//  AddAdjustmentSheet.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AddAdjustmentSheet: View {
    @Binding var isPresented: Bool
    var defaultName: String = ""
    var defaultIsDiscount: Bool = false
    let onAdd: (String, Double, Bool) -> Void

    @State private var name: String = ""
    @State private var amountText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                Text("Add Extra")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Label")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    TextField("e.g. Tax", text: $name)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding()
                        .background(Color(red: 0.984, green: 0.984, blue: 0.984))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Amount")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    TextField("0", text: $amountText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(red: 0.984, green: 0.984, blue: 0.984))
                        .cornerRadius(12)
                        .onChange(of: amountText) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            let formatted = digits.formatAsCurrency()
                            if formatted != newValue {
                                amountText = formatted
                            }
                        }
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal)

                Spacer()

                AnimatedButton(
                    title: "Add",
                    action: {
                        let raw = amountText.filter { $0.isNumber }
                        let amount = Double(raw) ?? 0
                        onAdd(name, amount, defaultIsDiscount)
                        isPresented = false
                    },
                    isEnabled: isValid
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .onAppear {
                name = defaultName
                isFocused = true
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    private var isValid: Bool {
        let amount = Double(amountText.filter { $0.isNumber }) ?? 0
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }
}

#Preview {
    AddAdjustmentSheet(
        isPresented: .constant(true),
        defaultName: "Tax",
        defaultIsDiscount: false,
        onAdd: { _, _, _ in }
    )
}
