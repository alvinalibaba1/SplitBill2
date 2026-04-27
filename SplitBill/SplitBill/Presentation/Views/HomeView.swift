//
//  HomeView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import Vision
import VisionKit

struct HomeView: View {

    @ObservedObject var viewModel = HistoryViewModel.shared
    @EnvironmentObject var router: NavigationRouter

    @Binding var selectedTab: Int
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    @State private var showCamera = false
    @State private var showOweSummary = false
    @State private var haptics = UIImpactFeedbackGenerator(style: .medium)
    @State private var appeared = false

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
            .padding(.bottom, 16)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    appeared = true
                }
            }

        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            BillDocumentScanner { image in
                processImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showOweSummary) {
            OweSummarySheet(history: viewModel.history) { bill in
                router.push(.historyDetail(bill))
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - OCR + AI Processing
    private func processImage(_ image: UIImage) {
        // Normalize EXIF orientation once — used for both Vision and Gemini paths
        let normalized = image.normalizedForReceipt()
        guard let cgImage = normalized.cgImage else { return }

        LoadingState.shared.isProcessingScan = true

        Task {
            // ── Step 1: Gemini reads the IMAGE directly (multimodal) ──────────
            let billName: String
            let total: String
            let items: [(name: String, price: Double)]
            let adjustments: [(name: String, amount: Double)]
            let usedAI: Bool

            do {
                let result = try await GeminiParser.parse(image: normalized)
                usedAI = result.usedAI

                // If Gemini returned useful data, use it; otherwise fall through to OCR fallback
                if !result.items.isEmpty {
                    billName    = result.billName?.isEmpty == false ? result.billName! : "Scanned Bill"
                    total       = result.total ?? ""
                    items       = result.items
                    adjustments = result.adjustments
                } else {
                    // Gemini gave no items — run local OCR fallback
                    let ocrLines = await runOCR(cgImage: cgImage)
                    billName    = result.billName?.isEmpty == false
                        ? result.billName!
                        : (SmartBillParser.extractBillName(from: ocrLines) ?? "Scanned Bill")
                    total       = result.total ?? SmartBillParser.extractBestTotal(from: ocrLines) ?? ""
                    items       = SmartBillParser.extractItems(from: ocrLines)
                    adjustments = SmartBillParser.extractAdjustments(from: ocrLines)
                }
            } catch {
                // Network / rate-limit error after retry → local OCR fallback
                print("[GeminiParser] ❌ Error: \(error)")
                let ocrLines = await runOCR(cgImage: cgImage)
                usedAI      = false
                billName    = SmartBillParser.extractBillName(from: ocrLines) ?? "Scanned Bill"
                total       = SmartBillParser.extractBestTotal(from: ocrLines) ?? ""
                items       = SmartBillParser.extractItems(from: ocrLines)
                adjustments = SmartBillParser.extractAdjustments(from: ocrLines)
            }

            // ── Step 3: Navigate ──────────────────────────────────────────────
            await MainActor.run {
                LoadingState.shared.isProcessingScan = false
                var data = ScannedBillData(
                    billName: billName,
                    total: total,
                    items: items,
                    adjustments: adjustments
                )
                data.parsedByAI = usedAI
                router.push(.scanReview(data))
            }
        }
    }

    // MARK: - OCR (fallback only)

    private func runOCR(cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var observed: [(text: String, x: CGFloat, y: CGFloat)] = []
                let req = VNRecognizeTextRequest { r, _ in
                    guard let res = r.results as? [VNRecognizedTextObservation] else { return }
                    for obs in res {
                        if let top = obs.topCandidates(1).first {
                            observed.append((top.string, obs.boundingBox.midX, obs.boundingBox.midY))
                        }
                    }
                }
                req.recognitionLevel       = .accurate
                req.usesLanguageCorrection = true
                req.recognitionLanguages   = ["id-ID", "en-US"]
                req.minimumTextHeight      = 0.015
                try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])

                let yThreshold: CGFloat = 0.025
                var groups: [[(text: String, x: CGFloat, y: CGFloat)]] = []
                for obs in observed.sorted(by: { $0.y > $1.y }) {
                    if let idx = groups.indices.first(where: {
                        !groups[$0].isEmpty && abs(groups[$0][0].y - obs.y) < yThreshold
                    }) { groups[idx].append(obs) } else { groups.append([obs]) }
                }
                let lines = groups
                    .sorted { ($0.first?.y ?? 0) > ($1.first?.y ?? 0) }
                    .map { g in g.sorted { $0.x < $1.x }.map { $0.text }.joined(separator: " ") }
                    .filter { !$0.isEmpty }
                cont.resume(returning: lines)
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
                    Text("home.owe.title".localized)
                        .roundedFont(11, weight: .semibold)
                        .foregroundColor(Color.appPrimary.opacity(0.7))
                        .tracking(0.8)

                    Text(totalOwed.toCurrency())
                        .roundedFont(36, weight: .bold)
                        .foregroundColor(Color.appPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: totalOwed)

                    HStack(spacing: 4) {
                        if viewModel.history.isEmpty {
                            Text("home.no.bills".localized)
                                .roundedFont(13, weight: .regular)
                                .foregroundColor(Color.textSecondary)
                        } else if billsWithUnpaid == 0 {
                            Text("home.bills.settled".localized)
                                .roundedFont(13, weight: .medium)
                                .foregroundColor(.green)
                        } else {
                            let fmt = billsWithUnpaid == 1 ? "home.subtitle.single".localized : "home.subtitle.plural".localized
                            Text(String(format: fmt, billsWithUnpaid))
                                .roundedFont(13, weight: .regular)
                                .foregroundColor(Color.textSecondary)
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
            .background(
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.13), Color.appSecondary.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.appPrimary.opacity(0.25), radius: 28, x: 0, y: 0)
        }
        .buttonStyle(.plain)
    }

    /// Sum of UNPAID people amounts across all bills (decreases as people are marked paid)
    private var totalOwed: Double {
        viewModel.history.reduce(0) { total, bill in
            total + bill.people.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
        }
    }

    /// Number of bills that still have at least one unpaid person
    private var billsWithUnpaid: Int {
        viewModel.history.filter { $0.people.contains { !$0.isPaid } }.count
    }

    // MARK: - Action Buttons
    private var actionsButton: some View {
        HStack(spacing: 16) {
            Button(action: {
                haptics.impactOccurred()
                router.push(.manualInput)
            }) {
                Label("home.add.manually".localized, systemImage: "plus.rectangle")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6C63F5"), Color(hex: "5651D8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.appPrimary.opacity(0.4), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(PressableButtonStyle())

            Button(action: {
                haptics.impactOccurred()
                showCamera = true
            }) {
                Label("home.quick.scan".localized, systemImage: "viewfinder")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .foregroundColor(Color.appPrimary)
                    .background(Color.appPrimary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appPrimary.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Recent Split Preview
    private var splitHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("home.recent.split".localized)
                    .roundedFont(18, weight: .bold)
                    .foregroundColor(Color.textPrimary)
                Spacer()
                if !viewModel.history.isEmpty {
                    Button("home.see.all".localized) { selectedTab = 2 }
                        .font(AppTheme.Fonts.inter(14, weight: .medium))
                        .foregroundColor(Color.appPrimary)
                }
            }

            if viewModel.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.clipboard")
                        .font(AppTheme.Fonts.inter(44))
                        .foregroundColor(Color.textSecondary.opacity(0.3))

                    Text("home.no.splits".localized)
                        .roundedFont(16, weight: .semibold)
                        .foregroundColor(Color.textSecondary)

                    Text("home.no.splits.sub".localized)
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
                    ForEach(Array(viewModel.history.prefix(3).enumerated()), id: \.element.id) { i, bill in
                        Button(action: { router.push(.historyDetail(bill)) }) {
                            HistoryCardView(bill: bill, showPaymentStatus: true)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.75)
                            .delay(Double(i) * 0.07),
                            value: appeared
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Document Camera (VNDocumentCameraViewController — auto-crops, deskews, enhances)

struct BillDocumentScanner: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true) {
                guard scan.pageCount > 0 else { return }
                self.onCapture(scan.imageOfPage(at: 0))
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage helper

private extension UIImage {
    /// Redraws into a new bitmap with .up orientation, correcting EXIF rotation.
    func normalizedForReceipt() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0))
            .environmentObject(NavigationRouter())
    }
}
