//
//  ReceiptLayoutParser.swift
//  SplitBill
//
//  Column-aware local receipt parser — no AI, no network, no cost.
//
//  Printed receipts are tables: a narrow qty column on the left, item names
//  in the middle, prices right-aligned in their own column. Instead of
//  flattening OCR output into text lines and guessing "last number = price",
//  this parser keeps every word's bounding box, finds the price column by
//  clustering right edges, and reads each row as  qty | name | price.
//  It then verifies itself against the receipt's own printed subtotal/total
//  and reports a confidence score so callers can fall back when unsure.
//

import Foundation
import CoreGraphics

struct ReceiptLayoutParser {

    // MARK: - Types

    /// One OCR'd word with its Vision-normalized bounding box (origin bottom-left).
    struct Word {
        let text: String
        let box: CGRect
    }

    struct Receipt {
        var billName: String?
        var items: [(name: String, price: Double)] = []      // qty expanded into per-unit rows
        var adjustments: [(name: String, amount: Double)] = []
        var total: String?                                    // plain digits, e.g. "325600"
        var confidence: Double = 0                            // 0…1 — how well items reconcile with total
    }

    private struct Row {
        var words: [Word]                                     // sorted left → right after grouping
        var sumY: CGFloat
        var meanY: CGFloat { sumY / CGFloat(words.count) }
    }

    private struct ItemRow {
        let name: String
        let qty: Int
        let unitHint: Double?     // explicit "@ 25.000" unit price if printed
        let value: Double         // the number in the price column
    }

    private struct PriceColumn {
        let centerX: CGFloat
        let tolerance: CGFloat
    }

    // MARK: - Keywords

    private static let subtotalKeywords = ["subtotal", "sub total", "sub-total", "sub tot"]
    private static let totalKeywords    = [
        "grand total", "total bayar", "total pembayaran", "total tagihan",
        "amount due", "total due", "jumlah", "total"
    ]
    private static let paymentKeywords  = [
        "tunai", "cash", "kembali", "kembalian", "change", "payment", "bayar",
        "dibayar", "diterima", "debit", "kredit", "credit", "qris", "gopay",
        "ovo", "dana", "shopeepay", "linkaja", "visa", "mastercard", "kartu",
        "card", "edc", "approval", "batch", "trace"
    ]
    private static let chargeKeywords   = [
        "ppn", "pb1", "pb 1", "pajak", "tax", "vat", "service charge", "service",
        "layanan", "ongkir", "delivery", "pengiriman", "packaging", "kemasan",
        "rounding", "pembulatan", "tip", "gratuity", "biaya"
    ]
    private static let discountKeywords = [
        "diskon", "discount", "potongan", "promo", "voucher", "disc", "hemat"
    ]
    private static let noiseKeywords    = [
        "npwp", "kasir", "cashier", "meja", "table", "tanggal", "wifi",
        "terima kasih", "thank you", "print", "struk", "nota", "invoice",
        "receipt", "telp", "phone", "alamat", "jalan", "antrian", "queue",
        "pax", "guest", "anda hemat", "item", "qty"
    ]
    private static var allStopKeywords: [String] {
        subtotalKeywords + totalKeywords + paymentKeywords +
        chargeKeywords + discountKeywords + noiseKeywords
    }

    // MARK: - Public API

    /// Flattens word observations into top-to-bottom text lines
    /// (for SmartBillParser fallback and bill-name extraction).
    static func textLines(from words: [Word]) -> [String] {
        groupIntoRows(words)
            .map { $0.words.map(\.text).joined(separator: " ") }
            .filter { !$0.isEmpty }
    }

