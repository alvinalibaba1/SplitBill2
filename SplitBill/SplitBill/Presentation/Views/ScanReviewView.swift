//
//  ScanReviewView.swift
//  SplitBill
//

import SwiftUI

struct ScanReviewView: View {

    @EnvironmentObject var router: NavigationRouter

    let scannedData: ScannedBillData

    @State private var items: [(name: String, price: Double)]
    @State private var adjustments: [(name: String, amount: Double)]
    @State private var showAddItem = false
    @State private var editingItem: (index: Int, name: String, price: Double)? = nil

    init(scannedData: ScannedBillData) {
        self.scannedData = scannedData
        _items = State(initialValue: scannedData.items)
        _adjustments = State(initialValue: scannedData.adjustments)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - AI / OCR Banner
                    HStack(spacing: 10) {
                        Image(systemName: scannedData.parsedByAI ? "sparkles" : "doc.text.viewfinder")
                            .foregroundColor(scannedData.parsedByAI ? Color.appPrimary : Color.appSecondary)
                            .font(AppTheme.Fonts.inter(15))
                        Text(scannedData.parsedByAI
                             ? "Parsed by Gemini AI — tap to edit, swipe to delete."
                             : "Scanned locally — tap to edit, swipe to delete.")
                            .font(AppTheme.Fonts.inter(13, weight: .medium))
                            .foregroundColor(scannedData.parsedByAI ? Color.appPrimary : Color.appSecondary)
                        Spacer()
                        if scannedData.parsedByAI {
                            Text("AI")
                                .font(AppTheme.Fonts.inter(10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(scannedData.parsedByAI
                                ? Color.appPrimary.opacity(0.07)
                                : Color.appSecondary.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                        scannedData.parsedByAI ? Color.appPrimary.opacity(0.25) : Color.appSecondary.opacity(0.2),
                        lineWidth: 1))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // MARK: - Items
                    sectionHeader("ITEMS (\(items.count))")

                    if !items.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                VStack(spacing: 0) {
                                    itemRow(item: item, index: index)
                                    Divider().padding(.leading, 16)
                                }
                            }
                            addItemRow
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 0) {
                            emptyItemsState
                            Divider()
                            addItemRow
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    }

                    // MARK: - Adjustments
                    if !adjustments.isEmpty {
                        sectionHeader("ADJUSTMENTS (\(adjustments.count))")

                        VStack(spacing: 0) {
                            ForEach(Array(adjustments.enumerated()), id: \.offset) { index, adj in
                                VStack(spacing: 0) {
                                    adjustmentRow(adj: adj, index: index)
                                    if index < adjustments.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 110)
                }
            }

            // MARK: - Confirm Button
            VStack(spacing: 0) {
                Spacer()
                Divider()
                Button(action: confirm) {
                    Text("Confirm & Continue")
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(items.isEmpty ? Color.textSecondary.opacity(0.25) : Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(items.isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appBackground)
            }
        }
        .navigationTitle("Review Scan")
        .navigationBarTitleDisplayMode(.inline)
        // Add item sheet
        .sheet(isPresented: $showAddItem) {
            ScanItemFormSheet(title: "Add Item") { name, price in
                withAnimation { items.append((name: name, price: price)) }
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        // Edit item sheet
        .sheet(item: Binding(
            get: { editingItem.map { EditingItemWrapper(index: $0.index, name: $0.name, price: $0.price) } },
            set: { editingItem = $0.map { (index: $0.index, name: $0.name, price: $0.price) } }
        )) { wrapper in
            ScanItemFormSheet(
                title: "Edit Item",
                initialName: wrapper.name,
                initialPrice: wrapper.price
            ) { name, price in
                withAnimation { items[wrapper.index] = (name: name, price: price) }
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Item Row

    private func itemRow(item: (name: String, price: Double), index: Int) -> some View {
        Button(action: {
            editingItem = (index: index, name: item.name, price: item.price)
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppTheme.Fonts.inter(15, weight: .medium))
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                Text(item.price.toCurrency())
                    .font(AppTheme.Fonts.inter(15, weight: .semibold))
                    .foregroundColor(Color.textSecondary)

                Image(systemName: "pencil")
                    .font(AppTheme.Fonts.inter(13, weight: .medium))
                    .foregroundColor(Color.textSecondary.opacity(0.4))

                Button(action: { deleteItem(at: index) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTheme.Fonts.inter(18))
                        .foregroundColor(Color.textSecondary.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Item Row

    private var addItemRow: some View {
        Button(action: { showAddItem = true }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "plus")
                            .font(AppTheme.Fonts.inter(13, weight: .bold))
                            .foregroundColor(Color.appPrimary)
                    )
                Text("Add Item")
                    .font(AppTheme.Fonts.inter(15, weight: .medium))
                    .foregroundColor(Color.appPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Adjustment Row

    private func adjustmentRow(adj: (name: String, amount: Double), index: Int) -> some View {
        HStack(spacing: 12) {
            Text(adj.name)
                .font(AppTheme.Fonts.inter(15, weight: .medium))
                .foregroundColor(Color.textPrimary)
            Spacer()
            Text(adj.amount.toCurrency())
                .font(AppTheme.Fonts.inter(15, weight: .semibold))
                .foregroundColor(Color.textSecondary)
            Button(action: { deleteAdjustment(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTheme.Fonts.inter(18))
                    .foregroundColor(Color.textSecondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Empty Items State

    private var emptyItemsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart")
                .font(AppTheme.Fonts.inter(36))
                .foregroundColor(Color.textSecondary.opacity(0.25))
            Text("No items detected")
                .font(AppTheme.Fonts.inter(14, weight: .medium))
                .foregroundColor(Color.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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

    // MARK: - Actions

    private func deleteItem(at index: Int) {
        withAnimation { items.remove(at: index) }
    }

    private func deleteAdjustment(at index: Int) {
        withAnimation { adjustments.remove(at: index) }
    }

    private func confirm() {
        let confirmed = ScannedBillData(
            billName: scannedData.billName,
            total: scannedData.total,
            items: items,
            adjustments: adjustments
        )
        router.push(.billResult(confirmed))
    }
}

// MARK: - Identifiable wrapper for sheet(item:)

private struct EditingItemWrapper: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
    let price: Double
}

// MARK: - Shared Item Form Sheet (Add & Edit)

struct ScanItemFormSheet: View {

    let title: String
    var initialName: String = ""
    var initialPrice: Double = 0
    var onSave: (String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var priceText: String
    @FocusState private var focusedField: Field?

    enum Field { case name, price }

    init(title: String, initialName: String = "", initialPrice: Double = 0, onSave: @escaping (String, Double) -> Void) {
        self.title = title
        self.initialName = initialName
        self.initialPrice = initialPrice
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _priceText = State(initialValue: initialPrice > 0 ? String(Int(initialPrice)) : "")
    }

    private var price: Double { Double(priceText.filter { $0.isNumber }) ?? 0 }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0 }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(AppTheme.Fonts.inter(16, weight: .semibold))
                .foregroundColor(Color.textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                HStack {
                    Text("Name")
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                        .frame(width: 60, alignment: .leading)
                    TextField("e.g. Nasi Goreng", text: $name)
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .price }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Price")
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                        .frame(width: 60, alignment: .leading)
                    TextField("0", text: $priceText)
                        .font(AppTheme.Fonts.inter(15, weight: .regular))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .price)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .padding(.horizontal, 16)

            Button(action: {
                onSave(name.trimmingCharacters(in: .whitespaces), price)
                dismiss()
            }) {
                Text(title == "Edit Item" ? "Save" : "Add")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValid ? Color.appPrimary : Color.textSecondary.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { focusedField = .name }
    }
}

#Preview {
    NavigationStack {
        ScanReviewView(scannedData: ScannedBillData(
            billName: "Scanned Bill",
            total: "",
            items: [("Nasi Goreng", 35000), ("Es Teh", 8000), ("Ayam Bakar", 45000)],
            adjustments: [("Tax", 8800)]
        ))
        .environmentObject(NavigationRouter())
    }
}
