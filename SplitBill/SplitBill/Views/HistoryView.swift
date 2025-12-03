//
//  HistoryView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var storageManager = StorageManager.shared
    @State private var showClearAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if storageManager.history.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.3))

                        Text("No History Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray)

                        Text("Your first split bill will appear here")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(storageManager.history) { bill in
                                NavigationLink(destination: HistoryDetailView(bill: bill)) {
                                    HistoryCardView(bill: bill)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !storageManager.history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showClearAlert = true
                        }) {
                            Text("Clear All")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
            .alert("Clear All History?", isPresented: $showClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    withAnimation {
                        storageManager.clearAllHistory()
                    }
                }
            } message: {
                Text("All split bill history will be permanently deleted.")
            }
        }
    }
}

struct HistoryCardView: View {
    let bill: BillHistory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(bill.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                Text(bill.totalAmount.toCurrency())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.black)

                Text(bill.formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    HistoryView()
}
