//
//  HistoryDetailView.swift
//  SplitBill
//

import SwiftUI

struct HistoryDetailView: View {
    let bill: BillHistory

    @ObservedObject private var historyVM = HistoryViewModel.shared
    @State private var showShare = false
    @State private var justMarkedId: UUID? = nil

    // Always read the freshest version from the view model
    private var liveBill: BillHistory {
        historyVM.history.first(where: { $0.id == bill.id }) ?? bill
    }

    private var unpaidPeople: [HistoryPerson] {
        liveBill.people.filter { !$0.isPaid }
    }

    private var paidPeople: [HistoryPerson] {
        liveBill.people.filter { $0.isPaid }
    }

    private var allPaid: Bool { unpaidPeople.isEmpty }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summaryCard
                    if !unpaidPeople.isEmpty {
                        peopleSection(
                            title: "STILL OWES YOU",
                            people: unpaidPeople,
                            isPaidSection: false
                        )
                    }
                    if !paidPeople.isEmpty {
                        peopleSection(
                            title: "PAID ✓",
                            people: paidPeople,
                            isPaidSection: true
                        )
                    }
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Bill Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showShare = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(Color.appPrimary)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareMessage])
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(liveBill.title.isEmpty ? "Untitled Bill" : liveBill.title)
                        .roundedFont(20, weight: .bold)
                        .foregroundColor(Color.textPrimary)

                    Text(liveBill.formattedDate)
                        .roundedFont(13, weight: .regular)
                        .foregroundColor(Color.textSecondary)
                }

                Spacer()

                // All paid badge
                if allPaid {
                    Label("All Paid", systemImage: "checkmark.seal.fill")
                        .roundedFont(12, weight: .semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Divider()
                .background(Color.textSecondary.opacity(0.1))

            HStack(spacing: 0) {
                statItem(
                    label: "TOTAL",
                    value: liveBill.totalAmount.toCurrency()
                )
                Divider()
                    .frame(height: 36)
                    .background(Color.textSecondary.opacity(0.12))
                    .padding(.horizontal, 16)
                statItem(
                    label: "AVG / PERSON",
                    value: liveBill.splitAmount.toCurrency()
                )
                Divider()
                    .frame(height: 36)
                    .background(Color.textSecondary.opacity(0.12))
                    .padding(.horizontal, 16)
                statItem(
                    label: "PEOPLE",
                    value: "\(liveBill.people.count)"
                )
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .roundedFont(10, weight: .semibold)
                .foregroundColor(Color.textSecondary)
                .tracking(0.6)
            Text(value)
                .roundedFont(16, weight: .bold)
                .foregroundColor(Color.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - People Section

    @ViewBuilder
    private func peopleSection(title: String, people: [HistoryPerson], isPaidSection: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .roundedFont(11, weight: .semibold)
                .foregroundColor(isPaidSection ? .green : Color.appSecondary)
                .tracking(0.8)
                .padding(.leading, 4)

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
        let avatarColors: [Color] = [.appPrimary, .appSecondary, .purple, .teal, .indigo, .pink]
        let colorIndex = abs(person.name.hashValue) % avatarColors.count
        let avatarColor = isPaidSection ? Color.green : avatarColors[colorIndex]

        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(avatarColor.opacity(isPaidSection ? 0.12 : 0.16))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(person.name.prefix(1)).uppercased())
                        .roundedFont(17, weight: .bold)
                        .foregroundColor(avatarColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .roundedFont(15, weight: .semibold)
                    .foregroundColor(isPaidSection ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(isPaidSection, color: Color.textSecondary.opacity(0.5))

                Text(person.amount.toCurrency())
                    .roundedFont(13, weight: .medium)
                    .foregroundColor(isPaidSection ? Color.textSecondary.opacity(0.6) : Color.appPrimary)
            }

            Spacer()

            // Mark paid / unpaid button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    justMarkedId = person.id
                    historyVM.markPersonPaid(
                        billId: liveBill.id,
                        personId: person.id,
                        isPaid: !person.isPaid
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    justMarkedId = nil
                }
            }) {
                if justMarkedId == person.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isPaidSection {
                    Label("Undo", systemImage: "arrow.uturn.left")
                        .roundedFont(12, weight: .medium)
                        .foregroundColor(Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.textSecondary.opacity(0.08))
                        .clipShape(Capsule())
                } else {
                    Label("Mark Paid", systemImage: "checkmark")
                        .roundedFont(12, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isPaidSection ? 0.7 : 1.0)
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
                    Person(name: "Alvin", amount: 170000),
                    Person(name: "Budi",  amount: 85000),
                    Person(name: "Siti",  amount: 85000)
                ],
                splitAmount: 113333
            )
        )
    }
}
