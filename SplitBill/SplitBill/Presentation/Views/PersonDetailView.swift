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
    @State private var showSuccess = false
    @State private var scale = 1.0

    @FocusState private var isFocused: Bool



    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                scannedItemsList
                itemInputs
                allItemsList
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appPrimary)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(AppTheme.Fonts.inter(24, weight: .bold))
                    .foregroundColor(Color.textPrimary)
            }

            Spacer()

            Circle()
                .fill(Color.appPrimary)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(person.name.prefix(1)).uppercased())
                        .font(AppTheme.Fonts.inter(18, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var scannedItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scanned items")
                .font(AppTheme.Fonts.inter(14, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .textCase(.uppercase)

            if viewModel.scannedItems.isEmpty {
                VStack(spacing: 8) {
                    Text("No scanned items found")
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(Color.textSecondary)
                    Text("Scan a bill to auto-fill items.")
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.textSecondary.opacity(0.4), lineWidth: 1.2)
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(viewModel.scannedItems.enumerated()), id: \.offset) { index, scanned in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scanned.name)
                                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                                    .foregroundColor(Color.textPrimary)
                                Text(scanned.price.toCurrency())
                                    .font(AppTheme.Fonts.inter(14, weight: .medium))
                                    .foregroundColor(Color.textSecondary)
                            }
                            Spacer()

                            Button(action: {
                                //ADD ITEM LOGIC
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    scale = 1.2
                                    assign(scannedItemAt: index)
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                                //RESET
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation {
                                        scale = 1.0
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                    Text("Add to \(person.name)")
                                        .font(AppTheme.Fonts.inter(14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                                .shadow(color: Color.appPrimary.opacity(0.2), radius: 6, x: 0, y: 3)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.gray.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
                }
            }
        }
    }

    private var itemInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add item")
                .font(AppTheme.Fonts.inter(14, weight: .semibold))
                .foregroundColor(Color.textPrimary)
                .textCase(.uppercase)

            TextField("  Item name", text: $itemName)
                .font(AppTheme.Fonts.inter(17, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1.2)
                )
                .overlay(alignment: .leading) {
                    if itemName.isEmpty {
                        Text("  Item name")
                            .font(AppTheme.Fonts.inter(17, weight: .medium))
                            .foregroundColor(Color.textSecondary.opacity(0.6))
                            .padding(.horizontal, 10)
                    }
                }
                .focused($isFocused)
                .autocorrectionDisabled(true)

            TextField("  Price", text: $priceText)
                .font(AppTheme.Fonts.inter(17, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1.2)
                )
                .overlay(alignment: .leading) {
                    if priceText.isEmpty {
                        Text("  Price")
                            .font(AppTheme.Fonts.inter(17, weight: .medium))
                            .foregroundColor(Color.textSecondary.opacity(0.6))
                            .padding(.horizontal, 10)
                    }
                }
                .onChange(of: priceText) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    let formatted = digits.formatAsCurrency()
                    if formatted != newValue {
                        priceText = formatted
                    }
                }
                .autocorrectionDisabled(true)

            AnimatedButton(
                title: "Add",
                action: {
                    let raw = priceText.filter { $0.isNumber }
                    let price = Double(raw) ?? 0
                    viewModel.addItem(name: itemName, price: price, personId: person.id, quantity: 1)
                    itemName = ""
                    priceText = ""
                    isFocused = true
                },
                isEnabled: isValid
            )
        }
    }

    private var allItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(AppTheme.Fonts.inter(14, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .textCase(.uppercase)

            if allItems.isEmpty {
                VStack(spacing: 8) {
                    Text("No items yet")
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(Color.textSecondary)
                    Text("Add expenses for \(person.name).")
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.textSecondary.opacity(0.4), lineWidth: 1.2)
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(allItems, id: \.self) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                                    .foregroundColor(Color.textPrimary)
                                Text(item.price.toCurrency())
                                    .font(AppTheme.Fonts.inter(14, weight: .medium))
                                    .foregroundColor(Color.textSecondary)
                            }
                            Spacer()

                            if item.personId == person.id {
                                // Item belongs to this person - show quantity controls
                                HStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            removeOne(item)
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.red)
                                    }

                                    Text("\(item.quantity)")
                                        .contentTransition(.numericText())
                                        .font(AppTheme.Fonts.inter(18, weight: .bold))
                                        .foregroundColor(Color.textPrimary)
                                        .frame(minWidth: 35)

                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            addOne(item)
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.appPrimary)
                                    }
                                }
                            } else {
                                // Item belongs to someone else - show add button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        viewModel.addItem(name: item.name, price: item.price, personId: person.id, quantity: 1)
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color.appPrimary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1.2)
                        )
                        .shadow(color: Color.gray.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
                }
            }
        }
    }

    private var allItems: [BillItem] {
        // Group items by name and price (ignoring personId)
        var grouped: [String: (ownedItem: BillItem?, otherItem: BillItem?)] = [:]

        for item in viewModel.items {
            let key = "\(item.name.lowercased())_\(item.price)"
            var entry = grouped[key] ?? (nil, nil)

            if item.personId == person.id {
                // This item belongs to current person
                if var owned = entry.ownedItem {
                    owned.quantity += item.quantity
                    entry.ownedItem = owned
                } else {
                    entry.ownedItem = item
                }
            } else {
                // This item belongs to someone else
                if var other = entry.otherItem {
                    other.quantity += item.quantity
                    entry.otherItem = other
                } else {
                    entry.otherItem = item
                }
            }

            grouped[key] = entry
        }

        // Return owned items first, then other items (showing only one entry per unique item)
        return grouped.values.compactMap { entry in
            // Prioritize showing owned items, otherwise show the other version
            entry.ownedItem ?? entry.otherItem
        }.sorted { $0.name < $1.name }
    }

    private func removeOne(_ item: BillItem) {
        if let idx = viewModel.items.firstIndex(where: { $0.personId == person.id && $0.name == item.name && $0.price == item.price }) {
            var target = viewModel.items[idx]
            if target.quantity > 1 {
                target.quantity -= 1
                viewModel.items[idx] = target
            } else {
                // Restore to scanned items before removing
                viewModel.restoreToScannedItems(name: item.name, price: item.price)
                viewModel.items.remove(at: idx)
            }
            viewModel.recalcTotals()
        }
    }

    private func addOne(_ item: BillItem) {
        if let idx = viewModel.items.firstIndex(where: { $0.personId == person.id && $0.name == item.name && $0.price == item.price }) {
            var target = viewModel.items[idx]
            target.quantity += 1
            viewModel.items[idx] = target
            viewModel.recalcTotals()
        }
    }

    private func assign(scannedItemAt index: Int) {
        guard index < viewModel.scannedItems.count else { return }
        let scanned = viewModel.scannedItems[index]
        viewModel.assignScannedItem(scanned, to: person.id)
    }

    private var totalForPerson: Double {
        allItems.filter { $0.personId == person.id }.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    private var isValid: Bool {
        let price = Double(priceText.filter { $0.isNumber }) ?? 0
        return !itemName.trimmingCharacters(in: .whitespaces).isEmpty && price > 0
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
