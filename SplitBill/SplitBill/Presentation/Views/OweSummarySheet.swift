//
//  OweSummarySheet.swift
//  SplitBill
//

import SwiftUI

struct OweSummarySheet: View {

    let history: [BillHistory]
    let onBillTap: (BillHistory) -> Void

    @Environment(\.dismiss) private var dismiss

    private var bills: [BillHistory] {
        history
            .filter { !$0.people.isEmpty }
            .sorted { $0.date > $1.date }
    }

    private var totalOwed: Double {
        history.reduce(0) { total, bill in
            total + bill.people.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        }
    }

    private var unpaidBillCount: Int {
        history.filter { $0.people.contains { !$0.isPaid } }.count
    }

    private var allSettled: Bool { totalOwed == 0 && !history.isEmpty }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Handle
            Capsule()
                .fill(Color.textSecondary.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // MARK: - Header
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Who Owes You")
                        .roundedFont(13, weight: .semibold)
                        .foregroundColor(Color.textSecondary)
                        .tracking(0.5)

                    Text(allSettled ? "All Settled!" : totalOwed.toCurrency())
                        .roundedFont(36, weight: .bold)
                        .foregroundColor(allSettled ? .green : Color.appPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: totalOwed)
                }

                // Status pills
                HStack(spacing: 8) {
                    statPill(
                        value: "\(bills.count)",
                        label: "bills",
                        color: Color.appPrimary
                    )

                    if unpaidBillCount > 0 {
                        statPill(
                            value: "\(unpaidBillCount)",
                            label: "with unpaid",
                            color: Color.appSecondary
                        )
                    }

                    if allSettled {
                        statPill(value: "✓", label: "settled", color: .green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
            .padding(.horizontal, 24)

            Divider()
                .background(Color.textSecondary.opacity(0.1))

            // MARK: - Bill List
            if bills.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(bills) { bill in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onBillTap(bill)
                                }
                            }) {
                                HistoryCardView(bill: bill, showPaymentStatus: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Stat Pill

    private func statPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .roundedFont(13, weight: .bold)
                .foregroundColor(color)
            Text(label)
                .roundedFont(12, weight: .regular)
                .foregroundColor(Color.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(AppTheme.Fonts.inter(48))
                .foregroundColor(Color.textSecondary.opacity(0.3))

            Text("No bills yet")
                .roundedFont(17, weight: .semibold)
                .foregroundColor(Color.textSecondary)

            Text("Add your first bill to start tracking who owes you.")
                .roundedFont(14, weight: .regular)
                .foregroundColor(Color.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
