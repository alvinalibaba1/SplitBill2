//
//  SmartBillParser.swift
//  SplitBill
//
//  Advanced bill scanning with multi-strategy parsing
//

import Foundation
import NaturalLanguage

struct SmartBillParser {
    private static let numberPattern = "[-+]?[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]+)?"
    private static let numberRegex = try? NSRegularExpression(pattern: numberPattern)

    // MARK: - Receipt Structure Types
    enum ReceiptStructure: CustomStringConvertible {
        case inline
        case multiLine
        case quantityBased
        case tabular
        case mixed

        var description: String {
            switch self {
            case .inline:        return "Inline"
            case .multiLine:     return "MultiLine"
            case .quantityBased: return "QuantityBased"
            case .tabular:       return "Tabular"
            case .mixed:         return "Mixed"
            }
        }
    }

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

    // English ignore keywords
    private static let ignoreKeywordsEN = [
        "total", "amount due", "balance", "grand total", "subtotal", "total due",
        "cash", "change", "service", "tax", "bill", "table", "thank you",
        "receipt", "address", "phone", "date", "time",
        "disc", "discount", "promo", "voucher", "order", "invoice",
        "wifi", "password", "member", "loyalty"
    ]

    // Indonesian ignore keywords
    private static let ignoreKeywordsID = [
        "total", "grand total", "subtotal", "jumlah",
        "kembalian", "bayar", "tunai", "kasir",
        "terima kasih", "nota", "struk", "kwitansi",
        "alamat", "telp", "hp", "no.", "meja", "nomor",
        "tanggal", "waktu", "jam", "tgl",
        "diskon", "potongan", "promo", "hemat", "anda hemat",
        "npwp", "siup", "nib", "ppn", "pb1", "pajak",
        "service", "layanan", "biaya", "instagram", "facebook",
        "wifi", "password", "voucher", "member"
    ]

    // Combined for fallback
    private static let ignoreKeywords: [String] = ignoreKeywordsEN + ignoreKeywordsID

    private static let sizeDescriptors = [
        "small", "medium", "large", "kecil", "sedang", "besar", "reguler", "regular",
        "s", "m", "l", "xl", "jumbo"
    ]

    private static let adjustmentKeywords: [String: (displayName: String, isDiscount: Bool)] = [
        "service":        ("Service", false),
        "service charge": ("Service", false),
        "tax":            ("Tax", false),
        "ppn":            ("PPN", false),
        "pb1":            ("PB1", false),
        "pajak":          ("Tax", false),
        "discount":       ("Discount", true),
        "diskon":         ("Discount", true),
        "potongan":       ("Discount", true),
        "promo":          ("Promo", true)
    ]

    // MARK: - Main Entry Points

    static func extractItems(from lines: [String]) -> [(name: String, price: Double)] {
        guard let _ = numberRegex else { return [] }

        let structure = detectStructure(from: lines)
        var parsedItems: [ParsedItem] = []

        switch structure {
        case .inline:        parsedItems = extractInlineItems(from: lines)
        case .multiLine:     parsedItems = extractMultiLineItems(from: lines)
        case .quantityBased: parsedItems = extractQuantityBasedItems(from: lines)
        case .tabular:       parsedItems = extractTabularItems(from: lines)
        case .mixed:         parsedItems = extractMixedItems(from: lines)
        }

        let items = parsedItems
            .filter { $0.confidence >= 0.5 }
            .sorted { $0.confidence > $1.confidence }
            .map { (name: $0.name, price: $0.price) }

        let deduplicated = removeDuplicates(items)

        // NLP pass: boost confidence of noun-phrase items, drop clear non-food lines
        let validated = nlpValidateItems(deduplicated)

        return validated
    }

