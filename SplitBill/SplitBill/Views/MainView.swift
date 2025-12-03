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

    init(billTitle: String = "", totalPrefill: String = "", scannedItems: [(name: String, price: Double)] = []) {
        _viewModel = StateObject(
            wrappedValue: SplitBillViewModel(
                billTitle: billTitle,
                totalAmount: totalPrefill,
                scannedItems: scannedItems
            )
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                    peopleSection
                    adjustmentSection
                    actionsSection
                }
                .frame(maxWidth: 600)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            NavigationLink(
                destination: ResultView(viewModel: viewModel),
                isActive: $navigateResult
            ) { EmptyView() }
        )
        .sheet(item: $adjustmentPreset) { preset in
            AddAdjustmentSheet(
                isPresented: Binding(
                    get: { adjustmentPreset != nil },
                    set: { value in
                        if !value { adjustmentPreset = nil }
                    }
                ),
                defaultName: preset.name,
                defaultIsDiscount: preset.isDiscount,
                onAdd: { name, amount, isDiscount in
                    viewModel.addAdjustment(name: name, amount: amount, isDiscount: isDiscount)
                }
            )
        }
        .navigationDestination(item: $selectedPerson) { person in
            PersonDetailView(
                person: person,
                viewModel: viewModel
            )
        }
        .overlay(alignment: .center) {
            if showingAddPerson {
                AddPersonSheet(
                    isPresented: $showingAddPerson,
                    onAdd: { name in
                        viewModel.addPerson(name: name)
                    }
                )
            }
        }
        .navigationTitle("Split Bill")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bill name")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)

            TextField("", text: $viewModel.billTitle, prompt: Text("  Name this bill").foregroundColor(.gray.opacity(0.6)))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding()
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                .autocorrectionDisabled(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("People")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("Add everyone who shares this bill.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                }

                Spacer()

                Button(action: {
                    showingAddPerson = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                    Text("Add")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.green)
                .cornerRadius(14)
                .shadow(color: Color.green.opacity(0.2), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: 12) {
                if viewModel.people.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 52))
                            .foregroundColor(.gray.opacity(0.25))

                        Text("No people yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)

                        Text("Tap Add to include someone.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [8, 6]))
                            .foregroundColor(Color.gray.opacity(0.35))
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.people) { person in
                            PersonCardView(
                                person: person,
                                onDelete: {
                                    if let index = viewModel.people.firstIndex(where: { $0.id == person.id }) {
                                        viewModel.removePerson(at: IndexSet(integer: index))
                                    }
                                },
                                onTap: {
                                    selectedPerson = person
                                }
                            )
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(maxWidth: .infinity)
    }

    private var adjustmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extras")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("Add tax, discount, service, or other fees.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.black)
                }

                Spacer()

                Menu {
                    Button("Tax") { adjustmentPreset = AdjustmentSheetPreset(name: "Tax", isDiscount: false) }
                    Button("Discount") { adjustmentPreset = AdjustmentSheetPreset(name: "Discount", isDiscount: true) }
                    Button("Service") { adjustmentPreset = AdjustmentSheetPreset(name: "Service", isDiscount: false) }
                    Button("Other") { adjustmentPreset = AdjustmentSheetPreset(name: "Other", isDiscount: false) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Add")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(14)
                    .shadow(color: Color.green.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }

            if viewModel.adjustments.isEmpty {
                VStack(spacing: 8) {
                    Text("No extras yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)

                    Text("Add tax, discounts, or service charges.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.35), lineWidth: 1.2)
                )
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

                            Button(action: {
                                viewModel.removeAdjustment(id: adj.id)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(6)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 6)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .frame(maxWidth: .infinity)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {

            AnimatedButton(
                title: "Calculate Split Bill",
                action: {
                    let history = BillHistory(
                        title: viewModel.billTitle.isEmpty ? "" : viewModel.billTitle,
                        totalAmount: viewModel.totalForSplit,
                        people: viewModel.people,
                        splitAmount: viewModel.averageAmount
                    )
                    StorageManager.shared.saveHistory(history)
                    navigateResult = true
                },
                isEnabled: viewModel.hasValidSplit
            )
            .padding(.horizontal)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

}

struct AdjustmentSheetPreset: Identifiable {
    let id = UUID()
    let name: String
    let isDiscount: Bool
}

#Preview {
    MainView()
}
