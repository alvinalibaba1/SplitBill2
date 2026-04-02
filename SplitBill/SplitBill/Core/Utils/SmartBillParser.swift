//
//  SmartBillParser.swift
//  SplitBill
//
//  Advanced bill scanning with multi-strategy parsing
//

import Foundation

struct SmartBillParser {
    private static let numberPattern = "[-+]?[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]+)?"
    private static let numberRegex = try? NSRegularExpression(pattern: numberPattern)

    // MARK: - Receipt Structure Types
    enum ReceiptStructure: CustomStringConvertible {
        case inline              // Name and price on same line
        case multiLine           // Name on one line, price on next
        case quantityBased       // Name, then qty @ price line
        case tabular             // Structured columns
        case mixed               // Multiple patterns

        var description: String {
            switch self {
            case .inline: return "Inline"
            case .multiLine: return "MultiLine"
            case .quantityBased: return "QuantityBased"
            case .tabular: return "Tabular"
            case .mixed: return "Mixed"
            }
        }
    }

    // MARK: - Parsed Item with Confidence
    struct ParsedItem {
        let name: String
        let price: Double
        let quantity: Int
        let confidence: Double
    }

    struct ParsedAdjustment {
        let name: String
        let amount: Double
        let isDiscount: Bool
        let confidence: Double
    }

    // MARK: - Keywords
    private static let ignoreKeywords = [
        "total", "amount due", "balance", "grand total", "subtotal", "total due",
        "cash", "change", "kembalian", "bayar", "service", "tax", "ppn", "pb1",
        "bill", "no.", "meja", "table", "kasir", "terima kasih", "thank you",
        "receipt", "nota", "struk", "alamat", "address", "phone", "telp",
        "date", "tanggal", "waktu", "time",
        "disc", "discount", "diskon", "potongan", "promo",
        "anda hemat", "hemat", "global disc", "member disc", "voucher",
        "grand ttl", "ttl"
    ]

    private static let sizeDescriptors = [
        "small", "medium", "large", "kecil", "sedang", "besar", "reguler", "regular",
        "s", "m", "l", "xl", "jumbo"
    ]

    private static let adjustmentKeywords: [String: (displayName: String, isDiscount: Bool)] = [
        "service": ("Service", false),
        "service charge": ("Service", false),
        "tax": ("Tax", false),
        "ppn": ("PPN", false),
        "pb1": ("PB1", false),
        "pajak": ("Tax", false),
        "discount": ("Discount", true),
        "diskon": ("Discount", true),
        "potongan": ("Discount", true),
        "promo": ("Promo", true)
    ]

    // MARK: - Main Entry Points
    static func extractItems(from lines: [String]) -> [(name: String, price: Double)] {
        guard let _ = numberRegex else { return [] }

        print("\n========== SMART BILL PARSER ==========")
        print("DEBUG: Processing \(lines.count) lines")

        // Detect structure
        let structure = detectStructure(from: lines)
        print("DEBUG: Detected structure: \(structure)")

        // Extract using appropriate strategy
        var parsedItems: [ParsedItem] = []

        switch structure {
        case .inline:
            parsedItems = extractInlineItems(from: lines)
        case .multiLine:
            parsedItems = extractMultiLineItems(from: lines)
        case .quantityBased:
            parsedItems = extractQuantityBasedItems(from: lines)
        case .tabular:
            parsedItems = extractTabularItems(from: lines)
        case .mixed:
            // Try all and merge
            parsedItems = extractMixedItems(from: lines)
        }

        // Filter by confidence and deduplicate
        let items = parsedItems
            .filter { $0.confidence >= 0.5 }
            .sorted { $0.confidence > $1.confidence }
            .map { (name: $0.name, price: $0.price) }

        let deduplicated = removeDuplicates(items)

        print("DEBUG: Final extracted \(deduplicated.count) items")
        for (idx, item) in deduplicated.enumerated() {
            print("  \(idx + 1). \(item.name) - \(item.price)")
        }
        print("=======================================\n")

        return deduplicated
    }