    static func extractAdjustments(from lines: [String]) -> [(name: String, amount: Double)] {
        guard let regex = numberRegex else { return [] }

        let cleanedLines = cleanLines(lines)
        var adjustments: [(name: String, amount: Double)] = []
        var seen: Set<String> = []
        var processedIndices: Set<Int> = []

        for (idx, line) in cleanedLines.enumerated() {
            if processedIndices.contains(idx) { continue }

            let lower = line.lowercased()
            var matched: (displayName: String, isDiscount: Bool)?
            for (keyword, value) in adjustmentKeywords {
                if lower == keyword || lower.contains(keyword) {
                    matched = value
                    break
                }
            }
            guard let (displayName, _) = matched else { continue }

            var amount: Double?

            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            if let priceMatch = matches.last {
                let rawNumber = nsLine.substring(with: priceMatch.range)
                let normalized = normalizeNumber(rawNumber)
                if let parsed = Double(normalized), parsed > 0 {
                    amount = parsed
                }
            }

            if amount == nil {
                for offset in 1...3 {
                    let nextIdx = idx + offset
                    guard nextIdx < cleanedLines.count else { break }
                    let nextLine = cleanedLines[nextIdx]
                    let nextLower = nextLine.lowercased()
                    if nextLower == "rp" || nextLower == "rp." || nextLower == "idr" || nextLower == "idr." { continue }
                    if adjustmentKeywords.keys.contains(where: { nextLower.contains($0) }) { break }
                    let nsNextLine = nextLine as NSString
                    let nextMatches = regex.matches(in: nextLine, range: NSRange(location: 0, length: nsNextLine.length))
                    if let nextMatch = nextMatches.last {
                        let rawNumber = nsNextLine.substring(with: nextMatch.range)
                        let normalized = normalizeNumber(rawNumber)
                        if let parsed = Double(normalized), parsed > 0 {
                            amount = parsed
                            processedIndices.insert(nextIdx)
                            break
                        }
                    }
                }
            }

            guard let finalAmount = amount else { continue }
            let rounded = (finalAmount * 100).rounded() / 100
            let key = "\(displayName.lowercased())_\(rounded)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            adjustments.append((name: displayName, amount: rounded))
        }

        return adjustments
    }

    static func extractBestTotal(from lines: [String]) -> String? {
        struct Candidate {
            let value: Double
            let score: Double
            let lineIndex: Int
        }

        var candidates: [Candidate] = []
        let totalKeywords    = ["total", "grand total", "amount due", "balance", "total due"]
        let subtotalKeywords = ["subtotal", "sub total", "sub-total"]

        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()
            if lower.contains("item total") || lower.contains("qty total") { continue }

            let hasCurrency       = lower.contains("rp") || lower.contains("idr") || lower.contains("$")
            let hasTotalKeyword   = totalKeywords.contains(where: { lower.contains($0) })
            let hasSubtotalKeyword = subtotalKeywords.contains(where: { lower.contains($0) })

            let numbers = extractAllNumbers(from: line)
            for num in numbers {
                var score: Double = 1.0
                if hasTotalKeyword    { score += 10.0 }
                if hasSubtotalKeyword { score += 7.0 }
                if hasCurrency        { score += 3.0 }
                let positionRatio = Double(idx) / Double(max(lines.count - 1, 1))
                score += positionRatio * 5.0
                if num > 10000 { score += 2.0 }
                if num > 50000 { score += 3.0 }
                candidates.append(Candidate(value: num, score: score, lineIndex: idx))
            }
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else { return nil }
        return String(Int(best.value)).formatAsCurrency()
    }

    // MARK: - Bill Name Extraction (NLP-powered)

