//
//  StatsView.swift
//  SplitBill
//

import SwiftUI
import Charts

struct StatsView: View {

    @ObservedObject private var viewModel = HistoryViewModel.shared
    @EnvironmentObject var router: NavigationRouter

    // MARK: - Computed Stats

    private var totalBills: Int { viewModel.history.count }

    private var totalAmount: Double {
        viewModel.history.reduce(0) { $0 + $1.totalAmount }
    }

    private var averageBill: Double {
        guard totalBills > 0 else { return 0 }
        return totalAmount / Double(totalBills)
    }

    private var biggestBill: BillHistory? {
        viewModel.history.max(by: { $0.totalAmount < $1.totalAmount })
    }

    private var monthlyData: [MonthStat] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        return (0..<6).reversed().compactMap { offset -> MonthStat? in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let month = calendar.component(.month, from: date)
            let year  = calendar.component(.year,  from: date)
            let total = viewModel.history
                .filter {
                    calendar.component(.month, from: $0.date) == month &&
                    calendar.component(.year,  from: $0.date) == year
                }
                .reduce(0) { $0 + $1.totalAmount }
            return MonthStat(label: formatter.string(from: date), total: total)
        }
    }

    private var topPeople: [(name: String, count: Int, total: Double)] {
        var map: [String: (count: Int, total: Double)] = [:]
        for bill in viewModel.history {
            for person in bill.people {
                let existing = map[person.name] ?? (0, 0)
                map[person.name] = (existing.count + 1, existing.total + person.amount)
            }
        }
        return map
            .map { (name: $0.key, count: $0.value.count, total: $0.value.total) }
            .sorted { $0.count > $1.count }
            .prefix(4)
            .map { $0 }
    }

    private var currentMonthTotal: Double {
        let calendar = Calendar.current
        let now = Date()
        return viewModel.history
            .filter {
                calendar.component(.month, from: $0.date) == calendar.component(.month, from: now) &&
                calendar.component(.year,  from: $0.date) == calendar.component(.year,  from: now)
            }
            .reduce(0) { $0 + $1.totalAmount }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if viewModel.history.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryCards
                        monthlyChart
                        topPeopleSection
                        biggestBillCard
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "doc.text.fill",
                iconColor: Color.appPrimary,
                label: "Total Bills",
                value: "\(totalBills)"
            )
            statCard(
                icon: "calendar",
                iconColor: Color.appSecondary,
                label: "This Month",
                value: currentMonthTotal.toCurrency()
            )
        }
    }

    private func statCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            Spacer()

            Text(value)
                .font(AppTheme.Fonts.inter(22, weight: .bold))
                .foregroundColor(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())

            Text(label)
                .font(AppTheme.Fonts.inter(13, weight: .regular))
                .foregroundColor(Color.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Monthly Chart

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Monthly Spending")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                Spacer()
                Text(totalAmount.toCurrency())
                    .font(AppTheme.Fonts.inter(14, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
            }

            if monthlyData.allSatisfy({ $0.total == 0 }) {
                Text("No spending data yet")
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(monthlyData) { stat in
                    BarMark(
                        x: .value("Month", stat.label),
                        y: .value("Total", stat.total)
                    )
                    .foregroundStyle(
                        stat.total == monthlyData.max(by: { $0.total < $1.total })?.total
                            ? Color.appPrimary
                            : Color.appPrimary.opacity(0.3)
                    )
                    .cornerRadius(6)
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(AppTheme.Fonts.inter(11, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 140)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Top People

    private var topPeopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top People")
                .font(AppTheme.Fonts.inter(16, weight: .semibold))
                .foregroundColor(Color.textPrimary)

            if topPeople.isEmpty {
                Text("No people data yet")
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topPeople.enumerated()), id: \.offset) { index, person in
                        HStack(spacing: 12) {
                            // Rank badge
                            ZStack {
                                Circle()
                                    .fill(index == 0 ? Color.appPrimary : Color.appPrimary.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Text("\(index + 1)")
                                    .font(AppTheme.Fonts.inter(14, weight: .bold))
                                    .foregroundColor(index == 0 ? .white : Color.appPrimary)
                            }

                            Text(person.name)
                                .font(AppTheme.Fonts.inter(15, weight: .medium))
                                .foregroundColor(Color.textPrimary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(person.total.toCurrency())
                                    .font(AppTheme.Fonts.inter(14, weight: .semibold))
                                    .foregroundColor(Color.textPrimary)
                                Text("\(person.count) bill\(person.count == 1 ? "" : "s")")
                                    .font(AppTheme.Fonts.inter(12, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                        .padding(.vertical, 10)

                        if index < topPeople.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Biggest Bill

    @ViewBuilder
    private var biggestBillCard: some View {
        if let bill = biggestBill {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Biggest Bill")
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(Color.textPrimary)
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .foregroundColor(Color(hex: "F59E0B"))
                        .font(.system(size: 16))
                }

                Button(action: { router.push(.historyDetail(bill)) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appSecondary.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color.appSecondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.title.isEmpty ? "Untitled Bill" : bill.title)
                                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                .foregroundColor(Color.textPrimary)
                            Text(bill.formattedDate)
                                .font(AppTheme.Fonts.inter(12, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                        }

                        Spacer()

                        Text(bill.totalAmount.toCurrency())
                            .font(AppTheme.Fonts.inter(15, weight: .bold))
                            .foregroundColor(Color.appPrimary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.4))
                    }
                    .padding(12)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 52))
                .foregroundColor(Color.textSecondary.opacity(0.2))
            Text("No data yet")
                .font(AppTheme.Fonts.inter(18, weight: .semibold))
                .foregroundColor(Color.textSecondary)
            Text("Complete your first bill split to see insights here.")
                .font(AppTheme.Fonts.inter(14, weight: .regular))
                .foregroundColor(Color.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Data Model

struct MonthStat: Identifiable {
    let id = UUID()
    let label: String
    let total: Double
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(NavigationRouter())
    }
}