    static func parse(words: [Word]) -> Receipt {
        var receipt = Receipt()
        guard words.count >= 4 else { return receipt }

        let rows = groupIntoRows(words)
        receipt.billName = extractBillName(rows: rows)

        guard let column = detectPriceColumn(rows: rows) else {
            print("[LayoutParser] ⚠️ No price column detected")
            return receipt
        }

        // ── Classify rows top → bottom ───────────────────────────────────
        var itemRows: [ItemRow] = []
        var adjustments: [(name: String, amount: Double)] = []
        var subtotal: Double?
        var totalValue: Double?
        var sawTotal = false
        var pendingName: String?   // unpriced name line directly above a priced row

        for row in rows {
            guard let priced = extractPricedRow(row, column: column) else {
                // No price on this row — may be a wrapped item name for the next row
                let text = cleanedName(row.words.map(\.text).joined(separator: " "))
                pendingName = (isPlausibleName(text) && !matchesAny(text.lowercased(), allStopKeywords))
                    ? text : nil
                continue
            }

            var name = priced.name
            if name.filter(\.isLetter).count < 3, let donor = pendingName { name = donor }
            pendingName = nil
            let lower = name.lowercased()

            if matchesAny(lower, subtotalKeywords) {
                subtotal = abs(priced.value)
            } else if matchesAny(lower, totalKeywords) {
                if abs(priced.value) > (totalValue ?? 0) { totalValue = abs(priced.value) }
                sawTotal = true
            } else if matchesAny(lower, paymentKeywords) {
                continue
            } else if matchesAny(lower, noiseKeywords) {
                continue
            } else if matchesAny(lower, discountKeywords) {
                adjustments.append((name: cleanedName(name), amount: -abs(priced.value)))
            } else if matchesAny(lower, chargeKeywords) {
                adjustments.append((name: cleanedName(name), amount: priced.value))
            } else if sawTotal {
                continue           // below the total line lives payment junk
            } else if isPlausibleName(name), priced.value >= 100 {
                itemRows.append(ItemRow(name: cleanedName(name), qty: priced.qty,
                                        unitHint: priced.unitHint, value: priced.value))
            }
        }

        // ── Decide whether the price column holds line totals or unit prices ──
        // Use the receipt's own subtotal/total as the referee.
        let h1 = itemRows.reduce(0.0) { $0 + $1.value }                        // printed = line total
        let h2 = itemRows.reduce(0.0) { $0 + $1.value * Double($1.qty) }       // printed = unit price
        let adjSum = adjustments.reduce(0.0) { $0 + $1.amount }
        let anchor: Double? = subtotal ?? totalValue.map { $0 - adjSum }

        let useLineTotals: Bool
        if let a = anchor, a > 0, abs(h1 - h2) > 0.01 {
            useLineTotals = abs(h1 - a) <= abs(h2 - a)
        } else {
            useLineTotals = true   // Indonesian POS receipts usually print line totals
        }

        // ── Expand quantities into per-unit rows (assignable when splitting) ──
        for r in itemRows {
            let qty = max(1, r.qty)
            var unit = useLineTotals ? r.value / Double(qty) : r.value
            if let hint = r.unitHint, abs(hint * Double(qty) - (useLineTotals ? r.value : r.value * Double(qty))) < 1 {
                unit = hint
            }
            unit = (unit * 100).rounded() / 100
            if qty <= 20 {
                for _ in 0..<qty { receipt.items.append((name: r.name, price: unit)) }
            } else {
                // Implausible qty — keep one row with the full line value
                receipt.items.append((name: r.name, price: useLineTotals ? r.value : r.value * Double(qty)))
            }
        }
        receipt.adjustments = adjustments

        if let t = totalValue {
            receipt.total = String(Int(t))
        } else if let s = subtotal {
            receipt.total = String(Int(s + adjSum))
        }

        // ── Confidence: how well do items + adjustments explain the total? ──
        let chosenSum = useLineTotals ? h1 : h2
        if let a = anchor, a > 0 {
            receipt.confidence = max(0, 1 - min(1, abs(chosenSum - a) / a))
        } else {
            receipt.confidence = receipt.items.isEmpty ? 0 : 0.5
        }

        print("[LayoutParser] \(itemRows.count) item rows (\(receipt.items.count) units), "
              + "\(adjustments.count) adj, mode=\(useLineTotals ? "lineTotals" : "unitPrices"), "
              + "conf \(String(format: "%.2f", receipt.confidence))")
        return receipt
    }

