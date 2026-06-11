//
//  GeminiParser.swift
//  SplitBill
//
//  Sends the receipt IMAGE directly to Gemini 2.0 Flash (multimodal).
//  Free tier: 15 RPM · 1 500 RPD
//

import Foundation
import UIKit

struct GeminiParser {

    // MARK: - Result

    struct ParsedResult {
        let billName: String?
        let items: [(name: String, price: Double)]
        let adjustments: [(name: String, amount: Double)]
        let total: String?
        let usedAI: Bool
    }

    // MARK: - Errors

    enum GeminiError: Error {
        case imageEncodingFailed
        case badResponse(Int, String)
        case noContent
        case jsonParseFailure(String)
    }

    // MARK: - Public API

    /// Sends the receipt image to Gemini and returns structured data.
    /// Retries once after 2 s on any error before throwing.
    static func parse(image: UIImage) async throws -> ParsedResult {
        // Normalize EXIF orientation, then resize to 1024px longest side
        // (higher res helps small/dense receipt fonts; still well within request limits)
        let resized = image.normalizedOrientation().resizedForGemini(maxSide: 1024)

        guard let jpegData = resized.jpegData(compressionQuality: 0.75) else {
            throw GeminiError.imageEncodingFailed
        }
        let base64 = jpegData.base64EncodedString()

        do {
            return try await sendRequest(base64: base64)
        } catch {
            print("[GeminiParser] ⚠️ First attempt failed (\(error)) — retrying in 2 s")
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return try await sendRequest(base64: base64)
        }
    }

    // MARK: - Request

