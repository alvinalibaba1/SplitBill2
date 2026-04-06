//
//  TabBarView.swift
//  SplitBill
//

import SwiftUI

struct TabBarView: View {

    @State private var selectedTab = 0
    @StateObject private var loadingState = LoadingState.shared

    // Independent routers per tab
    @StateObject private var homeRouter    = NavigationRouter()
    @StateObject private var statsRouter   = NavigationRouter()
    @StateObject private var historyRouter = NavigationRouter()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {

                // MARK: - Home Tab
                NavigationStack(path: $homeRouter.path) {
                    HomeView(selectedTab: $selectedTab)
                        .navigationDestination(for: RouterDestination.self) { view(for: $0) }
                }
                .environmentObject(homeRouter)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

                // MARK: - Stats Tab
                NavigationStack(path: $statsRouter.path) {
                    StatsView()
                        .navigationDestination(for: RouterDestination.self) { view(for: $0) }
                }
                .environmentObject(statsRouter)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "chart.bar.fill" : "chart.bar")
                    Text("Statistics")
                }
                .tag(1)

                // MARK: - History Tab
                NavigationStack(path: $historyRouter.path) {
                    HistoryView()
                        .navigationDestination(for: RouterDestination.self) { view(for: $0) }
                }
                .environmentObject(historyRouter)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "clock.fill" : "clock")
                    Text("History")
                }
                .tag(2)
            }
            .tint(Color.appPrimary)

            // Global loading overlay
            if loadingState.isProcessingScan {
                LoadingOverlayView()
            }
        }
    }

    @ViewBuilder
    private func view(for destination: RouterDestination) -> some View {
        switch destination {
        case .manualInput:
            MainView()
        case .scanReview(let data):
            ScanReviewView(scannedData: data)
        case .billResult(let data):
            MainView(
                billTitle: data.billName,
                totalPrefill: data.total.filter { $0.isNumber },
                scannedItems: data.items,
                scannedAdjustments: data.adjustments
            )
        case .historyDetail(let bill):
            HistoryDetailView(bill: bill)
        }
    }
}

#Preview {
    TabBarView()
}
