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
    @State private var totalText = ""
    @FocusState private var focusedField: Field?

    private enum Field { case total, name }

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
                    }

                    // Hero: total amount + bill name
                    totalCard.padding(.top, 16)

                    // Equal / Custom split mode
                    splitModePicker

                    // People
                    sectionHeader("PEOPLE", count: viewModel.people.count)
                    peopleSectionCard

                    // Extras
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                // Only visible while this screen's own fields are focused (not the Add Person sheet)
                Button("Done") { focusedField = nil }
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .opacity(focusedField == nil ? 0 : 1)
                    .disabled(focusedField == nil)
            }
        }
        .onAppear {
            if !viewModel.totalAmount.isEmpty { totalText = viewModel.totalAmount.formatAsCurrency() }
        }
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
    private var scanBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .symbolEffect(.bounce, value: isPulsing)
                .onAppear { isPulsing.toggle() }
                .foregroundColor(Color.appSuccess)
                .font(AppTheme.Fonts.inter(16))

            Text("\(viewModel.scannedItems.count) items ready — tap a person below to assign them")
                .font(AppTheme.Fonts.inter(13, weight: .medium))
                .foregroundColor(Color.appBrandText)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appIconChip)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Total + Name Card
    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOTAL BILL")
                .font(AppTheme.Fonts.inter(11, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
                .padding(.bottom, 6)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Rp")
                    .font(AppTheme.Fonts.inter(26, weight: .bold))
                    .foregroundColor(Color.textSecondary)

                TextField("0", text: $totalText)
                    .font(AppTheme.Fonts.inter(40, weight: .bold))
                    .foregroundColor(Color.appBrandText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .total)
                    .minimumScaleFactor(0.5)
                    .onChange(of: totalText) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        viewModel.totalAmount = digits
                        let formatted = digits.formatAsCurrency()
                        if formatted != newValue { totalText = formatted }
                    }
            }

            assignmentHint
                .font(AppTheme.Fonts.inter(13, weight: .medium))
                .padding(.top, 4)

            Divider().padding(.vertical, 14)

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(AppTheme.Fonts.inter(13, weight: .medium))
                    .foregroundColor(Color.textSecondary.opacity(0.6))
                TextField("Name this bill (e.g. Dinner)", text: $viewModel.billTitle)
                    .font(AppTheme.Fonts.inter(16, weight: .medium))
                    .foregroundColor(Color.textPrimary)
                    .focused($focusedField, equals: .name)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
            }
        }
        .padding(18)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(focusedField == .total ? Color.appPrimary.opacity(0.5) : Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.appPrimary.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: focusedField)
    }

    /// Tells the user how much of the typed total is still unassigned (custom mode only).
    @ViewBuilder
    private var assignmentHint: some View {
        let total = viewModel.totalAmountDouble
        let assigned = viewModel.assignedTotal
        if total > 0, !viewModel.isEqualSplit, assigned > 0 {
            let left = total - assigned
            if abs(left) < 1 {
                Label("Fully assigned", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color.appSuccess)
            } else if left > 0 {
                Label("\(left.toCurrency()) left to assign", systemImage: "exclamationmark.circle.fill")
                    .foregroundColor(Color.appWarningText)
            } else {
                Label("Over by \((-left).toCurrency())", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.appDanger)
            }
        } else if total > 0, viewModel.isEqualSplit, !viewModel.people.isEmpty {
            Label("Each person pays \(viewModel.averageAmount.toCurrency())", systemImage: "equal.circle.fill")
                .foregroundColor(Color.appBrandText)
        } else {
            Text("Enter the bill total, or add items per person")
                .foregroundColor(Color.textSecondary)
        }
    }

    // MARK: - Split Mode (Equal / Custom)
    private var splitModePicker: some View {
        HStack(spacing: 4) {
            modeButton(title: "Split equally", icon: "equal.square.fill", isOn: viewModel.isEqualSplit) {
                viewModel.isEqualSplit = true
            }
            modeButton(title: "Custom amounts", icon: "slider.horizontal.3", isOn: !viewModel.isEqualSplit) {
                viewModel.isEqualSplit = false
            }
        }
        .padding(4)
        .background(Color.appCardBorder.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isEqualSplit)
    }

    private func modeButton(title: String, icon: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(AppTheme.Fonts.inter(13, weight: .semibold))
                Text(title)
                    .font(AppTheme.Fonts.inter(14, weight: .semibold))
            }
            .foregroundColor(isOn ? Color.appBrandText : Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? Color.appCard : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: Color.black.opacity(isOn ? 0.10 : 0), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, count: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
            if let count, count > 0 {
                Text("\(count)")
                    .font(AppTheme.Fonts.inter(11, weight: .bold))
                    .foregroundColor(Color.appBrandText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.appIconChip)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 8)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
            .shadow(color: Color.appPrimary.opacity(0.05), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 16)
    }

    // MARK: - People Section
    private var peopleSectionCard: some View {
        card {
            VStack(spacing: 0) {
                if viewModel.people.isEmpty {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.appIconChip).frame(width: 52, height: 52)
                            Image(systemName: "person.2.fill")
                                .font(AppTheme.Fonts.inter(20))
                                .foregroundColor(Color.appPrimary)
                        }
                        Text("Who's splitting?")
                            .font(AppTheme.Fonts.inter(15, weight: .semibold))
                            .foregroundColor(Color.textPrimary)
                        Text("Add the people sharing this bill")
                            .font(AppTheme.Fonts.inter(13, weight: .regular))
                            .foregroundColor(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                    Divider().padding(.leading, 16)
                } else {
                    ForEach(Array(viewModel.people.enumerated()), id: \.element.id) { index, person in
                        VStack(spacing: 0) {
                            personRow(person: person, index: index)
                            Divider().padding(.leading, 64)
                        }
                    }
                }

                Button(action: { showingAddPerson = true }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.appIconChip)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(AppTheme.Fonts.inter(13, weight: .bold))
                                    .foregroundColor(Color.appPrimary)
                            )
                        Text("Add Person")
                            .font(AppTheme.Fonts.inter(16, weight: .semibold))
                            .foregroundColor(Color.appBrandText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Person Row
    private func personRow(person: Person, index: Int) -> some View {
        Button(action: { selectedPerson = person }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.avatar(for: person.name))
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

                if person.amount > 0 {
                    Text(person.amount.toCurrency())
                        .font(AppTheme.Fonts.inter(15, weight: .bold))
                        .foregroundColor(Color.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: person.amount)
                } else if !viewModel.isEqualSplit {
                    Text("Add items")
                        .font(AppTheme.Fonts.inter(13, weight: .medium))
                        .foregroundColor(Color.textSecondary)
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

    // MARK: - Extras Section (quick-add chips)
    private var extrasSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.adjustments.isEmpty {
                card {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.adjustments.enumerated()), id: \.element.id) { index, adj in
                            adjustmentRow(adj)
                            if index < viewModel.adjustments.count - 1 {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    extraChip("Tax", icon: "percent", isDiscount: false)
                    extraChip("Service", icon: "bell.fill", isDiscount: false)
                    extraChip("Discount", icon: "tag.fill", isDiscount: true)
                    extraChip("Other", icon: "ellipsis", isDiscount: false)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func extraChip(_ name: String, icon: String, isDiscount: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            adjustmentPreset = AdjustmentSheetPreset(name: name, isDiscount: isDiscount)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(AppTheme.Fonts.inter(11, weight: .bold))
                Text(name)
                    .font(AppTheme.Fonts.inter(14, weight: .semibold))
            }
            .foregroundColor(isDiscount ? Color.appSuccess : Color.appBrandText)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.appCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.appCardBorder, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
    }

    // MARK: - Adjustment Row
    private func adjustmentRow(_ adj: Adjustment) -> some View {
        HStack(spacing: 12) {
            Text(adj.isDiscount ? "−" : "+")
                .font(AppTheme.Fonts.inter(15, weight: .bold))
                .foregroundColor(adj.isDiscount ? Color.appSuccess : Color.appBrandText)
                .frame(width: 36, height: 36)
                .background(adj.isDiscount ? Color.appSuccess.opacity(0.12) : Color.appIconChip)
                .clipShape(Circle())

            Text(adj.name)
                .font(AppTheme.Fonts.inter(16, weight: .medium))
                .foregroundColor(Color.textPrimary)

            Spacer()

            Text((adj.isDiscount ? -adj.amount : adj.amount).toCurrency())
                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                .foregroundColor(adj.isDiscount ? Color.appSuccess : Color.textPrimary)

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
                            .foregroundColor(Color.appBrandText)
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
                                ? AnyShapeStyle(LinearGradient(colors: [Color.appPrimary, Color(hex: "14305A")],
                                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.textSecondary.opacity(0.25))
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