    private static func sendRequest(base64: String) async throws -> ParsedResult {
        let prompt = """
        You are an expert receipt parser. You handle ALL receipt types:
        restaurants, cafés, warung, grocery/minimarket, retail, and delivery-app
        receipts (GoFood, GrabFood, ShopeeFood), in Indonesian or English.

        Read the image carefully and extract EVERY ordered line item with its quantity.

        Return ONLY valid JSON — no markdown, no commentary — exactly this shape:
        {
          "billName": "Restaurant or Store Name",
          "items": [
            {"name": "Nasi Goreng", "qty": 2, "price": 35000},
            {"name": "Es Teh",      "qty": 1, "price": 8000}
          ],
          "adjustments": [
            {"name": "PPN 11%",         "amount": 5500},
            {"name": "Service Charge",  "amount": 3000},
            {"name": "Discount",        "amount": -10000}
          ],
          "total": "49500"
        }

        NUMBERS
        - every price/amount is a plain integer in rupiah — no "Rp", no thousand dots, no commas.
          "Rp 35.000" → 35000 · "12.500" → 12500 · "1.250.000" → 1250000
        - "price" is the UNIT price for ONE of that item, NOT the line total.
          "2x Nasi Goreng  70.000" → {"name":"Nasi Goreng","qty":2,"price":35000}
          "3 Kopi @25.000  75.000" → {"name":"Kopi","qty":3,"price":25000}
        - if only a line total is printed and qty > 1, divide the line total by qty to get the unit price.

        ITEMS — what counts as an item
        - a real product/dish the customer ordered. Repeated prices are FINE and EXPECTED
          (e.g. three coffees all 25000) — never drop or merge items just because prices match.
        - item names can wrap onto two lines — join them into one name.
        - modifiers / add-ons printed under an item ("+ Extra Cheese 5.000", "- No Onion",
          "Topping: Boba 7.000", "Less Ice") belong to that parent item: add a priced add-on
          to the parent's unit price, and ignore zero-price notes like "Less Ice"/"No Onion".
        - grocery/weighted lines ("Apel 0,5 kg x 30.000 = 15.000") → name "Apel", qty 1, price 15000.
        - keep the language exactly as printed; do not translate item names.

        ADJUSTMENTS — never put these in items
        - tax (PPN, VAT, Pajak, PB1), service charge / biaya layanan, packaging / biaya kemasan,
          delivery / ongkir / biaya pengiriman, tip / gratuity, rounding / pembulatan.
        - discounts, promo, voucher, "Diskon", "Potongan" → NEGATIVE amount.
        - delivery-app fees (ongkir, biaya layanan, biaya penanganan) → adjustments.

        SKIP entirely (never an item, never an adjustment)
        - subtotal / sub-total — it is a running sum, not a charge.
        - store address, phone, cashier, date/time, table no., queue no., thank-you text.
        - payment rows: TUNAI, CASH, DEBIT, KREDIT, KEMBALI(AN), CHANGE, QRIS, GoPay, OVO, Dana,
          ShopeePay, card brand (Visa/Mastercard/GPN), approval/ref/merchant/terminal IDs.

        OTHER FIELDS
        - billName = the merchant name at the very top (use the brand line, not a tagline).
        - total = the final amount paid (Grand Total / Total Bayar / Total Pembayaran).
        - any field you cannot read → null.

        SELF-CHECK before answering
        - confirm (sum of item unit_price × qty) + (sum of adjustments) ≈ total.
          If it is far off, re-read the image — you likely mis-typed a price or missed an item.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    ["text": prompt]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.0,
                "maxOutputTokens": 4096
            ]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(Secrets.geminiAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[GeminiParser] ❌ HTTP \(code): \(body.prefix(300))")
            throw GeminiError.badResponse(code, body)
        }

        print("[GeminiParser] ✅ HTTP 200 — parsing response (\(data.count) bytes)")
        return try parseResponse(data)
    }

    // MARK: - Response Parsing

    private static func parseResponse(_ data: Data) throws -> ParsedResult {
        guard
            let root       = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let first      = candidates.first,
            let content    = first["content"] as? [String: Any],
            let parts      = content["parts"] as? [[String: Any]],
            let text       = parts.first?["text"] as? String
        else {
            throw GeminiError.noContent
        }

        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let jsonData = clean.data(using: .utf8),
            let json     = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw GeminiError.jsonParseFailure(text)
        }

        let billName: String? = json["billName"] as? String

        var items: [(name: String, price: Double)] = []
        if let rawItems = json["items"] as? [[String: Any]] {
            for item in rawItems {
                guard let name = item["name"] as? String, !name.isEmpty else { continue }
                guard !isPaymentRow(name) else {
                    print("[GeminiParser] 🚫 Filtered payment row: \(name)")
                    continue
                }
                guard !isAdjustmentRow(name) else {
                    print("[GeminiParser] 🚫 Filtered adjustment row from items: \(name)")
                    continue
                }

                // Unit price for ONE of this item
                let unitPrice = doubleFrom(item["price"])
                guard unitPrice > 0 else { continue }

                // Expand quantity into individual assignable rows (caps at 50 for safety)
                let qty = max(1, min(50, Int(doubleFrom(item["qty"]))))
                for _ in 0..<qty {
                    items.append((name: name, price: unitPrice))
                }
            }
        }

        var adjustments: [(name: String, amount: Double)] = []
        if let rawAdj = json["adjustments"] as? [[String: Any]] {
            for adj in rawAdj {
                guard let name = adj["name"] as? String, !name.isEmpty else { continue }
                let amount = doubleFrom(adj["amount"])
                adjustments.append((name: name, amount: amount))
            }
        }

        let total: String? = {
            if let t = json["total"] as? String, !t.isEmpty, t != "null" { return t }
            if let t = json["total"] as? Double { return String(Int(t)) }
            if let t = json["total"] as? Int    { return String(t) }
            return nil
        }()

        // Reconciliation sanity-check (non-destructive — just logs confidence)
        let itemsSum = items.reduce(0) { $0 + $1.price }
        let adjSum   = adjustments.reduce(0) { $0 + $1.amount }
        if let totalStr = total, let totalVal = Double(totalStr.filter { $0.isNumber || $0 == "." }) {
            let expected = itemsSum + adjSum
            let diff = abs(expected - totalVal)
            // Allow small rounding gap, or a ~12% gap (untyped tax/service the model put under total)
            let tolerance = max(1000, totalVal * 0.12)
            if diff <= tolerance {
                print("[GeminiParser] ✅ Reconciled: items \(Int(itemsSum)) + adj \(Int(adjSum)) ≈ total \(Int(totalVal))")
            } else {
                print("[GeminiParser] ⚠️ Reconcile gap \(Int(diff)) — items \(Int(itemsSum)) + adj \(Int(adjSum)) vs total \(Int(totalVal)). User should verify.")
            }
        }

        print("[GeminiParser] 📋 Parsed \(items.count) item rows, \(adjustments.count) adjustments")

        return ParsedResult(
            billName:    billName,
            items:       items,
            adjustments: adjustments,
            total:       total,
            usedAI:      true
        )
    }

    // MARK: - Helpers

    // MARK: - Payment Row Filter

    /// Returns true if the item name looks like a payment/card row, not a food/product item.
    private static func isPaymentRow(_ name: String) -> Bool {
        let lower = name.lowercased()

        // Exact or strong matches — payment keywords
        let paymentKeywords: [String] = [
            "kartu debit", "kartu kredit", "debit card", "credit card",
            "tunai", "cash", "kembali", "kembalian", "change", "kembalian",
            "visa", "mastercard", "maestro", "gpn", "jcb", "amex", "american express",
            "bca", "bni", "bri", "mandiri", "bsi", "cimb", "danamon", "permata", "ocbc",
            "gopay", "ovo", "dana", "shopeepay", "linkaja", "qris",
            "approval", "edc", "terminal id", "merchant id", "trace",
            "reference", "no ref", "no. ref", "no.ref",
            "pembayaran", "metode bayar", "payment method",
            "debit", "kredit"
        ]

        for keyword in paymentKeywords {
            // For short keywords like "debit"/"kredit", match whole word to avoid false positives
            if keyword.count <= 6 {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                if (try? NSRegularExpression(pattern: pattern))?.firstMatch(
                    in: lower, range: NSRange(lower.startIndex..., in: lower)
                ) != nil { return true }
            } else {
                if lower.contains(keyword) { return true }
            }
        }
        return false
    }

    /// Returns true if the item name is a tax/fee/adjustment row, not an ordered product.
    private static func isAdjustmentRow(_ name: String) -> Bool {
        let lower = name.lowercased()
        let adjustmentKeywords: [String] = [
            "ppn", "vat", "tax", "pajak",
            "service charge", "service fee", "biaya layanan", "biaya servis",
            "subtotal", "sub total", "sub-total",
            "diskon", "discount",
            "packaging", "kemasan", "biaya kemasan",
            "ongkir", "delivery fee", "biaya pengiriman",
            "tip", "gratuity",
            "rounding", "pembulatan"
        ]
        for keyword in adjustmentKeywords {
            if lower.contains(keyword) { return true }
        }
        return false
    }

    private static func doubleFrom(_ value: Any?) -> Double {
        if let v = value as? Double  { return v }
        if let v = value as? Int     { return Double(v) }
        if let v = value as? String  {
            let stripped = v.filter { $0.isNumber || $0 == "." || $0 == "-" }
            return Double(stripped) ?? 0
        }
        return 0
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    /// Redraws the image into a new bitmap with .up orientation, fixing EXIF rotation.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Resize so the longest side is ≤ maxSide, preserving aspect ratio.
    func resizedForGemini(maxSide: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > maxSide || h > maxSide else { return self }
        let scale   = maxSide / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
