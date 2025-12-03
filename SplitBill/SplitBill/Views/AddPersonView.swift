//
//  AddPersonView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AddPersonView: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Person")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)

                Text("Create a participant for this bill.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                Text("Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                TextField("Example: John", text: $name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color(red: 0.984, green: 0.984, blue: 0.984))
                    .cornerRadius(12)
                    .focused($isFocused)
                    .autocorrectionDisabled(true)
            }

            Spacer()

            AnimatedButton(
                title: "Save",
                action: {
                    onAdd(name)
                    dismiss()
                },
                isEnabled: isValid
            )
        }
        .padding()
        .background(Color.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFocused = true
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#Preview {
    NavigationStack {
        AddPersonView(onAdd: { _ in })
    }
}