    static func extractAdjustments(from lines: [String]) -> [(name: String, amount: Double)] {
        guard let regex = numberRegex else { return [] }

        let cleanedLines = cleanLines(lines)
        var adjustments: [(name: String, amount: Double)] = []
        var seen: Set<String> = []
        var processedIndices: Set<Int> = []

        print("\n========== ADJUSTMENT EXTRACTION ==========")

        for (idx, line) in cleanedLines.enumerated() {
            if processedIndices.contains(idx) { continue }

            let lower = line.lowercased()

            // Find matching keyword
            var matched: (displayName: String, isDiscount: Bool)?
            for (keyword, value) in adjustmentKeywords {
                if lower == keyword || lower.contains(keyword) {
                    matched = value
                    break
                }
            }

            guard let (displayName, _) = matched else { continue }

            print("DEBUG: Found '\(displayName)' at line \(idx): '\(line)'")

            // Try to extract amount
            var amount: Double?

            // 1. Check current line
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            if let priceMatch = matches.last {
                let rawNumber = nsLine.substring(with: priceMatch.range)
                let normalized = normalizeNumber(rawNumber)
                if let parsed = Double(normalized), parsed > 0 {
                    amount = parsed
                    print("DEBUG: Found amount on same line: \(parsed)")
                }
            }

            // 2. Search next 3 lines if not found
            if amount == nil {
                for offset in 1...3 {
                    let nextIdx = idx + offset
                    guard nextIdx < cleanedLines.count else { break }

                    let nextLine = cleanedLines[nextIdx]
                    let nextLower = nextLine.lowercased()

                    // Skip currency marker lines
                    if nextLower == "rp" || nextLower == "rp." || nextLower == "idr" || nextLower == "idr." {
                        continue
                    }

                    // Stop if hit another keyword
                    if adjustmentKeywords.keys.contains(where: { nextLower.contains($0) }) {
                        break
                    }

                    // Try to extract number
                    let nsNextLine = nextLine as NSString
                    let nextMatches = regex.matches(in: nextLine, range: NSRange(location: 0, length: nsNextLine.length))

                    if let nextMatch = nextMatches.last {
                        let rawNumber = nsNextLine.substring(with: nextMatch.range)
                        let normalized = normalizeNumber(rawNumber)
                        if let parsed = Double(normalized), parsed > 0 {
                            amount = parsed
                            processedIndices.insert(nextIdx)
                            print("DEBUG: Found amount \(offset) lines ahead: \(parsed)")
                            break
                        }
                    }
                }
            }

            guard let finalAmount = amount else {
                print("DEBUG: No amount found for '\(displayName)'")
                continue
            }

            let rounded = (finalAmount * 100).rounded() / 100
            let key = "\(displayName.lowercased())_\(rounded)"

            guard !seen.contains(key) else {
                print("DEBUG: Duplicate '\(displayName)', skipping")
                continue
            }

            seen.insert(key)
            adjustments.append((name: displayName, amount: rounded))
            print("DEBUG: Added \(displayName) = \(rounded)")
        }

        print("DEBUG: Total adjustments extracted: \(adjustments.count)")
        print("===========================================\n")

        return adjustments
    }

    static func extractBestTotal(from lines: [String]) -> String? {
        struct Candidate {
            let value: Double
            let score: Double
            let lineIndex: Int
        }

        var candidates: [Candidate] = []

        let totalKeywords = ["total", "grand total", "amount due", "balance", "total due"]
        let subtotalKeywords = ["subtotal", "sub total", "sub-total"]

        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()

            // Skip item totals
            if lower.contains("item total") || lower.contains("qty total") {
                continue
            }

            let hasCurrency = lower.contains("rp") || lower.contains("idr") || lower.contains("$")
            let hasTotalKeyword = totalKeywords.contains(where: { lower.contains($0) })
            let hasSubtotalKeyword = subtotalKeywords.contains(where: { lower.contains($0) })

            let numbers = extractAllNumbers(from: line)
            for num in numbers {
                var score: Double = 1.0

                if hasTotalKeyword { score += 10.0 }
                if hasSubtotalKeyword { score += 7.0 }
                if hasCurrency { score += 3.0 }

                // Position (totals at bottom)
                let positionRatio = Double(idx) / Double(max(lines.count - 1, 1))
                score += positionRatio * 5.0

                // Magnitude
                if num > 10000 { score += 2.0 }
                if num > 50000 { score += 3.0 }

                candidates.append(Candidate(value: num, score: score, lineIndex: idx))
            }
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else { return nil }

        print("DEBUG: Best total: \(best.value) (score: \(best.score), line: \(best.lineIndex))")

        return String(Int(best.value)).formatAsCurrency()
    }

