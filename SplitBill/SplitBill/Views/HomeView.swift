//
//  HomeView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import VisionKit

struct HomeView: View {
    @ObservedObject var storageManager = StorageManager.shared
    @Binding var selectedTab: Int

    @State private var showNewBillOptions = false
    @State private var navigateManual = false
    @State private var showScanner = false
    @State private var navigateScannedBill = false
    @State private var scannedLines: [String] = []
    @State private var scannedBillName: String = "Scanned Bill"
    @State private var scannedTotal: String = ""
    @State private var scannedItems: [(name: String, price: Double)] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        newBillCard
                        recentSection
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }

    private var newBillCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a new split")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)

            Text("Add people, set amounts, and share the total.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)

            Button(action: { showNewBillOptions = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("New Bill")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.green)
                .cornerRadius(14)
            }
            .confirmationDialog("Start a bill", isPresented: $showNewBillOptions, titleVisibility: .visible) {
                Button("Manual input") {
                    navigateManual = true
                }
                Button("Scan bill") {
                    showScanner = true
                }
            }

            NavigationLink(destination: MainView(), isActive: $navigateManual) { EmptyView() }
            NavigationLink(
                destination: MainView(
                    billTitle: scannedBillName,
                    totalPrefill: scannedTotal.filter { $0.isNumber },
                    scannedItems: scannedItems
                ),
                isActive: $navigateScannedBill
            ) { EmptyView() }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent bills")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    Text("Latest splits you've saved.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }

                Spacer()

                if !storageManager.history.isEmpty {
                    Button(action: {
                        selectedTab = 1
                    }) {
                        Text("See all")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }

            if storageManager.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundColor(.gray.opacity(0.3))

                    Text("No splits yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)

                    Text("Create a bill to see it appear here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(storageManager.history.prefix(3)) { bill in
                        NavigationLink(destination: HistoryDetailView(bill: bill)) {
                            HistoryCardView(bill: bill)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        .sheet(isPresented: $showScanner) {
            DocumentScanner { lines in
                scannedLines = lines
                scannedItems = BillTextParser.extractItems(from: lines)
                if let best = BillTextParser.extractBestTotal(from: lines) {
                    scannedTotal = best
                }
                navigateScannedBill = true
            }
        }
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
}
