//
//  AnimatedButton.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AnimatedButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Text(title)
                .font(AppTheme.Fonts.inter(18, weight: .semibold))
                .foregroundColor(isEnabled ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? Color.appPrimary : Color.gray.opacity(0.3))
                .cornerRadius(16)
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .disabled(!isEnabled)
    }
}