    // MARK: - Structure Detection
    private static func detectStructure(from lines: [String]) -> ReceiptStructure {
        guard let regex = numberRegex else { return .mixed }

        var inlineCount = 0
        var multiLineCount = 0
        var quantityCount = 0
        var tabularCount = 0

        let cleaned = cleanLines(lines)

        for (idx, line) in cleaned.enumerated() {
            let lower = line.lowercased()

            // Tabular
            if line.contains("|") || (lower.contains("qty") && lower.contains("price")) {
                tabularCount += 1
            }

            // Quantity-based
            if lower.contains("@") || lower.contains(" x ") ||
               lower.range(of: "\\d+\\s*@", options: .regularExpression) != nil {
                quantityCount += 1
            }

            // Inline (name + price same line)
            if hasPrice(line, regex: regex, threshold: 500) {
                let textBefore = getTextBeforePrice(line, regex: regex)
                if isValidItemName(textBefore) && textBefore.count > 3 {
                    inlineCount += 1
                }
            }

            // Multi-line (name, then price on next line)
            if idx < cleaned.count - 1 {
                let nextLine = cleaned[idx + 1]
                if isValidItemName(line) && hasPrice(nextLine, regex: regex, threshold: 500) {
                    let nextTextBefore = getTextBeforePrice(nextLine, regex: regex)
                    if nextTextBefore.count < 3 {
                        multiLineCount += 1
                    }
                }
            }
        }

        print("DEBUG: Counts - Inline:\(inlineCount) MultiLine:\(multiLineCount) Qty:\(quantityCount) Tab:\(tabularCount)")

        if tabularCount > 2 { return .tabular }
        if quantityCount > multiLineCount && quantityCount > inlineCount { return .quantityBased }
        if multiLineCount > inlineCount { return .multiLine }
        if inlineCount > 0 { return .inline }
        return .mixed
    }

