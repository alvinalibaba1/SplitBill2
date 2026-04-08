//
//  PersonDetailView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct PersonDetailView: View {
    let person: Person
    @ObservedObject var viewModel: SplitBillViewModel

    @State private var itemName = ""
    @State private var priceText = ""
    @FocusState private var focusedField: Field?

    enum Field { case name, price }

    // This person's items only
    private var myItems: [BillItem] {
        viewModel.items.filter { $0.personId == person.id }
    }

    // Option A — items other people have that this person doesn't yet
    // Deduplicated by name+price so the same item from multiple people only shows once
    private var alsoInThisBill: [(name: String, price: Double)] {
        let myKeys = Set(myItems.map { "\($0.name.lowercased())_\($0.price)" })
        var seen = Set<String>()
        var result: [(name: String, price: Double)] = []

        for item in viewModel.items where item.personId != person.id {
            let key = "\(item.name.lowercased())_\(item.price)"
            if !seen.contains(key) && !myKeys.contains(key) {
                seen.insert(key)
                result.append((name: item.name, price: item.price))
            }
        }
        return result
    }

    private var isValid: Bool {
        let price = Double(priceText.filter { $0.isNumber }) ?? 0
        return !itemName.trimmingCharacters(in: .whitespaces).isEmpty && price > 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                summaryCard

                if !viewModel.scannedItems.isEmpty {
                    scannedItemsSection
                }

                assignedItemsSection

                // Option A — only visible when other people have items this person doesn't
                if !alsoInThisBill.isEmpty {
                    alsoInThisBillSection
                }

                addItemSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appPrimary)
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.appPrimary.opacity(0.12))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(AppTheme.Fonts.inter(22, weight: .bold))
                        .foregroundColor(Color.appPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(AppTheme.Fonts.inter(18, weight: .bold))
                    .foregroundColor(Color.textPrimary)

                Text(person.amount > 0 ? person.amount.toCurrency() : "No items yet")
                    .font(AppTheme.Fonts.inter(15, weight: .semibold))
                    .foregroundColor(person.amount > 0 ? Color.appPrimary : Color.textSecondary.opacity(0.5))
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: person.amount)
            }

            Spacer()

            if !myItems.isEmpty {
                VStack(spacing: 2) {
                    Text("\(myItems.count)")
                        .font(AppTheme.Fonts.inter(20, weight: .bold))
                        .foregroundColor(Color.appPrimary)
                    Text(myItems.count == 1 ? "item" : "items")
                        .font(AppTheme.Fonts.inter(11, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Scanned Items Section
    private var scannedItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("UNASSIGNED ITEMS")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.scannedItems.enumerated()), id: \.offset) { index, scanned in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(scanned.name)
                                    .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                    .foregroundColor(Color.textPrimary)
                                Text(scanned.price.toCurrency())
                                    .font(AppTheme.Fonts.inter(13, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                            }
                            Spacer()
                            Button(action: { assign(scannedItemAt: index) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(AppTheme.Fonts.inter(14))
                                    Text("Assign")
                                        .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        if index < viewModel.scannedItems.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Assigned Items Section
    private var assignedItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ASSIGNED TO \(person.name.uppercased())")

            if myItems.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(AppTheme.Fonts.inter(18))
                        .foregroundColor(Color.textSecondary.opacity(0.35))
                    Text("No items assigned yet")
                        .font(AppTheme.Fonts.inter(14, weight: .regular))
                        .foregroundColor(Color.textSecondary.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(myItems.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(AppTheme.Fonts.inter(15, weight: .semibold))
                                        .foregroundColor(Color.textPrimary)
                                    Text((item.price * Double(item.quantity)).toCurrency())
                                        .font(AppTheme.Fonts.inter(13, weight: .regular))
                                        .foregroundColor(Color.textSecondary)
                                }
                                Spacer()
                                HStack(spacing: 10) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) { removeOne(item) }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(AppTheme.Fonts.inter(20))
                                            .foregroundColor(.red.opacity(0.8))
                                    }

                                    Text("\(item.quantity)")
                                        .font(AppTheme.Fonts.inter(16, weight: .bold))
                                        .foregroundColor(Color.textPrimary)
                                        .frame(minWidth: 24)
                                        .contentTransition(.numericText())

                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) { addOne(item) }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(AppTheme.Fonts.inter(20))
                                            .foregroundColor(Color.appPrimary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)

                            if index < myItems.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    // MARK: - Option A: Also in This Bill
    // Shows items already added to OTHER people that this person doesn't have yet.
    // One tap assigns instantly — no typing needed for shared items.
    // Disappears automatically once this person has all the items.
    private var alsoInThisBillSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("ALSO IN THIS BILL")
                Spacer()
                // Subtle hint so user understands what this section is for
                Text("Tap to add")
                    .font(AppTheme.Fonts.inter(11, weight: .medium))
                    .foregroundColor(Color.textSecondary.opacity(0.5))
            }

            VStack(spacing: 0) {
                ForEach(Array(alsoInThisBill.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(AppTheme.Fonts.inter(15, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                                Text(item.price.toCurrency())
                                    .font(AppTheme.Fonts.inter(13, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            // Outlined pill style — visually distinct from "Assign" (filled)
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    viewModel.addItem(
                                        name: item.name,
                                        price: item.price,
                                        personId: person.id,
                                        quantity: 1
                                    )
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(AppTheme.Fonts.inter(14))
                                    Text("Add")
                                        .font(AppTheme.Fonts.inter(13, weight: .semibold))
                                }
                                .foregroundColor(Color.appPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.appPrimary.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.appPrimary.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        if index < alsoInThisBill.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Add Item Section
    private var addItemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ADD ITEM")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "tag")
                        .font(AppTheme.Fonts.inter(15))
                        .foregroundColor(focusedField == .name ? Color.appPrimary : Color.textSecondary.opacity(0.5))
                        .animation(.easeInOut(duration: 0.15), value: focusedField)
                        .frame(width: 20)

                    TextField("Item name", text: $itemName)
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .autocorrectionDisabled(true)
                        .onSubmit { focusedField = .price }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                HStack(spacing: 12) {
                    Image(systemName: "banknote")
                        .font(AppTheme.Fonts.inter(15))
                        .foregroundColor(focusedField == .price ? Color.appPrimary : Color.textSecondary.opacity(0.5))
                        .animation(.easeInOut(duration: 0.15), value: focusedField)
                        .frame(width: 20)

                    TextField("Price", text: $priceText)
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .price)
                        .submitLabel(.done)
                        .onChange(of: priceText) { _, newValue in
                            let digits = newValue.filter { $0.isNumber }
                            let formatted = digits.formatAsCurrency()
                            if formatted != newValue { priceText = formatted }
                        }
                        .onSubmit { if isValid { addItem() } }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField != nil ? Color.appPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField)

            Button(action: addItem) {
                Text("Add Item")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValid ? Color.appPrimary : Color.textSecondary.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.Fonts.inter(12, weight: .semibold))
            .foregroundColor(Color.textSecondary)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func addItem() {
        let price = Double(priceText.filter { $0.isNumber }) ?? 0
        let name = itemName.trimmingCharacters(in: .whitespaces)
        viewModel.addItem(name: name, price: price, personId: person.id, quantity: 1)
        itemName = ""
        priceText = ""
        focusedField = .name
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func assign(scannedItemAt index: Int) {
        guard index < viewModel.scannedItems.count else { return }
        viewModel.assignScannedItem(viewModel.scannedItems[index], to: person.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func removeOne(_ item: BillItem) {
        if let idx = viewModel.items.firstIndex(where: {
            $0.personId == person.id && $0.name == item.name && $0.price == item.price
        }) {
            if viewModel.items[idx].quantity > 1 {
                viewModel.items[idx].quantity -= 1
            } else {
                viewModel.restoreToScannedItems(name: item.name, price: item.price)
                viewModel.items.remove(at: idx)
            }
            viewModel.recalcTotals()
        }
    }

    private func addOne(_ item: BillItem) {
        if let idx = viewModel.items.firstIndex(where: {
            $0.personId == person.id && $0.name == item.name && $0.price == item.price
        }) {
            viewModel.items[idx].quantity += 1
            viewModel.recalcTotals()
        }
    }
}


#Preview {
    NavigationStack {
        PersonDetailView(
            person: Person(name: "Alex"),
            viewModel: SplitBillViewModel()
        )
    }
}
