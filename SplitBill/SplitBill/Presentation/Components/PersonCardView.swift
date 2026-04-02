//
//  PersonCardView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct PersonCardView: View {
    let person: Person
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var appear = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(AppTheme.Fonts.inter(17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }

            Spacer()

            HStack(spacing: 12) {
                Text(person.amount.toCurrency())
                    .font(AppTheme.Fonts.inter(18, weight: .bold))
                    .foregroundColor(Color.textPrimary)

                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.4))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .scaleEffect(appear ? 1 : 0.5)
        .opacity(appear ? 1 : 0)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}