    // MARK: - Strategy 1: Inline Items
    private static func extractInlineItems(from lines: [String]) -> [ParsedItem] {
        guard let regex = numberRegex else { return [] }

        var items: [ParsedItem] = []
        let cleaned = cleanLines(lines)

        for line in cleaned {
            if shouldIgnoreLine(line) { continue }

            guard hasPrice(line, regex: regex, threshold: 500) else { continue }

            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            guard let priceMatch = matches.last else { continue }

            let rawNumber = nsLine.substring(with: priceMatch.range)
            let normalized = normalizeNumber(rawNumber)
            guard let price = Double(normalized), price > 0 else { continue }

            // Extract name before price
            var textBefore = nsLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)

            // Skip if this is ONLY a currency symbol (like "Rp" with a number after it for grand total)
            let textLower = textBefore.lowercased()
            if textLower == "rp" || textLower == "idr" || textLower == "rp." || textLower == "idr." ||
               textLower == "rp:" || textLower == "idr:" || textLower.isEmpty {
                continue
            }

            // Remove currency symbols from the end of name
            if textLower.hasSuffix("rp") || textLower.hasSuffix("idr") || textLower.hasSuffix("rp.") || textLower.hasSuffix("idr.") {
                // Find where "Rp" or "IDR" starts and remove it
                if let range = textBefore.range(of: "Rp", options: [.caseInsensitive, .backwards]) {
                    textBefore = String(textBefore[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Re-check after removing currency symbols
            if textBefore.isEmpty || textBefore.count < 3 {
                continue
            }

            // Check if this is valid
            if isValidItemName(textBefore) {
                // Check if this is ONLY a size descriptor
                let finalLower = textBefore.lowercased()
                let isSizeOnly = sizeDescriptors.contains(finalLower)

                if isSizeOnly {
                    // Skip standalone size descriptors
                    continue
                }

                let cleaned = cleanName(textBefore)
                let confidence = calculateConfidence(name: cleaned, price: price, hasContext: true)

                items.append(ParsedItem(name: cleaned, price: price, quantity: 1, confidence: confidence))
            }
        }

        print("DEBUG: Inline strategy extracted \(items.count) items")
        return items
    }

    // MARK: - Strategy 2: Multi-Line Items
    private static func extractMultiLineItems(from lines: [String]) -> [ParsedItem] {
        guard let regex = numberRegex else { return [] }

        var items: [ParsedItem] = []
        let cleaned = cleanLines(lines)
        var skipIndices: Set<Int> = []

        for (idx, line) in cleaned.enumerated() {
            if skipIndices.contains(idx) { continue }
            if shouldIgnoreLine(line) { continue }

            // Check if next line has a price
            guard idx < cleaned.count - 1 else { continue }
            let nextLine = cleaned[idx + 1]

            guard hasPrice(nextLine, regex: regex, threshold: 500) else { continue }

            // Current line should be a name
            guard isValidItemName(line) && line.count >= 3 else { continue }

            // Check if current line is ONLY a size descriptor
            let lineLower = line.lowercased()
            if sizeDescriptors.contains(lineLower) {
                // Skip standalone size descriptors
                continue
            }

            // Extract price from next line
            let nsNextLine = nextLine as NSString
            let matches = regex.matches(in: nextLine, range: NSRange(location: 0, length: nsNextLine.length))
            guard let priceMatch = matches.last else { continue }

            let rawNumber = nsNextLine.substring(with: priceMatch.range)
            let normalized = normalizeNumber(rawNumber)
            guard let price = Double(normalized), price > 0 else { continue }

            // Check that next line is mostly just price (not another item)
            var textBefore = nsNextLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)

            // Remove currency symbols
            let lower = textBefore.lowercased()
            if lower == "rp" || lower == "idr" || lower == "rp." || lower == "idr." {
                textBefore = ""
            }

            // Allow "Rp", currency symbols, size descriptors, or quantity patterns
            let isJustPriceInfo = textBefore.isEmpty ||
                                  textBefore.count < 5 ||
                                  sizeDescriptors.contains(lower) ||
                                  lower.contains("@") || lower.contains(" x ")

            if isJustPriceInfo {
                let cleaned = cleanName(line)
                let confidence = calculateConfidence(name: cleaned, price: price, hasContext: true)

                items.append(ParsedItem(name: cleaned, price: price, quantity: 1, confidence: confidence))
                skipIndices.insert(idx + 1)
            }
        }

        print("DEBUG: MultiLine strategy extracted \(items.count) items")
        return items
    }

    // MARK: - Strategy 3: Quantity-Based Items
    private static func extractQuantityBasedItems(from lines: [String]) -> [ParsedItem] {
        guard let regex = numberRegex else { return [] }

        var items: [ParsedItem] = []
        let cleaned = cleanLines(lines)
        var skipIndices: Set<Int> = []

        for (idx, line) in cleaned.enumerated() {
            if skipIndices.contains(idx) { continue }
            if shouldIgnoreLine(line) { continue }

            // Look for item name
            guard isValidItemName(line) && line.count >= 3 else { continue }

            // Check next line for quantity pattern
            guard idx < cleaned.count - 1 else { continue }
            let nextLine = cleaned[idx + 1]
            let nextLower = nextLine.lowercased()

            // Must have @ or x pattern
            guard nextLower.contains("@") || nextLower.contains(" x ") else { continue }

            // Extract all numbers from quantity line
            let numbers = extractAllNumbers(from: nextLine)
            guard numbers.count >= 2 else { continue }

            // Usually: quantity @ unitPrice = totalPrice
            // Take the last (largest) number as total price
            let price = numbers.max() ?? 0
            guard price > 0 else { continue }

            let quantity = Int(numbers.min() ?? 1)
            let cleaned = cleanName(line)
            let confidence = calculateConfidence(name: cleaned, price: price, hasContext: true)

            items.append(ParsedItem(name: cleaned, price: price, quantity: quantity, confidence: confidence))
            skipIndices.insert(idx + 1)
        }

        print("DEBUG: QuantityBased strategy extracted \(items.count) items")
        return items
    }

    // MARK: - Strategy 4: Tabular Items
    private static func extractTabularItems(from lines: [String]) -> [ParsedItem] {
        // Simplified tabular parsing - use inline strategy for now
        // Future: Implement column-based parsing for structured receipts
        return extractInlineItems(from: lines)
    }

    // MARK: - Strategy 5: Mixed Items
    private static func extractMixedItems(from lines: [String]) -> [ParsedItem] {
        let inline = extractInlineItems(from: lines)
        let multiLine = extractMultiLineItems(from: lines)
        let quantity = extractQuantityBasedItems(from: lines)

        // Merge and deduplicate
        var all = inline + multiLine + quantity

        // Sort by confidence and remove duplicates
        all.sort { $0.confidence > $1.confidence }

        var seen: Set<String> = []
        var unique: [ParsedItem] = []

        for item in all {
            let key = "\(item.name.lowercased())_\(item.price)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(item)
            }
        }

        print("DEBUG: Mixed strategy merged to \(unique.count) items")
        return unique
    }

    // MARK: - Helper Functions
    private static func cleanLines(_ lines: [String]) -> [String] {
        return lines
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                // Filter out standalone currency symbols
                let lower = line.lowercased()
                return !(lower == "rp" || lower == "rp." || lower == "idr" || lower == "idr." || lower == "$" || lower == "rp:" || lower == "idr:")
            }
    }

