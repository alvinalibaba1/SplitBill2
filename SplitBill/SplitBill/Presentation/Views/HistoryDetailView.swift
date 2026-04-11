//
//  HistoryDetailView.swift
//  SplitBill
//

import SwiftUI

struct HistoryDetailView: View {
    let bill: BillHistory

    @ObservedObject private var historyVM = HistoryViewModel.shared
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @State private var showShare = false
    @State private var justMarkedId: UUID? = nil

    private var liveBill: BillHistory {
        historyVM.history.first(where: { $0.id == bill.id }) ?? bill
    }

    private var unpaidPeople: [HistoryPerson] { liveBill.people.filter { !$0.isPaid } }
    private var paidPeople: [HistoryPerson]   { liveBill.people.filter {  $0.isPaid } }
    private var allPaid: Bool { unpaidPeople.isEmpty }

    private var unpaidTotal: Double {
        unpaidPeople.reduce(0) { $0 + $1.amount }
    }
    private var paidTotal: Double {
        paidPeople.reduce(0) { $0 + $1.amount }
    }
    private var progress: Double {
        guard liveBill.totalAmount > 0 else { return 0 }
        return paidTotal / liveBill.totalAmount
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroCard
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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showShare = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(AppTheme.Fonts.inter(16, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareMessage])
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title + date row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(liveBill.title.isEmpty ? "history.untitled".localized : liveBill.title)
                        .roundedFont(22, weight: .bold)
                        .foregroundColor(Color.textPrimary)

                    Text(liveBill.formattedDate)
                        .roundedFont(13, weight: .regular)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                if allPaid {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppTheme.Fonts.inter(16))
                            .foregroundColor(.green)
                        Text("detail.settled".localized)
                            .roundedFont(13, weight: .semibold)
                            .foregroundColor(Color.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(Color.textSecondary.opacity(0.1))
                .padding(.horizontal, 20)

            // Stats row
            HStack(spacing: 0) {
                statCell(
                    label: "detail.total.bill".localized,
                    value: liveBill.totalAmount.toCurrency(),
                    valueColor: Color.textPrimary
                )

                Rectangle()
                    .fill(Color.textSecondary.opacity(0.1))
                    .frame(width: 1, height: 40)

                statCell(
                    label: "detail.still.owed".localized,
                    value: allPaid ? "—" : unpaidTotal.toCurrency(),
                    valueColor: allPaid ? Color.textSecondary : Color.appPrimary
                )

                Rectangle()
                    .fill(Color.textSecondary.opacity(0.1))
                    .frame(width: 1, height: 40)

                statCell(
                    label: "detail.people".localized,
                    value: "\(liveBill.people.count)",
                    valueColor: Color.textPrimary
                )
            }
            .padding(.vertical, 16)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 4)
    }

    private func statCell(label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .roundedFont(10, weight: .semibold)
                .foregroundColor(Color.textSecondary)
                .tracking(0.5)
            Text(value)
                .roundedFont(15, weight: .bold)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("detail.progress".localized)
                    .roundedFont(14, weight: .semibold)
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .roundedFont(14, weight: .bold)
                    .foregroundColor(Color.appPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.textSecondary.opacity(0.1))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            progress >= 1
                            ? LinearGradient(colors: [Color.appPrimary, Color.appPrimary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.appPrimary, Color.appPrimary.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                }
            }
            .frame(height: 10)

            // Paid vs remaining
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTheme.Fonts.inter(11))
                        .foregroundColor(.green)
                    Text("\("detail.paid.label".localized) \(paidTotal.toCurrency())")
                        .roundedFont(12, weight: .medium)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                if !allPaid {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text("\("detail.remaining".localized) \(unpaidTotal.toCurrency())")
                            .roundedFont(12, weight: .medium)
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    // MARK: - People Section

    @ViewBuilder
    private func peopleSection(title: String, people: [HistoryPerson], isPaidSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .roundedFont(11, weight: .semibold)
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.appPrimary)
                    .tracking(0.8)

                Spacer()

                Text(isPaidSection
                     ? paidTotal.toCurrency()
                     : unpaidTotal.toCurrency())
                    .roundedFont(12, weight: .semibold)
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.appPrimary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(people) { person in
                    personRow(person, isPaidSection: isPaidSection)

                    if person.id != people.last?.id {
                        Divider()
                            .background(Color.textSecondary.opacity(0.08))
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }

    @ViewBuilder
    private func personRow(_ person: HistoryPerson, isPaidSection: Bool) -> some View {
        let avatarColors: [Color] = [.appPrimary, Color(hex: "A29BFE"), Color(hex: "FD79A8"), .teal, .indigo, Color(hex: "FDCB6E")]
        let colorIndex = abs(person.name.hashValue) % avatarColors.count
        let avatarColor: Color = isPaidSection ? Color.textSecondary : avatarColors[colorIndex]

        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(isPaidSection ? 0.08 : 0.14))
                    .frame(width: 46, height: 46)

                if isPaidSection {
                    Image(systemName: "checkmark")
                        .font(AppTheme.Fonts.inter(15, weight: .bold))
                        .foregroundColor(.green)
                } else {
                    Text(String(person.name.prefix(1)).uppercased())
                        .roundedFont(18, weight: .bold)
                        .foregroundColor(avatarColor)
                }
            }

            // Name + amount
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .roundedFont(15, weight: .semibold)
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(isPaidSection, color: Color.textSecondary.opacity(0.4))

                Text(person.amount.toCurrency())
                    .roundedFont(13, weight: .medium)
                    .foregroundColor(isPaidSection ? Color.textSecondary.opacity(0.6) : Color.appPrimary)
            }

            Spacer()

            // Action button
            markPaidButton(person: person, isPaidSection: isPaidSection)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isPaidSection ? 0.75 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPaidSection)
    }

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
                // Flash confirm state
                Image(systemName: isPaidSection ? "arrow.uturn.left.circle.fill" : "checkmark.circle.fill")
                    .font(AppTheme.Fonts.inter(24))
                    .foregroundColor(isPaidSection ? Color.appPrimary : .green)
                    .transition(.scale.combined(with: .opacity))
            } else if isPaidSection {
                // Undo button
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.left")
                        .font(AppTheme.Fonts.inter(11, weight: .medium))
                    Text("detail.undo".localized)
                        .roundedFont(12, weight: .medium)
                }
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.textSecondary.opacity(0.1))
                .clipShape(Capsule())
            } else {
                // Mark paid button
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(AppTheme.Fonts.inter(11, weight: .bold))
                    Text("detail.mark.paid".localized)
                        .roundedFont(12, weight: .semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: Color.green.opacity(0.3), radius: 6, y: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Share

    private var shareMessage: String {
        var msg = "🧾 \(liveBill.title)\n"
        msg += "Total: \(liveBill.totalAmount.toCurrency())\n\n"
        for p in liveBill.people {
            let status = p.isPaid ? "✓ paid" : "owes"
            msg += "· \(p.name) \(status) \(p.amount.toCurrency())\n"
        }
        return msg
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            bill: BillHistory(
                totalAmount: 340000,
                people: [
                    Person(name: "Alvin",  amount: 170000),
                    Person(name: "Budi",   amount: 85000),
                    Person(name: "Siti",   amount: 85000)
                ],
                splitAmount: 113333
            )
        )
    }
}
