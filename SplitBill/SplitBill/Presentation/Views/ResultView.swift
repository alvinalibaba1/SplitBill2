//
//  ResultView.swift
//  SplitBill — redesigned to match Splitin prototype
//

import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: SplitBillViewModel
    @EnvironmentObject var router: NavigationRouter

    @State private var showCheckmark = false
    @State private var showShare     = false
    @State private var showCopied    = false
    @State private var shareItems: [Any] = []
    @State private var particles: [ConfettiParticle] = []

    // Stagger each person row
    @State private var rowsVisible: [Bool] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            // ── 🎉 Confetti ──────────────────────────────────────
            ConfettiView(particles: particles)

            // ── Scroll content ───────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    checkmarkHeader
                    totalCard
                    breakdownSection
                    if !viewModel.adjustments.isEmpty {
                        extrasSection
                    }
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }

            // ── Sticky bottom bar ────────────────────────────────
            stickyBar
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            particles = makeConfettiParticles()
            rowsVisible = Array(repeating: false, count: viewModel.people.count)

            // Checkmark spring
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1)) {
                showCheckmark = true
            }
            // Stagger person rows
            for i in viewModel.people.indices {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.75)
                    .delay(0.25 + Double(i) * 0.08)) {
                    if i < rowsVisible.count { rowsVisible[i] = true }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(activityItems: shareItems)
        }
    }

    // MARK: - Checkmark Header

    private var checkmarkHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer soft ring
                Circle()
                    .fill(Color.appPrimary.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .scaleEffect(showCheckmark ? 1 : 0.4)
                    .opacity(showCheckmark ? 1 : 0)

                // Inner circle
                Circle()
                    .fill(Color(hex: "34D399").opacity(0.15))
                    .frame(width: 76, height: 76)
                    .scaleEffect(showCheckmark ? 1 : 0.4)
                    .opacity(showCheckmark ? 1 : 0)
                    .overlay(
                        Circle().stroke(Color(hex: "34D399").opacity(0.35), lineWidth: 1.5)
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "34D399"))
                    .scaleEffect(showCheckmark ? 1 : 0.2)
                    .opacity(showCheckmark ? 1 : 0)
            }

            VStack(spacing: 5) {
                Text(viewModel.billTitle.isEmpty ? "Bill Split" : viewModel.billTitle)
                    .font(AppTheme.Fonts.inter(22, weight: .bold))
                    .foregroundColor(Color.textPrimary)

                Text("All settled ✓")
                    .font(AppTheme.Fonts.inter(14, weight: .regular))
                    .foregroundColor(Color.textSecondary)
            }
            .opacity(showCheckmark ? 1 : 0)
            .offset(y: showCheckmark ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: showCheckmark)
        }
        .padding(.top, 8)
    }

    // MARK: - Total Card (purple gradient)

    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("TOTAL BILL")
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .tracking(1.2)

            Text(viewModel.totalForSplit.toCurrency())
                .font(AppTheme.Fonts.inter(38, weight: .black))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.75),
                           value: viewModel.totalForSplit)

            if !viewModel.people.isEmpty {
                Text("Avg \(viewModel.averageAmount.toCurrency()) / person")
                    .font(AppTheme.Fonts.inter(13, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color(hex: "6C63F5"), Color(hex: "9189F7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: "6C63F5").opacity(0.35), radius: 20, x: 0, y: 8)
    }

    // MARK: - Split Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SPLIT BREAKDOWN")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                    VStack(spacing: 0) {
                        personRow(person: person, index: index)
                        if index < viewModel.people.count - 1 {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                    // Stagger entry animation
                    .opacity(index < rowsVisible.count && rowsVisible[index] ? 1 : 0)
                    .offset(y: index < rowsVisible.count && rowsVisible[index] ? 0 : 16)
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
        }
    }

    private func personRow(person: Person, index: Int) -> some View {
        let personItems = viewModel.items.filter { $0.personId == person.id }

        return VStack(alignment: .leading, spacing: 0) {
            // Name + amount row
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(avatarColor(index: index).opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(avatarColor(index: index).opacity(0.3), lineWidth: 1.5)
                    )
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(AppTheme.Fonts.inter(16, weight: .bold))
                            .foregroundColor(avatarColor(index: index))
                    )

                Text(person.name)
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                Text(person.amount.toCurrency())
                    .font(AppTheme.Fonts.inter(16, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Item list (secondary, smaller)
            if !personItems.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(personItems) { item in
                        HStack {
                            Text("· \(item.name)\(item.quantity > 1 ? " ×\(item.quantity)" : "")")
                                .font(AppTheme.Fonts.inter(12, weight: .regular))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text((item.price * Double(item.quantity)).toCurrency())
                                .font(AppTheme.Fonts.inter(12, weight: .medium))
                                .foregroundColor(Color.textSecondary.opacity(0.7))
                        }
                    }
                }
                .padding(.leading, 68)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Extras (adjustments)

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("EXTRAS")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.adjustments.enumerated()), id: \.element.id) { index, adj in
                    HStack(spacing: 12) {
                        // +/− badge
                        Circle()
                            .fill(adj.isDiscount
                                  ? Color(hex: "DC2626").opacity(0.12)
                                  : Color(hex: "34D399").opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(adj.isDiscount ? "−" : "+")
                                    .font(AppTheme.Fonts.inter(16, weight: .bold))
                                    .foregroundColor(adj.isDiscount
                                                     ? Color(hex: "DC2626")
                                                     : Color(hex: "34D399"))
                            )

                        Text(adj.name)
                            .font(AppTheme.Fonts.inter(15, weight: .medium))
                            .foregroundColor(Color.textPrimary)

                        Spacer()

                        Text((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())
                            .font(AppTheme.Fonts.inter(15, weight: .semibold))
                            .foregroundColor(adj.isDiscount
                                             ? Color(hex: "DC2626")
                                             : Color.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if index < viewModel.adjustments.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
        }
    }

    // MARK: - Sticky Bottom Bar

    private var stickyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {

                // Copy
                Button(action: copyAction) {
                    HStack(spacing: 6) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(AppTheme.Fonts.inter(13, weight: .semibold))
                        Text(showCopied ? "Copied!" : "Copy")
                            .font(AppTheme.Fonts.inter(14, weight: .semibold))
                    }
                    .foregroundColor(showCopied ? Color(hex: "34D399") : Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        showCopied
                        ? Color(hex: "34D399").opacity(0.1)
                        : Color.appPrimary.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut(duration: 0.2), value: showCopied)
                }

                // Share
                Button(action: shareAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AppTheme.Fonts.inter(13, weight: .semibold))
                        Text("Share")
                            .font(AppTheme.Fonts.inter(14, weight: .semibold))
                    }
                    .foregroundColor(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Done
                Button(action: { router.popToRoot() }) {
                    Text("Done")
                        .font(AppTheme.Fonts.inter(15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6C63F5"), Color(hex: "9189F7")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color(hex: "6C63F5").opacity(0.35), radius: 8, y: 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Fonts.inter(11, weight: .semibold))
            .foregroundColor(Color.textSecondary)
            .tracking(0.8)
    }

    private func avatarColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "6C63F5"), Color(hex: "9189F7"),
            Color(hex: "E84393"), Color(hex: "F59E0B"),
            Color(hex: "34D399"), Color(hex: "3B82F6"),
        ]
        return colors[index % colors.count]
    }

    private func copyAction() {
        UIPasteboard.general.string = buildShareText()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopied = false }
        }
    }

    private func shareAction() {
        let text = buildShareText()
        do {
            let pdf = try PDFExporter.generateSummaryPDF(
                title: viewModel.billTitle, total: viewModel.totalForSplit,
                average: viewModel.averageAmount, people: viewModel.people,
                items: viewModel.items, adjustments: viewModel.adjustments
            )
            shareItems = [text, pdf]
        } catch { shareItems = [text] }
        showShare = true
    }

    private func buildShareText() -> String {
        var msg = "🧾 \(viewModel.billTitle.isEmpty ? "Bill Split" : viewModel.billTitle)\n"
        msg += "Total: \(viewModel.totalForSplit.toCurrency())\n\n"
        for person in viewModel.people {
            msg += "\(person.name): \(person.amount.toCurrency())\n"
        }
        return msg
    }
}

// MARK: - Preview

#Preview {
    let vm = SplitBillViewModel()
    vm.billTitle = "Makan Bareng"
    vm.people = [
        Person(name: "Alvin",  amount: 75000),
        Person(name: "Budi",   amount: 45000),
        Person(name: "Siti",   amount: 55000),
    ]
    return NavigationStack {
        ResultView(viewModel: vm)
            .environmentObject(NavigationRouter())
    }
}
