//
//  LoadingOverlayView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 10/12/25.
//

import SwiftUI

struct LoadingOverlayView: View {
    var body: some View {
        ZStack {
            // Dark semi-transparent background
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Animated scanning icon
                LoadingSpinner()

                VStack(spacing: 8) {
                    Text("Processing scan...")
                        .font(AppTheme.Fonts.inter(18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Extracting items and details")
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .transition(.opacity)
    }
}

struct LoadingSpinner: View {
    @State private var isRotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 4)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.appPrimary, lineWidth: 4)
                .frame(width: 80, height: 80)
                .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false)
                    ) {
                        isRotating = true
                    }
                }

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.green)
        }
    }
}

#Preview {
    LoadingOverlayView()
}
