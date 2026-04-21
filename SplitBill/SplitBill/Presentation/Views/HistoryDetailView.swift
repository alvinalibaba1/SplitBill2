//
//  HistoryDetailView.swift
//  SplitBill — redesigned to match ResultView style
//

import SwiftUI

struct HistoryDetailView: View {
    let bill: BillHistory

    @ObservedObject private var historyVM = HistoryViewModel.shared
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @State private var showShare   = false
    @State private var shareItems: [Any] = []
    @State private var justMarkedId: UUID? = nil
    @State private var appeared    = false

    private var bankAccounts: [BankAccount] { BankAccountStore.load() }

    private var liveBill: BillHistory {
        historyVM.history.first(where: { $0.id == bill.id }) ?? bill
    }

    private var unpaidPeople: [HistoryPerson] { liveBill.people.filter { !$0.isPaid } }
    private var paidPeople:   [HistoryPerson] { liveBill.people.filter {  $0.isPaid } }
    private var allPaid: Bool { unpaidPeople.isEmpty }

    private var unpaidTotal: Double { unpaidPeople.reduce(0) { $0 + $1.amount } }
    private var paidTotal:   Double { paidPeople.reduce(0)   { $0 + $1.amount } }
    private var progress: Double {
        guard liveBill.totalAmount > 0 else { return 0 }
        return paidTotal / liveBill.totalAmount
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    totalCard
                    progressCard
                    if !unpaidPeople.isEmpty {
                        peopleSection(
                            title: "detail.still.owes".localized,
                            people: unpaidPeople,
                            isPaidSection: false
                        )
                    }
                    if !paidPeople.isEmpty {
                        peopleSection(
                            title: "detail.already.paid".localized,
                            people: paidPeople,
                            isPaidSection: true
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                    appeared = true
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { prepareAndShare() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(AppTheme.Fonts.inter(16, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: shareItems)
        }
    }

    // MARK: - Total Card (matches ResultView style)

    private var totalCard: some View {
        VStack(spacing: 0) {
            // Purple gradient header
            VStack(spacing: 8) {
                // Title + settled badge
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(liveBill.title.isEmpty ? "history.untitled".localized : liveBill.title)
                            .font(AppTheme.Fonts.inter(20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(liveBill.formattedDate)
                            .font(AppTheme.Fonts.inter(12, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    Spacer()

                    if allPaid {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTheme.Fonts.inter(13))
                            Text("detail.settled".localized)
                                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "34D399"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "34D399").opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "34D399").opacity(0.35), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Big total amount
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(liveBill.totalAmount.toCurrency())
                        .font(AppTheme.Fonts.inter(36, weight: .black))
                        .foregroundColor(.white)

                    Spacer()
                }

                // Subline
                Text("\(liveBill.people.count) \("detail.people".localized)  ·  Avg \((liveBill.totalAmount / Double(max(liveBill.people.count, 1))).toCurrency())")
                    .font(AppTheme.Fonts.inter(12, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 22)
            .background(
                LinearGradient(
                    colors: [Color(hex: "6C63F5"), Color(hex: "9189F7")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Stats strip
            HStack(spacing: 0) {
                statCell(
                    icon: "hourglass",
                    label: "detail.still.owed".localized,
                    value: allPaid ? "—" : unpaidTotal.toCurrency(),
                    valueColor: allPaid ? Color.textSecondary : Color.appPrimary
                )

                Divider().frame(height: 36)

                statCell(
                    icon: "checkmark.circle",
                    label: "detail.paid.label".localized,
                    value: paidTotal > 0 ? paidTotal.toCurrency() : "—",
                    valueColor: paidTotal > 0 ? Color(hex: "34D399") : Color.textSecondary
                )

                Divider().frame(height: 36)

                statCell(
                    icon: "person.2",
                    label: "detail.people".localized,
                    value: "\(liveBill.people.count)",
                    valueColor: Color.textPrimary
                )
            }
            .padding(.vertical, 14)
            .background(Color.appCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "6C63F5").opacity(0.3), radius: 20, x: 0, y: 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func statCell(icon: String, label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(AppTheme.Fonts.inter(10, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.4)
            Text(value)
                .font(AppTheme.Fonts.inter(14, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("detail.progress".localized)
                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(AppTheme.Fonts.inter(13, weight: .bold))
                    .foregroundColor(allPaid ? Color(hex: "34D399") : Color.appPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.textSecondary.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: allPaid
                                    ? [Color(hex: "34D399"), Color(hex: "34D399").opacity(0.7)]
                                    : [Color(hex: "6C63F5"), Color(hex: "9189F7")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: appeared ? geo.size.width * CGFloat(min(progress, 1.0)) : 0, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2), value: appeared)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "34D399"))
                        .frame(width: 7, height: 7)
                    Text("\("detail.paid.label".localized) \(paidTotal.toCurrency())")
                        .font(AppTheme.Fonts.inter(12, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                if !allPaid {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text("\("detail.remaining".localized) \(unpaidTotal.toCurrency())")
                            .font(AppTheme.Fonts.inter(12, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
    }

    // MARK: - People Section

    @ViewBuilder
    private func peopleSection(title: String, people: [HistoryPerson], isPaidSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section label (matches ResultView style)
            HStack {
                Text(title)
                    .font(AppTheme.Fonts.inter(11, weight: .semibold))
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.appPrimary)
                    .tracking(0.8)

                Spacer()

                Text(isPaidSection ? paidTotal.toCurrency() : unpaidTotal.toCurrency())
                    .font(AppTheme.Fonts.inter(12, weight: .semibold))
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.appPrimary)
            }

            VStack(spacing: 0) {
                ForEach(Array(people.enumerated()), id: \.element.id) { i, person in
                    personRow(person, index: i, isPaidSection: isPaidSection)

                    if person.id != people.last?.id {
                        Divider()
                            .padding(.leading, 70)
                    }
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func personRow(_ person: HistoryPerson, index: Int, isPaidSection: Bool) -> some View {
        let color = avatarColor(name: person.name, isPaid: isPaidSection)

        HStack(spacing: 14) {
            // Avatar — matches ResultView style
            Circle()
                .fill(color.opacity(isPaidSection ? 0.08 : 0.18))
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(color.opacity(isPaidSection ? 0.15 : 0.3), lineWidth: 1.5))
                .overlay(
                    Group {
                        if isPaidSection {
                            Image(systemName: "checkmark")
                                .font(AppTheme.Fonts.inter(14, weight: .bold))
                                .foregroundColor(Color(hex: "34D399"))
                        } else {
                            Text(String(person.name.prefix(1)).uppercased())
                                .font(AppTheme.Fonts.inter(16, weight: .bold))
                                .foregroundColor(color)
                        }
                    }
                )

            // Name + amount
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .font(AppTheme.Fonts.inter(15, weight: .semibold))
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(isPaidSection, color: Color.textSecondary.opacity(0.4))

                Text(person.amount.toCurrency())
                    .font(AppTheme.Fonts.inter(13, weight: .medium))
                    .foregroundColor(isPaidSection
                                     ? Color.textSecondary.opacity(0.6)
                                     : Color.appPrimary)
            }

            Spacer()

            markPaidButton(person: person, isPaidSection: isPaidSection)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isPaidSection ? 0.7 : 1.0)
    }

    // MARK: - Mark Paid Button

    @ViewBuilder
    private func markPaidButton(person: HistoryPerson, isPaidSection: Bool) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                justMarkedId = person.id
                historyVM.markPersonPaid(
                    billId: liveBill.id,
                    personId: person.id,
                    isPaid: !person.isPaid
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { justMarkedId = nil }
            }
        }) {
            if justMarkedId == person.id {
                Image(systemName: isPaidSection ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill")
                    .font(AppTheme.Fonts.inter(26))
                    .foregroundColor(isPaidSection ? Color.appPrimary : Color(hex: "34D399"))
                    .transition(.scale.combined(with: .opacity))
            } else if isPaidSection {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.left")
                        .font(AppTheme.Fonts.inter(10, weight: .medium))
                    Text("detail.undo".localized)
                        .font(AppTheme.Fonts.inter(12, weight: .medium))
                }
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.textSecondary.opacity(0.1))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(AppTheme.Fonts.inter(11, weight: .bold))
                    Text("detail.mark.paid".localized)
                        .font(AppTheme.Fonts.inter(12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "34D399"), Color(hex: "10B981")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "34D399").opacity(0.35), radius: 6, y: 2)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.93))
    }

    // MARK: - Helpers

    private func avatarColor(name: String, isPaid: Bool) -> Color {
        if isPaid { return Color.textSecondary }
        let colors: [Color] = [
            Color(hex: "6C63F5"), Color(hex: "9189F7"),
            Color(hex: "E84393"), Color(hex: "F59E0B"),
            Color(hex: "34D399"), Color(hex: "3B82F6"),
        ]
        return colors[abs(name.hashValue) % colors.count]
    }

    // MARK: - Share

    private var shareMessage: String {
        var msg = "🧾 \(liveBill.title.isEmpty ? "Bill" : liveBill.title)\n"
        msg += "📅 \(liveBill.formattedDate)\n"
        msg += "💰 Total: \(liveBill.totalAmount.toCurrency())\n\n"
        if !unpaidPeople.isEmpty {
            msg += "⏳ Still owes:\n"
            for p in unpaidPeople { msg += "  · \(p.name)  →  \(p.amount.toCurrency())\n" }
            msg += "\n"
        }
        if !paidPeople.isEmpty {
            msg += "✅ Already paid:\n"
            for p in paidPeople { msg += "  · \(p.name)  →  \(p.amount.toCurrency())\n" }
            msg += "\n"
        }
        if !bankAccounts.isEmpty {
            msg += "💳 Transfer to:\n"
            for bank in bankAccounts {
                let masked = bank.accountNumber.count > 4
                    ? "•••• \(bank.accountNumber.suffix(4))"
                    : bank.accountNumber
                msg += "  \(bank.bankName)  ·  \(masked)  ·  \(bank.accountName)\n"
            }
        }
        return msg
    }

    private func prepareAndShare() {
        var items: [Any] = [shareMessage]
        if let pdfURL = try? PDFExporter.generateFromHistory(bill: liveBill, banks: bankAccounts) {
            items.insert(pdfURL, at: 0)
        }
        shareItems = items
        showShare  = true
    }
}

// MARK: - Preview

#Preview("Unpaid") {
    NavigationStack {
        HistoryDetailView(
            bill: BillHistory(
                title: "Makan Siang Bareng",
                totalAmount: 340000,
                people: [
                    Person(name: "Alvin",  amount: 120000),
                    Person(name: "Budi",   amount: 115000),
                    Person(name: "Siti",   amount: 105000)
                ],
                splitAmount: 113333
            )
        )
    }
}

#Preview("All Settled") {
    let bill = BillHistory(
        title: "Kopi Darat",
        totalAmount: 180000,
        people: [
            Person(name: "Dian", amount: 90000),
            Person(name: "Rani", amount: 90000)
        ],
        splitAmount: 90000
    )
    return NavigationStack {
        HistoryDetailView(bill: bill)
    }
}
