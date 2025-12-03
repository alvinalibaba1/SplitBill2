//
//  ResultView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: SplitBillViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showCheckmark = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []

var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
        VStack(spacing: 20) {
                    // Success Animation
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 100, height: 100)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                            .opacity(showCheckmark ? 1 : 0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                            .opacity(showCheckmark ? 1 : 0)
                    }
                    .padding(.top, 10)

                    VStack(spacing: 8) {
                        Text(viewModel.billTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)

                        Text("Complete")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    summaryCard
                    peopleItemsSummary
                    adjustmentsSummary

                    AnimatedButton(
                        title: "Done",
                        action: { dismiss() }
                    )
                }
                .padding()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                showCheckmark = true
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: shareItems)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: shareAction) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.black)
                }
            }
        }
    }

    private func shareAction() {
        let title = viewModel.billTitle
        let textSummary = buildShareMessage(title: title)
        do {
            let pdfURL = try PDFExporter.generateSummaryPDF(
                title: title,
                total: viewModel.totalForSplit,
                average: viewModel.averageAmount,
                people: viewModel.people,
                items: viewModel.items,
                adjustments: viewModel.adjustments
            )
            shareItems = [textSummary, pdfURL]
        } catch {
            shareItems = [textSummary]
        }
        showShare = true
    }

    private func buildShareMessage(title: String) -> String {
        var message = "\(title)\nTotal: \(viewModel.totalForSplit.toCurrency())\n"
        message += "People:\n"
        for person in viewModel.people {
            message += "- \(person.name): \(person.amount.toCurrency())\n"
            let items = viewModel.items.filter { $0.personId == person.id }
            for item in items {
                message += "   • \(item.name): \(item.price.toCurrency())\n"
            }
        }
        if !viewModel.adjustments.isEmpty {
            message += "Extras:\n"
            for adj in viewModel.adjustments {
                let value = (adj.isDiscount ? -adj.amount : adj.amount).toCurrency()
                message += "- \(adj.name): \(value)\n"
            }
        }
        return message
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Total to collect")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                
                Text(viewModel.totalForSplit.toCurrency())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.black)
            }

        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var peopleItemsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People & items")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)

            if viewModel.people.isEmpty {
                Text("No people added")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.people) { person in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(person.name.prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)

                                    Text(person.amount.toCurrency())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Spacer()
                            }

                            let items = viewModel.items.filter { $0.personId == person.id }

                            if items.isEmpty {
                                Text("No items for this person")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(items) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.black)

                                            Spacer()

                                            Text(item.price.toCurrency())
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                        .padding()
                                        .background(Color(red: 0.984, green: 0.984, blue: 0.984))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var adjustmentsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Extras")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)

            if viewModel.adjustments.isEmpty {
                Text("No extras")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.adjustments) { adj in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(adj.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)

                                if adj.isDiscount {
                                    Text("Discount")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.red)
                                }
                            }

                            Spacer()

                            Text((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(adj.isDiscount ? .red : .black)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
