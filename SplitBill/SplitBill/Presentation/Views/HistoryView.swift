//
//  HistoryView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel = HistoryViewModel.shared

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if viewModel.history.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppTheme.Fonts.inter(64))
                        .foregroundColor(Color.textSecondary.opacity(0.3))

                    Text("No History Yet")
                        .font(AppTheme.Fonts.inter(20, weight: .semibold))
                        .foregroundColor(Color.textSecondary)

                    Text("Your first split bill will appear here")
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.history) { bill in
                            NavigationLink(destination: HistoryDetailView(bill: bill)) {
                                HistoryCardView(bill: bill)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        if let idx = viewModel.history.firstIndex(where: { $0.id == bill.id }) {
                                            viewModel.deleteHistory(at: IndexSet(integer: idx))
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - History Card
struct HistoryCardView: View {
    let bill: BillHistory
    var showPaymentStatus: Bool = false   // shows paid/unpaid badge when true

    // Max 5 avatars, then show overflow
    private let maxAvatars = 5

    private var visiblePeople: [HistoryPerson] {
        Array(bill.people.prefix(maxAvatars))
    }

    private var overflowCount: Int {
        max(0, bill.people.count - maxAvatars)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            // Left: bill info
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.title.isEmpty ? "Untitled Bill" : bill.title)
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Text(bill.totalAmount.toCurrency())
                    .font(AppTheme.Fonts.inter(22, weight: .bold))
                    .foregroundColor(Color.textPrimary)

                Text(bill.formattedDate)
                    .font(AppTheme.Fonts.inter(12, weight: .medium))
                    .foregroundColor(Color.textSecondary)
                    .padding(.top, 2)
            }

            Spacer()

            // Right: people count + avatar stack + optional status badge
            VStack(alignment: .trailing, spacing: 8) {
                if showPaymentStatus {
                    let unpaidCount = bill.people.filter { !$0.isPaid }.count
                    if unpaidCount == 0 {
                        Label("All paid", systemImage: "checkmark.circle.fill")
                            .font(AppTheme.Fonts.inter(12, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(unpaidCount) unpaid")
                            .font(AppTheme.Fonts.inter(12, weight: .semibold))
                            .foregroundColor(Color.appSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.appSecondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else {
                    Text("\(bill.people.count) \(bill.people.count == 1 ? "person" : "people")")
                        .font(AppTheme.Fonts.inter(13, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }

                // Avatar stack
                avatarStack

                Image(systemName: "chevron.right")
                    .font(AppTheme.Fonts.inter(12, weight: .semibold))
                    .foregroundColor(Color.textSecondary.opacity(0.35))
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // MARK: - Overlapping Avatar Stack
    private var avatarStack: some View {
        HStack(spacing: 0) {
            // Show up to maxAvatars people
            ForEach(Array(visiblePeople.enumerated()), id: \.element.id) { index, person in
                avatarCircle(
                    initial: String(person.name.prefix(1)).uppercased(),
                    color: avatarColor(index: index)
                )
                .offset(x: CGFloat(index) * -8)
                .zIndex(Double(visiblePeople.count - index))
            }

            // Overflow badge: "+N"
            if overflowCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.textSecondary.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                    Text("+\(overflowCount)")
                        .font(AppTheme.Fonts.inter(10, weight: .bold))
                        .foregroundColor(Color.textSecondary)
                }
                .offset(x: CGFloat(visiblePeople.count) * -8)
                .zIndex(0)
            }
        }
        // Compensate for the negative offsets
        .padding(.trailing, CGFloat(min(bill.people.count, maxAvatars + (overflowCount > 0 ? 1 : 0)) - 1) * 8)
    }

    private func avatarCircle(initial: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 28, height: 28)
            Text(initial)
                .font(AppTheme.Fonts.inter(11, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func avatarColor(index: Int) -> Color {
        let colors: [Color] = [
            Color.appPrimary,
            Color.appSecondary,
            Color(hex: "A29BFE"),
            Color(hex: "FD79A8"),
            Color(hex: "FDCB6E"),
            Color(hex: "00B894"),
        ]
        return colors[index % colors.count]
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
