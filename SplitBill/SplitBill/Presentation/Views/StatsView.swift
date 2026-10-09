//
//  StatsView.swift
//  SplitBill
//

import SwiftUI
import Charts

struct StatsView: View {

    @ObservedObject private var viewModel = HistoryViewModel.shared
    @EnvironmentObject var router: NavigationRouter
    @AppStorage("appLanguage") private var appLanguage: String = "en"

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

    // MARK: - Month anchoring
    // The hero and chart follow "this month"; if it has no bills yet they fall back to
    // the most recent month that does, so the screen never opens on an empty "Rp 0".

    private var calendar: Calendar { Calendar.current }

    private func monthTotal(_ date: Date) -> Double {
        viewModel.history
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func monthBills(_ date: Date) -> Int {
        viewModel.history.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }.count
    }

    private var anchorDate: Date {
        let now = Date()
        if monthBills(now) > 0 { return now }
        return viewModel.history.map(\.date).max() ?? now
    }

    private var anchorIsCurrentMonth: Bool {
        calendar.isDate(anchorDate, equalTo: Date(), toGranularity: .month)
    }

    private var anchorLabel: String {
        if anchorIsCurrentMonth { return "stats.this.month".localized }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: anchorDate)
    }

    private var currentMonthTotal: Double { monthTotal(anchorDate) }
    private var currentMonthBills: Int { monthBills(anchorDate) }

    private var lastMonthTotal: Double {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: anchorDate) else { return 0 }
        return monthTotal(prev)
    }

    /// Percent change vs the month before the anchor; nil when there is nothing to compare against.
    private var monthDelta: Double? {
        guard lastMonthTotal > 0 else { return nil }
        return (currentMonthTotal - lastMonthTotal) / lastMonthTotal * 100
    }

    private var monthlyData: [MonthStat] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return (0..<6).reversed().compactMap { offset -> MonthStat? in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: anchorDate) else { return nil }
            return MonthStat(label: formatter.string(from: date), total: monthTotal(date))
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
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.total > $1.total }
            .prefix(4)
            .map { $0 }
    }

    private var paidTotal: Double {
        viewModel.history.flatMap(\.people).filter(\.isPaid).reduce(0) { $0 + $1.amount }
    }

    private var outstandingTotal: Double {
        viewModel.history.flatMap(\.people).filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    private var collectedFraction: Double {
        let all = paidTotal + outstandingTotal
        return all > 0 ? paidTotal / all : 0
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
                        heroCard
                        collectionCard
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
        .navigationTitle("stats.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero (this month)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(anchorLabel.uppercased())
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)

            Text(currentMonthTotal.toCurrency())
                .font(AppTheme.Fonts.inter(36, weight: .bold))
                .foregroundColor(Color.appBrandText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            HStack(spacing: 10) {
                if let delta = monthDelta {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(AppTheme.Fonts.inter(10, weight: .bold))
                        Text(String(format: "%.0f%%", abs(delta)))
                            .font(AppTheme.Fonts.inter(12, weight: .bold))
                    }
                    .foregroundColor(Color.appBrandText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.appIconChip)
                    .clipShape(Capsule())

                    Text("stats.vs.last.month".localized)
                        .font(AppTheme.Fonts.inter(13, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                } else {
                    Text("\(currentMonthBills) \(currentMonthBills == 1 ? "stats.bill".localized : "stats.bills".localized)")
                        .font(AppTheme.Fonts.inter(13, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .statsCard(accent: true)
    }

    // MARK: - Collection (paid vs outstanding)

    private var collectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("stats.collection".localized)
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                Spacer()
                Text(String(format: "stats.collected.pct".localized, Int((collectedFraction * 100).rounded())))
                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                    .foregroundColor(Color.appSuccess)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appWarningBackground)
                    Capsule()
                        .fill(Color.appSuccess)
                        .frame(width: max(0, geo.size.width * collectedFraction))
                }
            }
            .frame(height: 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: collectedFraction)

            HStack(alignment: .top) {
                legendItem(color: Color.appSuccess, label: "stats.paid".localized, value: paidTotal)
                Spacer()
                legendItem(color: Color.appWarningText, label: "stats.outstanding".localized, value: outstandingTotal, trailing: true)
            }
        }
        .padding(16)
        .statsCard()
    }

    private func legendItem(color: Color, label: String, value: Double, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(AppTheme.Fonts.inter(12, weight: .medium))
                    .foregroundColor(Color.textSecondary)
            }
            Text(value.toCurrency())
                .font(AppTheme.Fonts.inter(16, weight: .bold))
                .foregroundColor(Color.textPrimary)
        }
    }

    // MARK: - Summary (all-time)

    private var summaryCards: some View {
        HStack(spacing: 12) {
            statCard(icon: "doc.text.fill",
                     label: "stats.total.bills".localized,
                     value: "\(totalBills)")
            statCard(icon: "divide.circle.fill",
                     label: "stats.average".localized,
                     value: averageBill.toCurrency())
        }
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appIconChip)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                    .foregroundColor(Color.appPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTheme.Fonts.inter(17, weight: .bold))
                    .foregroundColor(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(AppTheme.Fonts.inter(12, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .statsCard()
    }

    // MARK: - Monthly Chart

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("stats.monthly.spending".localized)
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                Text("stats.last.six".localized)
                    .font(AppTheme.Fonts.inter(12, weight: .regular))
                    .foregroundColor(Color.textSecondary)
            }

            if monthlyData.allSatisfy({ $0.total == 0 }) {
                Text("stats.no.spending".localized)
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                let currentLabel = monthlyData.last?.label
                Chart(monthlyData) { stat in
                    BarMark(
                        x: .value("Month", stat.label),
                        y: .value("Total", stat.total),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(stat.label == currentLabel
                                     ? Color.appPrimary
                                     : Color.appPrimary.opacity(0.22))
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 4) {
                        if stat.total > 0 && stat.label == currentLabel {
                            Text(compact(stat.total))
                                .font(AppTheme.Fonts.inter(11, weight: .bold))
                                .foregroundColor(Color.appBrandText)
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(AppTheme.Fonts.inter(11, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .statsCard()
    }

    /// 168333 → "168k", 1250000 → "1.3M"
    private func compact(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000     { return String(format: "%.0fk", value / 1_000) }
        return String(format: "%.0f", value)
    }

    // MARK: - Top People

    private var topPeopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("stats.top.people".localized)
                .font(AppTheme.Fonts.inter(16, weight: .semibold))
                .foregroundColor(Color.textPrimary)

            if topPeople.isEmpty {
                Text("stats.no.people".localized)
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                let maxTotal = topPeople.map(\.total).max() ?? 1
                VStack(spacing: 14) {
                    ForEach(Array(topPeople.enumerated()), id: \.offset) { index, person in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.avatar(for: person.name))
                                    .frame(width: 38, height: 38)
                                Text(String(person.name.prefix(1)).uppercased())
                                    .font(AppTheme.Fonts.inter(14, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(person.name)
                                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                        .foregroundColor(Color.textPrimary)
                                    Spacer()
                                    Text(person.total.toCurrency())
                                        .font(AppTheme.Fonts.inter(14, weight: .bold))
                                        .foregroundColor(Color.textPrimary)
                                }
                                HStack(spacing: 8) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.appIconChip)
                                            Capsule()
                                                .fill(Color.appPrimary)
                                                .frame(width: max(6, geo.size.width * person.total / maxTotal))
                                        }
                                    }
                                    .frame(height: 6)

                                    Text("\(person.count) \(person.count == 1 ? "stats.bill".localized : "stats.bills".localized)")
                                        .font(AppTheme.Fonts.inter(11, weight: .medium))
                                        .foregroundColor(Color.textSecondary)
                                        .fixedSize()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .statsCard()
    }

    // MARK: - Biggest Bill

    @ViewBuilder
    private var biggestBillCard: some View {
        if let bill = biggestBill {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("stats.biggest.bill".localized)
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(Color.textPrimary)
                    Spacer()
                    Image(systemName: "trophy.fill")
                        .foregroundColor(Color.appAccent)
                        .font(AppTheme.Fonts.inter(16))
                }

                Button(action: { router.push(.historyDetail(bill)) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appIconChip)
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.text.fill")
                                .font(AppTheme.Fonts.inter(18))
                                .foregroundColor(Color.appPrimary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bill.title.isEmpty ? "history.untitled".localized : bill.title)
                                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                .foregroundColor(Color.textPrimary)
                                .lineLimit(1)
                            Text(bill.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(AppTheme.Fonts.inter(12, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(bill.totalAmount.toCurrency())
                            .fixedSize()
                            .font(AppTheme.Fonts.inter(15, weight: .bold))
                            .foregroundColor(Color.appBrandText)

                        Image(systemName: "chevron.right")
                            .font(AppTheme.Fonts.inter(12, weight: .semibold))
                            .foregroundColor(Color.textSecondary.opacity(0.4))
                    }
                    .padding(12)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .statsCard()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(AppTheme.Fonts.inter(52))
                .foregroundColor(Color.textSecondary.opacity(0.2))
            Text("stats.empty.title".localized)
                .font(AppTheme.Fonts.inter(18, weight: .semibold))
                .foregroundColor(Color.textSecondary)
            Text("stats.empty.sub".localized)
                .font(AppTheme.Fonts.inter(14, weight: .regular))
                .foregroundColor(Color.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Card style

private extension View {
    /// White card with hairline border; `accent` adds the champagne edge used on the hero.
    func statsCard(accent: Bool = false) -> some View {
        self
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accent ? Color.appAccent.opacity(0.5) : Color.appCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.appPrimary.opacity(0.06), radius: 10, x: 0, y: 4)
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