    static func extractBillName(from lines: [String]) -> String? {
        let cleaned = cleanLines(lines)
        let candidates = Array(cleaned.prefix(8))

        // Strategy 1: Named Entity Recognition — look for org or place name
        let nerTagger = NLTagger(tagSchemes: [.nameType])
        for line in candidates {
            if shouldIgnoreLine(line) { continue }
            let lower = line.lowercased()
            if lower.contains("rp") || lower.contains("idr") { continue }
            if lower.contains("jl.") || lower.contains("jalan") { continue }

            nerTagger.string = line
            var foundEntity = false
            nerTagger.enumerateTags(
                in: line.startIndex..<line.endIndex,
                unit: .word,
                scheme: .nameType,
                options: [.omitWhitespace, .omitPunctuation]
            ) { tag, _ in
                if tag == .organizationName || tag == .placeName {
                    foundEntity = true
                }
                return !foundEntity
            }
            if foundEntity {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strategy 2: Heuristic fallback
        for line in candidates {
            let lower = line.lowercased()
            if shouldIgnoreLine(line) { continue }
            if lower.contains("/") || lower.contains("jl.") || lower.contains("jalan") { continue }
            if lower.range(of: "\\d{2}[:/]\\d{2}", options: .regularExpression) != nil { continue }
            if lower.contains("rp") || lower.contains("idr") { continue }

            let digits  = line.filter { $0.isNumber }.count
            let letters = line.filter { $0.isLetter }.count
            guard letters >= 3 && digits < letters else { continue }
            guard line.trimmingCharacters(in: .whitespaces).count >= 4 else { continue }

            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    // MARK: - Structure Detection

    private static func detectStructure(from lines: [String]) -> ReceiptStructure {
        guard let regex = numberRegex else { return .mixed }

        var inlineCount    = 0
        var multiLineCount = 0
        var quantityCount  = 0
        var tabularCount   = 0

        let cleaned = cleanLines(lines)

        for (idx, line) in cleaned.enumerated() {
            let lower = line.lowercased()

            if line.contains("|") || (lower.contains("qty") && lower.contains("price")) {
                tabularCount += 1
            }

            if hasQuantityPattern(in: lower) {
                quantityCount += 1
            }

            if hasPrice(line, regex: regex, threshold: 500) {
                let textBefore = getTextBeforePrice(line, regex: regex)
                if isValidItemName(textBefore) && textBefore.count > 3 {
                    inlineCount += 1
                }
            }

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

        if tabularCount > 2                                               { return .tabular }
        if quantityCount > multiLineCount && quantityCount > inlineCount  { return .quantityBased }
        if multiLineCount > inlineCount                                   { return .multiLine }
        if inlineCount > 0                                                { return .inline }
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

            var textBefore = nsLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)
            let textLower  = textBefore.lowercased()

            if textLower == "rp" || textLower == "idr" || textLower == "rp." ||
               textLower == "idr." || textLower == "rp:" || textLower.isEmpty { continue }

            if textLower.hasSuffix("rp") || textLower.hasSuffix("idr") || textLower.hasSuffix("rp.") {
                if let range = textBefore.range(of: "Rp", options: [.caseInsensitive, .backwards]) {
                    textBefore = String(textBefore[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Strip leading quantity prefix: "2x ", "2 x ", "2 pcs "
            textBefore = stripLeadingQuantity(from: textBefore)

            if textBefore.isEmpty || textBefore.count < 3 { continue }

            if isValidItemName(textBefore) {
                let finalLower = textBefore.lowercased()
                if sizeDescriptors.contains(finalLower) { continue }
                let cleanedName = cleanName(textBefore)
                let confidence  = calculateConfidence(name: cleanedName, price: price, hasContext: true)
                items.append(ParsedItem(name: cleanedName, price: price, quantity: 1, confidence: confidence))
            }
        }

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
            guard idx < cleaned.count - 1 else { continue }

            let nextLine = cleaned[idx + 1]
            guard hasPrice(nextLine, regex: regex, threshold: 500) else { continue }
            guard isValidItemName(line) && line.count >= 3 else { continue }

            let lineLower = line.lowercased()
            if sizeDescriptors.contains(lineLower) { continue }

            let nsNextLine = nextLine as NSString
            let matches    = regex.matches(in: nextLine, range: NSRange(location: 0, length: nsNextLine.length))
            guard let priceMatch = matches.last else { continue }

            let rawNumber  = nsNextLine.substring(with: priceMatch.range)
            let normalized = normalizeNumber(rawNumber)
            guard let price = Double(normalized), price > 0 else { continue }

            var textBefore = nsNextLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)
            let lower      = textBefore.lowercased()
            if lower == "rp" || lower == "idr" || lower == "rp." || lower == "idr." { textBefore = "" }

            let isJustPriceInfo = textBefore.isEmpty ||
                                  textBefore.count < 5 ||
                                  sizeDescriptors.contains(lower) ||
                                  hasQuantityPattern(in: lower)

            if isJustPriceInfo {
                let cleanedName = cleanName(line)
                let confidence  = calculateConfidence(name: cleanedName, price: price, hasContext: true)
                items.append(ParsedItem(name: cleanedName, price: price, quantity: 1, confidence: confidence))
                skipIndices.insert(idx + 1)
            }
        }

        return items
    }

    // MARK: - Strategy 3: Quantity-Based Items

    private static func extractQuantityBasedItems(from lines: [String]) -> [ParsedItem] {
        var items: [ParsedItem] = []
        let cleaned = cleanLines(lines)
        var skipIndices: Set<Int> = []

        for (idx, line) in cleaned.enumerated() {
            if skipIndices.contains(idx) { continue }
            if shouldIgnoreLine(line) { continue }
            guard isValidItemName(line) && line.count >= 3 else { continue }
            guard idx < cleaned.count - 1 else { continue }

            let nextLine  = cleaned[idx + 1]
            let nextLower = nextLine.lowercased()

            // Expanded quantity pattern detection
            guard hasQuantityPattern(in: nextLower) else { continue }

            let numbers = extractAllNumbers(from: nextLine)
            guard numbers.count >= 2 else { continue }

            let price    = numbers.max() ?? 0
            guard price > 0 else { continue }

            let quantity    = Int(numbers.min() ?? 1)
            let cleanedName = cleanName(line)
            let confidence  = calculateConfidence(name: cleanedName, price: price, hasContext: true)

            items.append(ParsedItem(name: cleanedName, price: price, quantity: quantity, confidence: confidence))
            skipIndices.insert(idx + 1)
        }

        return items
    }

    // MARK: - Strategy 4: Tabular Items

    private static func extractTabularItems(from lines: [String]) -> [ParsedItem] {
        guard let regex = numberRegex else { return extractInlineItems(from: lines) }

        var items: [ParsedItem] = []
        let cleaned = cleanLines(lines)

        for line in cleaned {
            if shouldIgnoreLine(line) { continue }

            // Handle pipe-separated: "Item Name | 15.000"
            if line.contains("|") {
                let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 2 else { continue }
                let namePart  = parts[0]
                let pricePart = parts.last ?? ""
                let numbers   = extractAllNumbers(from: pricePart)
                if let price = numbers.last, price > 0, isValidItemName(namePart) {
                    let cleanedName = cleanName(namePart)
                    items.append(ParsedItem(name: cleanedName, price: price, quantity: 1, confidence: 0.8))
                }
                continue
            }

            // Fall back to inline for non-pipe tabular
            guard hasPrice(line, regex: regex, threshold: 500) else { continue }
            let nsLine  = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            guard let priceMatch = matches.last else { continue }
            let rawNumber  = nsLine.substring(with: priceMatch.range)
            let normalized = normalizeNumber(rawNumber)
            guard let price = Double(normalized), price > 0 else { continue }
            var textBefore = nsLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)
            textBefore     = stripLeadingQuantity(from: textBefore)
            if isValidItemName(textBefore) && textBefore.count >= 3 {
                let cleanedName = cleanName(textBefore)
                items.append(ParsedItem(name: cleanedName, price: price, quantity: 1, confidence: 0.75))
            }
        }

        return items
    }

    // MARK: - Strategy 5: Mixed Items

    private static func extractMixedItems(from lines: [String]) -> [ParsedItem] {
        let inline    = extractInlineItems(from: lines)
        let multiLine = extractMultiLineItems(from: lines)
        let quantity  = extractQuantityBasedItems(from: lines)

        var all = inline + multiLine + quantity
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
        return unique
    }

    // MARK: - NLP Helpers

    /// Detects the dominant language of the receipt (used for keyword selection)
    static func detectReceiptLanguage(from lines: [String]) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        let sample = lines.prefix(15).joined(separator: " ")
        recognizer.processString(sample)
        return recognizer.dominantLanguage ?? .english
    }

    /// Uses Part-of-Speech tagging to check if a name looks like a food item
    /// (food items are noun phrases — mostly nouns + adjectives)
    private static func isLikelyFoodItem(_ name: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = name

        var nounOrAdj = 0
        var total     = 0

        tagger.enumerateTags(
            in: name.startIndex..<name.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, _ in
            total += 1
            if tag == .noun || tag == .adjective || tag == .otherWord {
                nounOrAdj += 1
            }
            return true
        }

        // If tagger returns nothing (common for Indonesian), trust existing logic
        guard total > 0 else { return true }
        return Double(nounOrAdj) / Double(total) >= 0.4
    }

    /// Filters item list using NLP — removes lines that clearly aren't food names
    private static func nlpValidateItems(
        _ items: [(name: String, price: Double)]
    ) -> [(name: String, price: Double)] {
        return items.filter { item in
            // Very short names pass through
            guard item.name.count > 4 else { return true }
            // Skip NLP for single-word items (usually fine)
            let wordCount = item.name.split(separator: " ").count
            guard wordCount > 1 else { return true }
            return isLikelyFoodItem(item.name)
        }
    }

    // MARK: - Helpers

    private static func hasQuantityPattern(in lower: String) -> Bool {
        if lower.contains("@") || lower.contains(" x ") { return true }
        // "2x", "x2", "2pcs", "2 pcs", "2 buah", "qty", "2X"
        let patterns = ["\\d+\\s*[xX]\\s*\\d", "\\d+\\s*pcs", "\\d+\\s*buah", "qty\\s*:", "\\d+\\s*[xX]$"]
        for pattern in patterns {
            if lower.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        return false
    }

    private static func stripLeadingQuantity(from text: String) -> String {
        // Remove patterns like "2x ", "2 x ", "2pcs " from start
        let patterns = ["^\\d+\\s*[xX]\\s+", "^\\d+\\s+pcs\\s+", "^\\d+\\s+buah\\s+"]
        var result = text
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func cleanLines(_ lines: [String]) -> [String] {
        return lines
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                let lower = line.lowercased()
                return !(lower == "rp" || lower == "rp." || lower == "idr" ||
                         lower == "idr." || lower == "$" || lower == "rp:" || lower == "idr:")
            }
    }

    private static func shouldIgnoreLine(_ line: String, language: NLLanguage = .undetermined) -> Bool {
        let lower    = line.lowercased()
        let keywords = language == .indonesian ? ignoreKeywordsID :
                       language == .english     ? ignoreKeywordsEN : ignoreKeywords
        return keywords.contains(where: { lower.contains($0) })
    }

    private static func isValidItemName(_ text: String) -> Bool {
        guard text.count >= 2 else { return false }
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let digits  = text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        return letters >= 2 && letters >= digits
    }

    private static func cleanName(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let currencyPatterns = ["Rp\\.?", "IDR\\.?", "\\$", "USD", "€", "EUR"]
        for pattern in currencyPatterns {
            cleaned = cleaned.replacingOccurrences(of: "\\s*\(pattern)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
            cleaned = cleaned.replacingOccurrences(of: "^\\s*\(pattern)\\s*", with: "", options: [.regularExpression, .caseInsensitive])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func hasPrice(_ line: String, regex: NSRegularExpression, threshold: Double) -> Bool {
        let nsLine  = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        guard let match = matches.last else { return false }
        let rawNumber  = nsLine.substring(with: match.range)
        let normalized = normalizeNumber(rawNumber)
        guard let num  = Double(normalized) else { return false }
        let lower = line.lowercased()
        return num >= threshold || lower.contains("rp") || lower.contains("idr")
    }

    private static func getTextBeforePrice(_ line: String, regex: NSRegularExpression) -> String {
        let nsLine  = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        guard let priceMatch = matches.last else { return "" }
        return nsLine.substring(to: priceMatch.range.location).trimmingCharacters(in: .whitespaces)
    }

    private static func extractAllNumbers(from line: String) -> [Double] {
        guard let regex = numberRegex else { return [] }
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        return matches.compactMap { match in
            let raw        = nsLine.substring(with: match.range)
            let normalized = normalizeNumber(raw)
            return Double(normalized)
        }
    }

    private static func normalizeNumber(_ raw: String) -> String {
        var cleaned    = raw.replacingOccurrences(of: " ", with: "")
        let separators = cleaned.filter { $0 == "." || $0 == "," }

        if separators.count > 1 {
            if let lastSep = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) {
                let lastIdx = cleaned.distance(from: cleaned.startIndex, to: lastSep)
                cleaned = cleaned.enumerated().map { idx, ch -> String in
                    if (ch == "." || ch == ",") && idx != lastIdx { return "" }
                    return ch == "," ? "." : String(ch)
                }.joined()
            }
        } else if let sep = separators.first, let sepIndex = cleaned.lastIndex(of: sep) {
            let digitsAfter = cleaned.distance(from: cleaned.index(after: sepIndex), to: cleaned.endIndex)
            if digitsAfter == 3 {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            }
        }
        return cleaned
    }

    private static func calculateConfidence(name: String, price: Double, hasContext: Bool) -> Double {
        var confidence: Double = 0.5
        if name.count >= 5  { confidence += 0.1 }
        if name.count >= 10 { confidence += 0.1 }
        if price >= 1000    { confidence += 0.1 }
        if price >= 10000   { confidence += 0.1 }
        if hasContext       { confidence += 0.1 }
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