    private static func shouldIgnoreLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return ignoreKeywords.contains(where: { lower.contains($0) })
    }

    private static func isValidItemName(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digits = text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return letters >= 2 && letters >= digits
    }

    private static func cleanName(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common currency symbols from the name
        let currencyPatterns = ["Rp\\.?", "IDR\\.?", "\\$", "USD", "€", "EUR"]
        for pattern in currencyPatterns {
            // Remove currency at the end of the name (most common)
            cleaned = cleaned.replacingOccurrences(of: "\\s*\(pattern)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
            // Remove currency at the beginning of the name
            cleaned = cleaned.replacingOccurrences(of: "^\\s*\(pattern)\\s*", with: "", options: [.regularExpression, .caseInsensitive])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func hasPrice(_ line: String, regex: NSRegularExpression, threshold: Double) -> Bool {
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        guard let match = matches.last else { return false }

        let rawNumber = nsLine.substring(with: match.range)
        let normalized = normalizeNumber(rawNumber)
        guard let num = Double(normalized) else { return false }

        let lower = line.lowercased()
        return num >= threshold || lower.contains("rp") || lower.contains("idr")
    }

    private static func getTextBeforePrice(_ line: String, regex: NSRegularExpression) -> String {
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        guard let priceMatch = matches.last else { return "" }

        return nsLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)
    }

    private static func extractAllNumbers(from line: String) -> [Double] {
        guard let regex = numberRegex else { return [] }
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        return matches.compactMap { match in
            let raw = nsLine.substring(with: match.range)
            let normalized = normalizeNumber(raw)
            return Double(normalized)
        }
    }

    private static func normalizeNumber(_ raw: String) -> String {
        var cleaned = raw.replacingOccurrences(of: " ", with: "")
        let separators = cleaned.filter { $0 == "." || $0 == "," }

        if separators.count > 1 {
            // Multiple separators - keep last one as decimal
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
            // Single separator
            let digitsAfter = cleaned.distance(from: cleaned.index(after: sepIndex), to: cleaned.endIndex)
            if digitsAfter == 3 {
                // Thousands separator
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            } else {
                // Decimal separator
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        }

        return cleaned
    }

    private static func calculateConfidence(name: String, price: Double, hasContext: Bool) -> Double {
        var confidence: Double = 0.5

        // Name length
        if name.count >= 5 { confidence += 0.1 }
        if name.count >= 10 { confidence += 0.1 }

        // Price magnitude
        if price >= 1000 { confidence += 0.1 }
        if price >= 10000 { confidence += 0.1 }

        // Context
        if hasContext { confidence += 0.1 }

        return min(confidence, 1.0)
    }

    private static func removeDuplicates(_ items: [(name: String, price: Double)]) -> [(name: String, price: Double)] {
        var seen: Set<String> = []
        var unique: [(name: String, price: Double)] = []

        for item in items {
            let key = "\(item.name.lowercased())_\(item.price)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(item)
            }
        }

        return unique
    }
}
