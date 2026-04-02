//
//  TabBarView.swift
//  SplitBill
//

import SwiftUI

struct TabBarView: View {

    @State private var selectedTab = 0
    @StateObject private var loadingState = LoadingState.shared
    
    // Routers for independent tab navigation handling
    @StateObject private var homeRouter = NavigationRouter()
    @StateObject private var historyRouter = NavigationRouter()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {

                // MARK: - Home Tab
                NavigationStack(path: $homeRouter.path) {
                    HomeView(selectedTab: $selectedTab)
                        .navigationDestination(for: RouterDestination.self) { dest in
                            view(for: dest)
                        }
                }
                .environmentObject(homeRouter)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

                // MARK: - History Tab
                NavigationStack(path: $historyRouter.path) {
                    HistoryView()
                        .navigationDestination(for: RouterDestination.self) { dest in
                            view(for: dest)
                        }
                }
                .environmentObject(historyRouter)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "clock.fill" : "clock")
                    Text("History")
                }
                .tag(1)
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
