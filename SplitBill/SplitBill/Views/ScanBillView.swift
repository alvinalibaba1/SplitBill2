//
//  ScanBillView.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI
import Vision
import VisionKit

struct ScanBillView: View {
    @State private var billName: String = "Scanned Bill"
    @State private var totalText: String = ""
    @State private var scannedLines: [String] = []
    @State private var extractedItems: [(name: String, price: Double)] = []
    @State private var showScanner = false
    @State private var navigateToBill = false
    @State private var hasLaunchedScanner = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Scan a bill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)

                Text("Use your camera to capture a bill, we'll pull out totals so you can finish splitting.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text("Bill name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                TextField("Scanned Bill", text: $billName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .autocorrectionDisabled(true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Detected total (edit if needed)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                TextField("0", text: $totalText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .autocorrectionDisabled(true)
            }

            if !scannedLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanned text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(scannedLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                    .padding()
                    .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                }
            }

            if !extractedItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected items")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(extractedItems.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                                Spacer()
                                Text(item.price.toCurrency())
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                }
            } else if !scannedLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No items detected yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    Text("We couldn't parse line items from this scan. Edit total above and continue.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
            }

            NavigationLink(
                destination: MainView(
                    billTitle: billName,
                    totalPrefill: totalText.filter { $0.isNumber },
                    scannedItems: extractedItems
                ),
                isActive: $navigateToBill
            ) { EmptyView() }

            Spacer()
        }
        .padding()
        .background(Color.appBackground)
        .sheet(isPresented: $showScanner) {
            DocumentScanner { lines in
                scannedLines = lines
                extractedItems = BillTextParser.extractItems(from: lines)
                if let best = BillTextParser.extractBestTotal(from: lines) {
                    totalText = best
                }
                navigateToBill = true
            }
        }
        .onAppear {
            if !hasLaunchedScanner {
                hasLaunchedScanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showScanner = true
                }
            }
        }
        .navigationTitle("Scan Bill")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BillTextParser {
    private static let numberPattern = "[-+]?[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]+)?"
    private static let numberRegex = try? NSRegularExpression(pattern: numberPattern)

    static func extractBestTotal(from lines: [String]) -> String? {
        struct Candidate { let value: Double; let score: Int }
        var candidates: [Candidate] = []

        let keywords = ["total", "amount due", "balance", "grand total", "subtotal", "total due"]

        for line in lines {
            let lower = line.lowercased()
            let hasCurrency = lower.contains("rp") || lower.contains("idr") || lower.contains("$")
            let hasKeyword = keywords.contains(where: { lower.contains($0) })

            let numbers = extractNumbers(from: line)
            for num in numbers {
                var score = 1
                if hasKeyword { score += 5 }
                if hasCurrency { score += 3 }
                if num > 0 { score += 1 }
                candidates.append(.init(value: num, score: score))
            }
        }

        guard let best = candidates.max(by: { lhs, rhs in
            if lhs.score == rhs.score { return lhs.value < rhs.value }
            return lhs.score < rhs.score
        }) else { return nil }

        let intVal = Int(best.value)
        return String(intVal).formatAsCurrency()
    }

    static func extractItems(from lines: [String]) -> [(name: String, price: Double)] {
        guard let regex = numberRegex else { return [] }
        let ignoreKeywords = [
            "total", "amount due", "balance", "grand total", "subtotal", "total due",
            "cash", "change", "kembalian", "qty", "quantity", "count", "pcs", "pc", "kasir"
        ]

        // Normalise whitespace so the parser does not get tripped by uneven spacing from OCR.
        let cleanedLines = lines
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [(name: String, price: Double)] = []
        var seen: Set<String> = []

        for (idx, line) in cleanedLines.enumerated() {
            guard !shouldIgnore(line: line, keywords: ignoreKeywords) else { continue }

            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            guard let chosenMatch = matches.last else { continue }

            let rawNumber = nsLine.substring(with: chosenMatch.range)
            let normalizedNumber = normalizeNumberString(rawNumber)
            guard let candidatePrice = Double(normalizedNumber), candidatePrice > 0 else { continue }

            let lower = line.lowercased()
            let hasDecimalSeparator = rawNumber.contains(".") || rawNumber.contains(",")
            let hasPriceContext = lower.contains("rp") || lower.contains("idr") || lower.contains("=") || lower.contains(" x ")
            let isRightAlignedPrice = chosenMatch.range.location + chosenMatch.range.length >= max(nsLine.length - 8, 0)

            // Only treat this line as a price line if there is a clear hint (currency/equals)
            // or the number looks like a formatted amount (e.g. 7.000).
            if !hasPriceContext && !hasDecimalSeparator && !isRightAlignedPrice { continue }
            if !hasPriceContext && !hasDecimalSeparator && candidatePrice < 500 { continue }
            if hasPriceContext && !hasDecimalSeparator && !lower.contains("rp") && candidatePrice <= 2 { continue } // likely quantity, not price

            let inlineName = itemNameInline(in: line, priceRange: chosenMatch.range)
            let nearestBefore = nearestItemName(start: idx - 1, end: max(idx - 3, 0), step: -1, lines: cleanedLines, keywords: ignoreKeywords)
            let nearestAfter = nearestItemName(start: idx + 1, end: min(idx + 3, cleanedLines.count - 1), step: 1, lines: cleanedLines, keywords: ignoreKeywords)

            guard let namePart = inlineName ?? nearestBefore ?? nearestAfter, looksLikeItemName(namePart) else { continue }

            let cleanedName = cleanItemName(namePart)
            let price = (candidatePrice * 100).rounded() / 100 // keep 2 decimals at most
            let key = "\(cleanedName.lowercased())_\(price)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            items.append((name: cleanedName, price: price))
        }

        return items
    }

    static func extractNumbers(from line: String) -> [Double] {
        guard let regex = numberRegex else { return [] }
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        return matches.compactMap { match in
            let raw = nsLine.substring(with: match.range)
            let normalized = normalizeNumberString(raw)
            return Double(normalized)
        }
    }

    private static func normalizeNumberString(_ raw: String) -> String {
        var cleaned = raw.replacingOccurrences(of: " ", with: "")
        let separators = cleaned.filter { $0 == "." || $0 == "," }
        if separators.count > 1 {
            if let lastSep = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) {
                let lastIdx = cleaned.distance(from: cleaned.startIndex, to: lastSep)
                cleaned = cleaned.enumerated().map { idx, ch -> String in
                    if (ch == "." || ch == ",") && idx != lastIdx {
                        return ""
                    }
                    return ch == "," ? "." : String(ch)
                }.joined()
            }
        } else if let sep = separators.first, let sepIndex = cleaned.lastIndex(of: sep) {
            // If only one separator and it separates three trailing digits, treat it as a thousands separator.
            let digitsAfter = cleaned.distance(from: cleaned.index(after: sepIndex), to: cleaned.endIndex)
            if digitsAfter == 3 {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: "")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        }
        return cleaned
    }

    private static func shouldIgnore(line: String, keywords: [String]) -> Bool {
        let lower = line.lowercased()
        return keywords.contains(where: { lower.contains($0) })
    }

    private static func looksLikeItemName(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digits = text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return letters >= 2 && letters >= digits
    }

    private static func cleanItemName(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func nearestItemName(start: Int, end: Int, step: Int, lines: [String], keywords: [String]) -> String? {
        guard start >= 0, end >= 0, start < lines.count, end < lines.count else { return nil }
        var i = start
        while step > 0 ? i <= end : i >= end {
            let candidate = lines[i]
            if shouldIgnore(line: candidate, keywords: keywords) { i += step; continue }
            if looksLikeItemName(candidate) { return candidate }
            i += step
        }
        return nil
    }

    private static func itemNameInline(in line: String, priceRange: NSRange) -> String? {
        let nsLine = line as NSString
        let before = nsLine.substring(to: priceRange.location)
        let afterIndex = priceRange.location + priceRange.length
        let after = afterIndex < nsLine.length
            ? nsLine.substring(from: afterIndex)
            : ""

        let candidates = [before, after]
            .map { cleanItemName($0) }
            .filter { !$0.isEmpty }

        return candidates.first(where: { looksLikeItemName($0) })
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) { }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: ([String]) -> Void

        init(onScan: @escaping ([String]) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var observed: [(text: String, y: CGFloat)] = []
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for obs in observations {
                    if let candidate = obs.topCandidates(1).first {
                        observed.append((candidate.string, obs.boundingBox.origin.y))
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "id-ID"]
            let queue = DispatchQueue.global(qos: .userInitiated)
            let handlerGroup = DispatchGroup()

            for page in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: page)
                guard let cgImage = image.cgImage else { continue }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                handlerGroup.enter()
                queue.async {
                    defer { handlerGroup.leave() }
                    try? handler.perform([request])
                }
            }

            handlerGroup.notify(queue: .main) {
                controller.dismiss(animated: true) {
                    let sorted = observed.sorted { $0.y > $1.y }.map { $0.text }
                    self.onScan(sorted)
                }
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

#Preview {
    NavigationStack {
        ScanBillView()
    }
}
