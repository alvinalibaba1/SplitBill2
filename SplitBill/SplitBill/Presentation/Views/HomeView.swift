//
//  HomeView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import VisionKit

struct HomeView: View {

    @ObservedObject var viewModel = HistoryViewModel.shared
    @EnvironmentObject var router: NavigationRouter

    @Binding var selectedTab: Int


    @State private var showScanner = false
    @State private var haptics = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    actionsButton
                    splitHistory
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 80)
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        // Document camera sheet
        .sheet(isPresented: $showScanner) {
            DocumentScanner { lines in
                let items = SmartBillParser.extractItems(from: lines)
                let adjustments = SmartBillParser.extractAdjustments(from: lines)
                let data = ScannedBillData(
                    billName: "Scanned Bill",
                    total: "",
                    items: items,
                    adjustments: adjustments
                )
                router.push(.billResult(data))
                showScanner = false
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SplitBill")
                    .roundedFont(28, weight: .bold)
                    .foregroundColor(Color.textPrimary)
                Text("Split smarter, not harder")
                    .roundedFont(14, weight: .regular)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: - Action Buttons
    private var actionsButton: some View {
        HStack(spacing: 16) {
            Button(action: {
                haptics.impactOccurred()
                router.push(.manualInput)
            }) {
                Label("Add Manually", systemImage: "plus.rectangle")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.appPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.appPrimary.opacity(0.3), radius: 10, y: 5)
            }

            Button(action: {
                haptics.impactOccurred()
                showScanner = true
            }) {
                Label("Quick Scan", systemImage: "viewfinder")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.textPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.textPrimary.opacity(0.2), radius: 10, y: 5)
            }
        }
    }

    // MARK: - Split History Preview
    private var splitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Split History")
                    .roundedFont(18, weight: .bold)
                    .foregroundColor(Color.textPrimary)
                Spacer()
                if !viewModel.history.isEmpty {
                    Button("See more") { selectedTab = 1 }
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                }
            }

            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 44))
                        .foregroundColor(Color.textSecondary.opacity(0.3))

                    Text("No splits yet")
                        .roundedFont(16, weight: .semibold)
                        .foregroundColor(Color.textSecondary)

                    Text("Tap Add Manually or Quick Scan to get started.")
                        .roundedFont(13, weight: .regular)
                        .foregroundColor(Color.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [8, 6]))
                        .foregroundColor(Color.textSecondary.opacity(0.3))
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.history.prefix(3)) { bill in
                        Button(action: { router.push(.historyDetail(bill)) }) {
                            HistoryCardView(bill: bill)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}



#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0))
    }
}
