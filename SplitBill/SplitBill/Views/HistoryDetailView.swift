//
//  HistoryDetailView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct HistoryDetailView: View {
    let bill: BillHistory

    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    peopleList
                }
                .padding()
            }
        }
        .navigationTitle("Bill Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showShare = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: [shareMessage])
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(bill.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)

            Text(bill.formattedDate)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            Text(bill.totalAmount.toCurrency())
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)

            Text("\(bill.people.count) people")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var peopleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)

            LazyVStack(spacing: 10) {
                ForEach(bill.people) { person in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(person.name.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }

                        Spacer()

                        Text(person.amount.toCurrency())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareMessage: String {
        var message = "\(bill.title)\nTotal: \(bill.totalAmount.toCurrency())\n"
        message += "People:\n"
        for person in bill.people {
            message += "- \(person.name): \(person.amount.toCurrency())\n"
        }
        message += "Avg: \(bill.splitAmount.toCurrency())"
        return message
    }
}

#Preview {
    HistoryDetailView(
        bill: BillHistory(
            totalAmount: 120000,
            people: [Person(name: "Alex", amount: 60000), Person(name: "Sam", amount: 60000)],
            splitAmount: 60000
        )
    )
}
