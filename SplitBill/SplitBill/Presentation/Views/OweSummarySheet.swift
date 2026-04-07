//
//  OweSummarySheet.swift
//  SplitBill
//
//  Created by Claude on 07/04/26.
//

import SwiftUI

// MARK: - Data Models

struct PersonDebt: Identifiable {
    let id = UUID()
    let name: String
    let totalOwed: Double
    let bills: [BillDebt]

    var initial: String { String(name.prefix(1)).uppercased() }
}

struct BillDebt: Identifiable {
    let id = UUID()
    let bill: BillHistory
    let amount: Double
}

// MARK: - Sheet View

struct OweSummarySheet: View {

    let history: [BillHistory]
    let onBillTap: (BillHistory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedPerson: UUID? = nil

    // Aggregate person debts across all bills
    private var personDebts: [PersonDebt] {
        var map: [String: [BillDebt]] = [:]

        for bill in history {
            for person in bill.people where person.amount > 0 {
                let key = person.name.trimmingCharacters(in: .whitespaces)
                map[key, default: []].append(BillDebt(bill: bill, amount: person.amount))
            }
        }

        return map
            .map { name, bills in
                PersonDebt(
                    name: name,
                    totalOwed: bills.reduce(0) { $0 + $1.amount },
                    bills: bills.sorted { $0.bill.date > $1.bill.date }
                )
            }
            .sorted { $0.totalOwed > $1.totalOwed }
    }

    private var totalOwed: Double {
        history.reduce(0) { $0 + $1.totalAmount }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.textSecondary.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            VStack(spacing: 6) {
                Text("Who Owes You")
                    .roundedFont(22, weight: .bold)
                    .foregroundColor(Color.textPrimary)

                Text(totalOwed.toCurrency())
                    .roundedFont(15, weight: .medium)
                    .foregroundColor(Color.appPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)

            Divider()
                .background(Color.textSecondary.opacity(0.1))

            if personDebts.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(personDebts) { debt in
                            personRow(debt)
                            Divider()
                                .background(Color.textSecondary.opacity(0.08))
                                .padding(.leading, 72)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
    }

    // MARK: - Person Row

    @ViewBuilder
    private func personRow(_ debt: PersonDebt) -> some View {
        let isExpanded = expandedPerson == debt.id

        VStack(spacing: 0) {
            // Main row — tap to expand/collapse
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    expandedPerson = isExpanded ? nil : debt.id
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                HStack(spacing: 14) {
                    // Avatar
                    avatarCircle(debt.name, index: personDebts.firstIndex(where: { $0.id == debt.id }) ?? 0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.name)
                            .roundedFont(16, weight: .semibold)
                            .foregroundColor(Color.textPrimary)

                        Text("\(debt.bills.count) bill\(debt.bills.count == 1 ? "" : "s")")
                            .roundedFont(12, weight: .regular)
                            .foregroundColor(Color.textSecondary)
                    }

                    Spacer()

                    Text(debt.totalOwed.toCurrency())
                        .roundedFont(16, weight: .bold)
                        .foregroundColor(Color.appPrimary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.textSecondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            // Expanded bill list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(debt.bills) { billDebt in
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onBillTap(billDebt.bill)
                            }
                        }) {
                            HStack(spacing: 12) {
                                // Timeline dot
                                VStack {
                                    Circle()
                                        .fill(Color.appPrimary.opacity(0.4))
                                        .frame(width: 7, height: 7)
                                }
                                .frame(width: 52)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(billDebt.bill.title.isEmpty ? "Untitled Bill" : billDebt.bill.title)
                                        .roundedFont(14, weight: .medium)
                                        .foregroundColor(Color.textPrimary)

                                    Text(billDebt.bill.formattedDate)
                                        .roundedFont(11, weight: .regular)
                                        .foregroundColor(Color.textSecondary)
                                }

                                Spacer()

                                Text(billDebt.amount.toCurrency())
                                    .roundedFont(14, weight: .semibold)
                                    .foregroundColor(Color.appSecondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.textSecondary.opacity(0.35))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.appPrimary.opacity(0.04))
                        }
                        .buttonStyle(.plain)

                        if billDebt.id != debt.bills.last?.id {
                            Divider()
                                .background(Color.textSecondary.opacity(0.06))
                                .padding(.leading, 72)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Avatar

    private func avatarCircle(_ name: String, index: Int) -> some View {
        let colors: [Color] = [.appPrimary, .appSecondary, .purple, .teal, .indigo, .pink]
        let color = colors[index % colors.count]
        let initial = String(name.prefix(1)).uppercased()

        return Circle()
            .fill(color.opacity(0.18))
            .frame(width: 44, height: 44)
            .overlay(
                Text(initial)
                    .roundedFont(17, weight: .bold)
                    .foregroundColor(color)
            )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(Color.textSecondary.opacity(0.3))

            Text("No debts found")
                .roundedFont(17, weight: .semibold)
                .foregroundColor(Color.textSecondary)

            Text("Once you split a bill, you'll see who owes you here.")
                .roundedFont(14, weight: .regular)
                .foregroundColor(Color.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
