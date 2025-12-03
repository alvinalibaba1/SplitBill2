//
//  AddPersonSheet.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AddPersonSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 20) {
                Text("Add Person")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    TextField("Example: John", text: $name)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding()
                        .background(Color.appBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isFocused ? Color.green : Color.clear, lineWidth: 2)
                        )
                        .focused($isFocused)
                        .autocorrectionDisabled(true)
                }

                AnimatedButton(
                    title: "Add",
                    action: {
                        onAdd(name)
                        name = ""
                        isPresented = false
                    },
                    isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            .onAppear { isFocused = true }
        }
    }
}