    // MARK: - Row grouping (adaptive Y threshold)

    private static func groupIntoRows(_ words: [Word]) -> [Row] {
        guard !words.isEmpty else { return [] }
        let heights = words.map { $0.box.height }.sorted()
        let medianH = heights[heights.count / 2]
        let yTol = max(0.008, medianH * 0.55)

        var rows: [Row] = []
        for w in words.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let i = rows.indices.first(where: { abs(rows[$0].meanY - w.box.midY) < yTol }) {
                rows[i].words.append(w)
                rows[i].sumY += w.box.midY
            } else {
                rows.append(Row(words: [w], sumY: w.box.midY))
            }
        }
        for i in rows.indices {
            rows[i].words.sort { $0.box.minX < $1.box.minX }
        }
        return rows.sorted { $0.meanY > $1.meanY }
    }

    // MARK: - Price column detection

    private static func detectPriceColumn(rows: [Row]) -> PriceColumn? {
        // Right edge of the rightmost meaningful number on each row
        var edges: [CGFloat] = []
        for row in rows {
            if let w = row.words.last(where: { (numericValue(of: $0.text).map { abs($0) >= 100 }) ?? false }) {
                edges.append(w.box.maxX)
            }
        }
        guard edges.count >= 3 else { return nil }
        edges.sort()

        // Greedy 1-D clustering of right edges
        var clusters: [[CGFloat]] = []
        for e in edges {
            if let i = clusters.indices.last,
               case let mean = clusters[i].reduce(0, +) / CGFloat(clusters[i].count),
               e - mean < 0.045 {
                clusters[i].append(e)
            } else {
                clusters.append([e])
            }
        }

        // Best cluster: most members, sitting in the right half of the receipt
        var bestMean: CGFloat = 0
        var bestCount = 0
        for cluster in clusters {
            let sum: CGFloat = cluster.reduce(0, +)
            let mean: CGFloat = sum / CGFloat(cluster.count)
            guard mean > 0.5, cluster.count >= 3 else { continue }
            if cluster.count > bestCount || (cluster.count == bestCount && mean > bestMean) {
                bestCount = cluster.count
                bestMean  = mean
            }
        }
        guard bestCount > 0 else { return nil }

        return PriceColumn(centerX: bestMean, tolerance: 0.05)
    }

    // MARK: - Row → (qty, name, price)

    private static func extractPricedRow(
        _ row: Row, column: PriceColumn
    ) -> (name: String, qty: Int, unitHint: Double?, value: Double)? {

        // Price = rightmost numeric word whose right edge sits in the price column
        guard let priceIdx = row.words.indices.reversed().first(where: { i in
            let w = row.words[i]
            return abs(w.box.maxX - column.centerX) <= column.tolerance
                && numericValue(of: w.text) != nil
        }) else { return nil }
        guard let value = numericValue(of: row.words[priceIdx].text) else { return nil }

        var nameWords = Array(row.words[..<priceIdx])

        // Leading qty column: "2 Nasi …", "2x Nasi …"
        var qty = 1
        if let first = nameWords.first {
            let t = first.text
            if let q = Int(t), (1...99).contains(q), nameWords.count > 1 {
                qty = q
                nameWords.removeFirst()
                if let nxt = nameWords.first?.text.lowercased(), nxt == "x" || nxt == "×" {
                    nameWords.removeFirst()
                }
            } else if t.range(of: "^\\d{1,2}[xX]$", options: .regularExpression) != nil,
                      let q = Int(t.dropLast()), (1...99).contains(q) {
                qty = q
                nameWords.removeFirst()
            }
        }

        // Trailing "@ 25.000" / "x 25.000" unit-price notation before the price column
        var unitHint: Double?
        while let last = nameWords.last {
            let lt = last.text
            if lt == "@" || lt == "=" || lt == "×" || lt.lowercased() == "x" {
                nameWords.removeLast()
                continue
            }
            if let v = numericValue(of: lt), abs(v) >= 50 {
                unitHint = v
                nameWords.removeLast()
                continue
            }
            break
        }

        let name = nameWords.map(\.text).joined(separator: " ")
        return (name: name, qty: qty, unitHint: unitHint, value: value)
    }

    // MARK: - Bill name (largest plausible text near the top)

    private static func extractBillName(rows: [Row]) -> String? {
        var best: (name: String, score: CGFloat)?
        for row in rows.prefix(6) {
            let text = cleanedName(row.words.map(\.text).joined(separator: " "))
            let lower = text.lowercased()
            let letters = text.filter(\.isLetter).count
            let digits  = text.filter(\.isNumber).count
            guard letters >= 3, letters > digits, text.count >= 4 else { continue }
            guard !matchesAny(lower, allStopKeywords) else { continue }
            guard !lower.contains("jl."), !lower.contains("jalan") else { continue }
            guard numericValue(of: text) == nil else { continue }
            let height = row.words.map { $0.box.height }.max() ?? 0
            let score = height + CGFloat(min(letters, 24)) * 0.0005
            if best == nil || score > best!.score { best = (text, score) }
        }
        return best?.name
    }

    // MARK: - Helpers

    /// Word-boundary match for short keywords, substring match for long/phrase ones.
    private static func matchesAny(_ text: String, _ keywords: [String]) -> Bool {
        for k in keywords {
            if k.count <= 4 && !k.contains(" ") {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: k))\\b"
                if text.range(of: pattern, options: .regularExpression) != nil { return true }
            } else if text.contains(k) {
                return true
            }
        }
        return false
    }

    private static func isPlausibleName(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter).count
        let digits  = text.filter(\.isNumber).count
        return letters >= 2 && letters >= digits
    }

    private static func cleanedName(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t:;,.-*"))
    }

    /// Parses "36.000", "Rp 12.500", "1.250.000", "(10.000)", "-5.000", "36,5" → Double.
    /// Returns nil for anything that isn't a clean number.
    static func numericValue(of raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t:*=,;"))
        for prefix in ["Rp.", "Rp", "RP", "rp", "IDR", "idr"] where s.hasPrefix(prefix) {
            s.removeFirst(prefix.count)
            s = s.trimmingCharacters(in: .whitespaces)
        }

        var negative = false
        if s.hasPrefix("("), s.hasSuffix(")") {
            negative = true
            s = String(s.dropFirst().dropLast())
        }
        if s.hasPrefix("-") || s.hasPrefix("−") {
            negative = true
            s.removeFirst()
        }
        if s.hasPrefix("@") { s.removeFirst() }

        guard !s.isEmpty, s.count <= 13 else { return nil }
        guard s.range(of: "^\\d{1,3}([.,]\\d{3})+([.,]\\d{1,2})?$|^\\d+([.,]\\d{1,2})?$",
                      options: .regularExpression) != nil else { return nil }

        // Thousands vs decimal separators: a final group of exactly 3 digits
        // after a separator is a thousands group ("36.000" → 36000);
        // 1–2 digits is a decimal tail ("36,5" → 36.5).
        var numeric = s
        if let lastSep = s.lastIndex(where: { $0 == "." || $0 == "," }) {
            let digitsAfter = s.distance(from: s.index(after: lastSep), to: s.endIndex)
            if digitsAfter == 3 {
                numeric = s.replacingOccurrences(of: ".", with: "")
                           .replacingOccurrences(of: ",", with: "")
            } else {
                let lastPos = s.distance(from: s.startIndex, to: lastSep)
                var out = ""
                for (i, c) in s.enumerated() {
                    if c == "." || c == "," {
                        if i == lastPos { out.append(".") }
                    } else {
                        out.append(c)
                    }
                }
                numeric = out
            }
        }

        guard let v = Double(numeric) else { return nil }
        return negative ? -v : v
    }
}
