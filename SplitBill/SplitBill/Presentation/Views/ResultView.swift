//
//  ResultView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: SplitBillViewModel
    @EnvironmentObject var router: NavigationRouter

    @State private var showCheckmark = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    // ✅ Copy feedback — button label switches to "Copied!" for 2s then resets
    @State private var showCopied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    successHeader
                    totalCard
                    peopleSummary

                    // ✅ Adjustments hidden when empty — no more "No extras" noise
                    if !viewModel.adjustments.isEmpty {
                        adjustmentsSummary
                    }

                    // Space so content doesn't hide behind sticky bar
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }

            // ✅ Sticky bottom bar — Copy + Share + Done always reachable
            stickyBar
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                showCheckmark = true
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: shareItems)
        }
    }

    // MARK: - Success Header
    // ✅ "Complete" → "All settled" — more human, less task-manager
    // ✅ Outer soft ring adds depth without extra visual noise
    private var successHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer soft ring
                Circle()
                    .fill(Color.appPrimary.opacity(0.08))
                    .frame(width: 110, height: 110)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)

                // Inner filled circle
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 80, height: 80)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showCheckmark ? 1 : 0.3)
                    .opacity(showCheckmark ? 1 : 0)
            }

            VStack(spacing: 6) {
                Text(viewModel.billTitle.isEmpty ? "Bill Split" : viewModel.billTitle)
                    .font(AppTheme.Fonts.inter(22, weight: .bold))
                    .foregroundColor(Color.textPrimary)

                Text("All settled ✓")
                    .font(AppTheme.Fonts.inter(15, weight: .regular))
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Total Card
    // ✅ "Total to collect" → "TOTAL BILL" — not everyone is collecting
    // ✅ Added avg per person as secondary info — useful at a glance
    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("TOTAL BILL")
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)

            Text(viewModel.totalForSplit.toCurrency())
                .font(AppTheme.Fonts.inter(38, weight: .bold))
                .foregroundColor(Color.textPrimary)

            if !viewModel.people.isEmpty {
                Text("Avg \(viewModel.averageAmount.toCurrency()) / person")
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - People Summary
    // ✅ Amount is now the hero — bold + appPrimary color, right-aligned
    // ✅ Items shown below in small secondary text — visible but not competing
    // ✅ All people in one unified card instead of a card-per-person
    private var peopleSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SPLIT BREAKDOWN")
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                    VStack(spacing: 0) {
                        personRow(person: person, index: index)
                        if index < viewModel.people.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    private func personRow(person: Person, index: Int) -> some View {
        let personItems = viewModel.items.filter { $0.personId == person.id }

        return VStack(alignment: .leading, spacing: 0) {
            // Name + Amount row
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarColor(index: index))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(AppTheme.Fonts.inter(15, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(person.name)
                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                // ✅ Amount is the hero — bold, primary color, right side
                Text(person.amount.toCurrency())
                    .font(AppTheme.Fonts.inter(16, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            // ✅ Items shown small below — secondary, not competing with amount
            if !personItems.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(personItems) { item in
                        HStack {
                            Text("· \(item.name)\(item.quantity > 1 ? " ×\(item.quantity)" : "")")
                                .font(AppTheme.Fonts.inter(13, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text((item.price * Double(item.quantity)).toCurrency())
                                .font(AppTheme.Fonts.inter(13, weight: .medium))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.leading, 66)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Adjustments Summary
    private var adjustmentsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EXTRAS")
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.adjustments.enumerated()), id: \.element.id) { index, adj in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(adj.isDiscount ? "−" : "+")
                                .font(AppTheme.Fonts.inter(15, weight: .bold))
                                .foregroundColor(adj.isDiscount ? .red : Color.appSecondary)
                                .frame(width: 36, height: 36)
                                .background((adj.isDiscount ? Color.red : Color.appSecondary).opacity(0.1))
                                .clipShape(Circle())

                            Text(adj.name)
                                .font(AppTheme.Fonts.inter(15, weight: .medium))
                                .foregroundColor(Color.textPrimary)

                            Spacer()

                            Text((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())
                                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                .foregroundColor(adj.isDiscount ? .red : Color.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        if index < viewModel.adjustments.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Sticky Bottom Bar
    // ✅ Copy + Share + Done always visible — no scrolling to find them
    // ✅ Done now calls popToRoot() — goes back to HomeView, not MainView
    private var stickyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {

                // Copy to clipboard
                // ✅ Label flips to "Copied!" for 2s as tactile confirmation
                Button(action: copyAction) {
                    HStack(spacing: 6) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text(showCopied ? "Copied!" : "Copy")
                            .font(AppTheme.Fonts.inter(14, weight: .semibold))
                    }
                    .foregroundColor(showCopied ? Color.appSecondary : Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        showCopied
                            ? Color.appSecondary.opacity(0.1)
                            : Color.appPrimary.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut(duration: 0.2), value: showCopied)
                }

                // Share PDF + text
                Button(action: shareAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Share")
                            .font(AppTheme.Fonts.inter(14, weight: .semibold))
                    }
                    .foregroundColor(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Done — pops all the way back to HomeView
                Button(action: { router.popToRoot() }) {
                    Text("Done")
                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appBackground)
        }
    }

    // MARK: - Actions

    private func copyAction() {
        UIPasteboard.general.string = buildShareMessage(title: viewModel.billTitle)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopied = false }
        }
    }

    private func shareAction() {
        let text = buildShareMessage(title: viewModel.billTitle)
        do {
            let pdfURL = try PDFExporter.generateSummaryPDF(
                title: viewModel.billTitle,
                total: viewModel.totalForSplit,
                average: viewModel.averageAmount,
                people: viewModel.people,
                items: viewModel.items,
                adjustments: viewModel.adjustments
            )
            shareItems = [text, pdfURL]
        } catch {
            shareItems = [text]
        }
        showShare = true
    }

    private func buildShareMessage(title: String) -> String {
        var msg = "🧾 \(title.isEmpty ? "Bill Split" : title)\n"
        msg += "Total: \(viewModel.totalForSplit.toCurrency())\n"
        msg += "Avg: \(viewModel.averageAmount.toCurrency()) / person\n\n"
        for person in viewModel.people {
            msg += "\(person.name): \(person.amount.toCurrency())\n"
            let items = viewModel.items.filter { $0.personId == person.id }
            for item in items {
                msg += "  · \(item.name)\(item.quantity > 1 ? " ×\(item.quantity)" : "") — \((item.price * Double(item.quantity)).toCurrency())\n"
            }
        }
        if !viewModel.adjustments.isEmpty {
            msg += "\nExtras:\n"
            for adj in viewModel.adjustments {
                msg += "  \(adj.isDiscount ? "−" : "+") \(adj.name): \((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())\n"
            }
        }
        return msg
    }

    // MARK: - Avatar Color Cycle
    private func avatarColor(index: Int) -> Color {
        let colors: [Color] = [
            Color.appPrimary,
            Color.appSecondary,
            Color(hex: "A29BFE"),
            Color(hex: "FD79A8"),
            Color(hex: "FDCB6E"),
            Color(hex: "00B894"),
        ]
        return colors[index % colors.count]
    }
}

#Preview {
    NavigationStack {
        ResultView(viewModel: SplitBillViewModel())
            .environmentObject(NavigationRouter())
    }
}
