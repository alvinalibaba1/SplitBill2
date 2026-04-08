//
//  MainView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: SplitBillViewModel
    @State private var showingAddPerson = false
    @State private var adjustmentPreset: AdjustmentSheetPreset?
    @State private var selectedPerson: Person?
    @State private var navigateResult = false
    @State private var isPulsing = false

    init(
        billTitle: String = "",
        totalPrefill: String = "",
        scannedItems: [(name: String, price: Double)] = [],
        scannedAdjustments: [(name: String, amount: Double)] = []
    ) {
        _viewModel = StateObject(
            wrappedValue: SplitBillViewModel(
                billTitle: billTitle,
                totalAmount: totalPrefill,
                scannedItems: scannedItems,
                scannedAdjustments: scannedAdjustments
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Scan banner — only shows when coming from scanner
                    if !viewModel.scannedItems.isEmpty {
                        scanBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }

                    // Bill name + total + equal split toggle
                    summarySection.padding(.top, 20)

                    // People — unified card: empty hint + rows + Add Person
                    sectionHeader("PEOPLE")
                    peopleSectionCard

                    // Extras — unified card: rows + Add Extra menu
                    sectionHeader("EXTRAS")
                    extrasSectionCard

                    Color.clear.frame(height: 100)
                }
            }

            // Sticky bottom bar
            calculateBar
        }
        .navigationTitle(viewModel.billTitle.isEmpty ? "New Bill" : viewModel.billTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateResult) {
            ResultView(viewModel: viewModel)
        }
        .navigationDestination(item: $selectedPerson) { person in
            PersonDetailView(person: person, viewModel: viewModel)
        }
        .sheet(item: $adjustmentPreset) { preset in
            AddAdjustmentSheet(
                isPresented: Binding(
                    get: { adjustmentPreset != nil },
                    set: { if !$0 { adjustmentPreset = nil } }
                ),
                defaultName: preset.name,
                defaultIsDiscount: preset.isDiscount,
                onAdd: { name, amount, isDiscount in
                    viewModel.addAdjustment(name: name, amount: amount, isDiscount: isDiscount)
                }
            )
        }
        // ✅ Converted from custom ZStack overlay → native sheet
        // Gives drag-to-dismiss, safe area handling, and proper iPad support
        .sheet(isPresented: $showingAddPerson) {
            AddPersonSheet(onAdd: { viewModel.addPerson(name: $0) })
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Scan Banner
    // ✅ More directional copy — tells user exactly what action to take
    private var scanBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .symbolEffect(.bounce, value: isPulsing)
                .onAppear { isPulsing.toggle() }
                .foregroundColor(Color.appSecondary)
                .font(AppTheme.Fonts.inter(16))

            Text("\(viewModel.scannedItems.count) items ready — tap a person below to assign them")
                .font(AppTheme.Fonts.inter(13, weight: .medium))
                .foregroundColor(Color.appSecondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appSecondary.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSecondary.opacity(0.2), lineWidth: 1))
        .cornerRadius(10)
    }

    // MARK: - Bill Name + Total Card
    private var summarySection: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Name this bill", text: $viewModel.billTitle)
                    .font(AppTheme.Fonts.inter(17, weight: .medium))
                    .foregroundColor(Color.textPrimary)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)

            Divider().padding(.leading, 16)

            HStack {
                Text("Total")
                    .font(AppTheme.Fonts.inter(17, weight: .regular))
                    .foregroundColor(Color.textPrimary)
                Spacer()
                Text(viewModel.totalForSplit > 0 ? viewModel.totalForSplit.toCurrency() : "—")
                    .font(AppTheme.Fonts.inter(17, weight: .semibold))
                    .foregroundColor(viewModel.totalForSplit > 0 ? Color.appPrimary : Color.textSecondary.opacity(0.4))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: viewModel.totalForSplit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)

            Divider().padding(.leading, 16)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Split Equally")
                        .font(AppTheme.Fonts.inter(17, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                    if viewModel.isEqualSplit {
                        Text("Each person pays \((viewModel.totalForSplit / Double(max(viewModel.people.count, 1))).toCurrency())")
                            .font(AppTheme.Fonts.inter(12, weight: .regular))
                            .foregroundColor(Color.appPrimary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.spring(response: 0.3), value: viewModel.isEqualSplit)
                Spacer()
                Toggle("", isOn: $viewModel.isEqualSplit)
                    .tint(Color.appPrimary)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 8)
    }

    // MARK: - People Section (unified card)
    // ✅ addPersonRow merged inside the card — one cohesive block instead of two floating cards
    // ✅ Empty hint guides first-time users instead of a blank gap
    private var peopleSectionCard: some View {
        VStack(spacing: 0) {
            if viewModel.people.isEmpty {
                // Empty hint — first-time user guidance
                HStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(AppTheme.Fonts.inter(18))
                        .foregroundColor(Color.textSecondary.opacity(0.35))
                    Text("Add people to start splitting")
                        .font(AppTheme.Fonts.inter(14, weight: .regular))
                        .foregroundColor(Color.textSecondary.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)

                Divider().padding(.leading, 16)
            } else {
                ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                    VStack(spacing: 0) {
                        personRow(person: person, index: index)
                        Divider().padding(.leading, 56)
                    }
                }
            }

            // Add Person — always last row inside the card
            Button(action: { showingAddPerson = true }) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .font(AppTheme.Fonts.inter(13, weight: .bold))
                                .foregroundColor(Color.appPrimary)
                        )
                    Text("Add Person")
                        .font(AppTheme.Fonts.inter(16, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Person Row
    private func personRow(person: Person, index: Int) -> some View {
        Button(action: { selectedPerson = person }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(avatarColor(index: index))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(person.name.prefix(1)).uppercased())
                            .font(AppTheme.Fonts.inter(14, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(person.name)
                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                    .foregroundColor(Color.textPrimary)

                Spacer()

                // ✅ Amount now uses textPrimary + bold — it's the most important number on this row
                if person.amount > 0 {
                    Text(person.amount.toCurrency())
                        .font(AppTheme.Fonts.inter(15, weight: .bold))
                        .foregroundColor(Color.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: person.amount)
                }

                Image(systemName: "chevron.right")
                    .font(AppTheme.Fonts.inter(12, weight: .semibold))
                    .foregroundColor(Color.textSecondary.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    if let idx = viewModel.people.firstIndex(where: { $0.id == person.id }) {
                        viewModel.removePerson(at: IndexSet(integer: idx))
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Extras Section (unified card)
    // ✅ addExtraRow merged inside the card — same visual consistency as people card
    private var extrasSectionCard: some View {
        VStack(spacing: 0) {
            if !viewModel.adjustments.isEmpty {
                ForEach(Array(viewModel.adjustments.enumerated()), id: \.element.id) { index, adj in
                    VStack(spacing: 0) {
                        adjustmentRow(adj)
                        Divider().padding(.leading, 56)
                    }
                }
            }

            // Add Extra menu — always last row inside the card
            Menu {
                Button { adjustmentPreset = AdjustmentSheetPreset(name: "Tax",      isDiscount: false) }
                    label: { Label("Tax",      systemImage: "percent") }
                Button { adjustmentPreset = AdjustmentSheetPreset(name: "Service",  isDiscount: false) }
                    label: { Label("Service",  systemImage: "cart") }
                Button { adjustmentPreset = AdjustmentSheetPreset(name: "Discount", isDiscount: true) }
                    label: { Label("Discount", systemImage: "tag") }
                Button { adjustmentPreset = AdjustmentSheetPreset(name: "Other",    isDiscount: false) }
                    label: { Label("Other",    systemImage: "ellipsis.circle") }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appSecondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .font(AppTheme.Fonts.inter(13, weight: .bold))
                                .foregroundColor(Color.appSecondary)
                        )
                    Text("Add Extra")
                        .font(AppTheme.Fonts.inter(16, weight: .medium))
                        .foregroundColor(Color.appSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: - Adjustment Row
    private func adjustmentRow(_ adj: Adjustment) -> some View {
        HStack(spacing: 12) {
            Text(adj.isDiscount ? "−" : "+")
                .font(AppTheme.Fonts.inter(15, weight: .bold))
                .foregroundColor(adj.isDiscount ? .red : Color.appSecondary)
                .frame(width: 36, height: 36)
                .background((adj.isDiscount ? Color.red : Color.appSecondary).opacity(0.1))
                .clipShape(Circle())

            Text(adj.name)
                .font(AppTheme.Fonts.inter(16, weight: .medium))
                .foregroundColor(Color.textPrimary)

            Spacer()

            Text((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())
                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                .foregroundColor(adj.isDiscount ? .red : Color.textPrimary)

            Button(action: { viewModel.removeAdjustment(id: adj.id) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTheme.Fonts.inter(18))
                    .foregroundColor(Color.textSecondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Sticky Bottom Bar
    private var calculateBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    // ✅ Shows avg/person when people exist — removes duplicate total info
                    // Shows plain total when no people yet (still useful context)
                    if viewModel.people.isEmpty {
                        Text("Total")
                            .font(AppTheme.Fonts.inter(12, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                        Text(viewModel.totalForSplit > 0 ? viewModel.totalForSplit.toCurrency() : "Rp 0")
                            .font(AppTheme.Fonts.inter(17, weight: .bold))
                            .foregroundColor(Color.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: viewModel.totalForSplit)
                    } else {
                        Text("Avg per person")
                            .font(AppTheme.Fonts.inter(12, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                        Text(viewModel.averageAmount.toCurrency())
                            .font(AppTheme.Fonts.inter(17, weight: .bold))
                            .foregroundColor(Color.appPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: viewModel.averageAmount)
                    }
                }

                Spacer()

                // ✅ "Split Bill" — more natural CTA than "Calculate"
                Button(action: {
                    let history = BillHistory(
                        title: viewModel.billTitle,
                        totalAmount: viewModel.totalForSplit,
                        people: viewModel.people,
                        splitAmount: viewModel.averageAmount
                    )
                    HistoryViewModel.shared.saveHistory(history)
                    navigateResult = true
                }) {
                    Text("Split Bill")
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            viewModel.hasValidSplit
                                ? Color.appPrimary
                                : Color.textSecondary.opacity(0.25)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!viewModel.hasValidSplit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appBackground)
        }
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

// MARK: - Supporting Types
struct AdjustmentSheetPreset: Identifiable {
    let id = UUID()
    let name: String
    let isDiscount: Bool
}

#Preview {
    NavigationStack {
        MainView()
    }
}
