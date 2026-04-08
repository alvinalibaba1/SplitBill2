//
//  HomeView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import Vision

struct HomeView: View {

    @ObservedObject var viewModel = HistoryViewModel.shared
    @EnvironmentObject var router: NavigationRouter

    @Binding var selectedTab: Int

    @State private var showCamera = false
    @State private var showOweSummary = false
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
        .sheet(isPresented: $showCamera) {
            BillCameraView { image in
                processImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showOweSummary) {
            OweSummarySheet(history: viewModel.history) { bill in
                router.push(.historyDetail(bill))
            }
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - OCR Processing
    private func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        LoadingState.shared.isProcessingScan = true

        DispatchQueue.global(qos: .userInitiated).async {
            var observed: [(text: String, y: CGFloat)] = []

            let request = VNRecognizeTextRequest { req, _ in
                guard let results = req.results as? [VNRecognizedTextObservation] else { return }
                for obs in results {
                    if let top = obs.topCandidates(1).first {
                        observed.append((top.string, obs.boundingBox.origin.y))
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "id-ID"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])

            let lines = observed.sorted { $0.y > $1.y }.map { $0.text }
            let items       = SmartBillParser.extractItems(from: lines)
            let adjustments = SmartBillParser.extractAdjustments(from: lines)

            DispatchQueue.main.async {
                LoadingState.shared.isProcessingScan = false
                let data = ScannedBillData(
                    billName: "Scanned Bill",
                    total: "",
                    items: items,
                    adjustments: adjustments
                )
                router.push(.scanReview(data))
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Profile avatar — switches to Profile tab
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedTab = 3
                }) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.12))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(AppTheme.Fonts.inter(20, weight: .medium))
                                .foregroundColor(Color.appPrimary)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                // Notification bell
                Button(action: {}) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.08))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "bell.fill")
                                    .font(AppTheme.Fonts.inter(18, weight: .medium))
                                    .foregroundColor(Color.appPrimary)
                            )

                        // Badge dot
                        if !viewModel.history.isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            totalOwedCard
        }
        .padding(.top, 20)
    }

    private var totalOwedCard: some View {
        Button(action: {
            guard !viewModel.history.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showOweSummary = true
        }) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PEOPLE OWE YOU")
                        .roundedFont(11, weight: .semibold)
                        .foregroundColor(Color.appPrimary.opacity(0.7))
                        .tracking(0.8)

                    Text(totalOwed.toCurrency())
                        .roundedFont(36, weight: .bold)
                        .foregroundColor(Color.appPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: totalOwed)

                    HStack(spacing: 4) {
                        Text(viewModel.history.isEmpty
                             ? "No bills yet"
                             : "across \(viewModel.history.count) bill\(viewModel.history.count == 1 ? "" : "s")")
                            .roundedFont(13, weight: .regular)
                            .foregroundColor(Color.textSecondary)

                        if !viewModel.history.isEmpty {
                            Text("· tap to see breakdown")
                                .roundedFont(12, weight: .regular)
                                .foregroundColor(Color.appPrimary.opacity(0.6))
                        }
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.2.fill")
                        .font(AppTheme.Fonts.inter(22))
                        .foregroundColor(Color.appPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.appPrimary.opacity(0.08), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appPrimary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var totalOwed: Double {
        viewModel.history.reduce(0) { $0 + $1.totalAmount }
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
                showCamera = true
            }) {
                Label("Quick Scan", systemImage: "viewfinder")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.appSurface)
                    .foregroundColor(Color.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.appSurface.opacity(0.2), radius: 10, y: 5)
            }
        }
    }

    // MARK: - Recent Split Preview
    private var splitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Split")
                    .roundedFont(18, weight: .bold)
                    .foregroundColor(Color.textPrimary)
                Spacer()
                if !viewModel.history.isEmpty {
                    Button("See all") { selectedTab = 2 }
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                }
            }

            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.clipboard")
                        .font(AppTheme.Fonts.inter(44))
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

// MARK: - Plain Camera (UIImagePickerController — no filter UI)
struct BillCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0))
            .environmentObject(NavigationRouter())
    }
}
