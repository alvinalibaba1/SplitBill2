//
//  OweSummarySheet.swift
//  SplitBill
//

import SwiftUI

struct OweSummarySheet: View {

    let history: [BillHistory]
    let onBillTap: (BillHistory) -> Void

    @Environment(\.dismiss) private var dismiss

    // Bills sorted newest first, only those with people
    private var bills: [BillHistory] {
        history
            .filter { !$0.people.isEmpty }
            .sorted { $0.date > $1.date }
    }

    private var totalOwed: Double {
        history.reduce(0) { $0 + $1.totalAmount }
    }

    // Unpaid people count across all bills
    private var totalUnpaid: Int {
        history.flatMap { $0.people }.filter { !$0.isPaid }.count
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

                HStack(spacing: 6) {
                    Text(totalOwed.toCurrency())
                        .roundedFont(15, weight: .semibold)
                        .foregroundColor(Color.appPrimary)

                    if totalUnpaid > 0 {
                        Text("·")
                            .foregroundColor(Color.textSecondary)
                        Text("\(totalUnpaid) unpaid")
                            .roundedFont(14, weight: .medium)
                            .foregroundColor(Color.appSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            Divider()
                .background(Color.textSecondary.opacity(0.1))

            if bills.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(bills) { bill in
                            billRow(bill)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.appSurface.ignoresSafeArea())
    }

    // MARK: - Bill Row

    @ViewBuilder
    private func billRow(_ bill: BillHistory) -> some View {
        let unpaidPeople = bill.people.filter { !$0.isPaid }
        let allPaid = unpaidPeople.isEmpty

        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onBillTap(bill)
            }
        }) {
            HStack(spacing: 14) {
                // Bill icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(allPaid
                              ? Color.green.opacity(0.12)
                              : Color.appPrimary.opacity(0.10))
                        .frame(width: 48, height: 48)

                    Image(systemName: allPaid ? "checkmark.seal.fill" : "doc.text.fill")
                        .font(.system(size: 20))
                        .foregroundColor(allPaid ? .green : Color.appPrimary)
                }

                // Bill info
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.title.isEmpty ? "Untitled Bill" : bill.title)
                        .roundedFont(15, weight: .semibold)
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)

                    Text(bill.formattedDate)
                        .roundedFont(12, weight: .regular)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                // Right side: amount + badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(bill.totalAmount.toCurrency())
                        .roundedFont(15, weight: .bold)
                        .foregroundColor(Color.textPrimary)

                    if allPaid {
                        Text("All paid ✓")
                            .roundedFont(11, weight: .semibold)
                            .foregroundColor(.green)
                    } else {
                        Text("\(unpaidPeople.count) unpaid")
                            .roundedFont(11, weight: .semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appSecondary.opacity(0.15))
                            .foregroundColor(Color.appSecondary)
                            .clipShape(Capsule())
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.textSecondary.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(allPaid
                            ? Color.green.opacity(0.2)
                            : Color.textSecondary.opacity(0.08),
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
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
