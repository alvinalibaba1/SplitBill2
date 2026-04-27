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
        // Normalize EXIF orientation, then resize to 768px longest side
        let resized = image.normalizedOrientation().resizedForGemini(maxSide: 768)

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
        You are an expert receipt parser for Indonesian and English receipts.
        Analyze this receipt image carefully and extract ALL ordered items.

        Return ONLY valid JSON — no markdown, no explanation, exactly this structure:
        {
          "billName": "Restaurant or Store Name",
          "items": [
            {"name": "Item Name", "price": 35000},
            {"name": "Another Item", "price": 15000}
          ],
          "adjustments": [
            {"name": "PPN 11%", "amount": 5500},
            {"name": "Service Charge", "amount": 3000},
            {"name": "Discount", "amount": -10000}
          ],
          "total": "49500"
        }

        Rules:
        - prices and amounts are plain integers (no Rp, no dots, no commas) — e.g. 35000 not "Rp 35.000"
        - if quantity shown (e.g. "2x Nasi Goreng 70.000"), split into individual price: 35000
        - discounts = negative amounts
        - adjustments = tax, service charge, discount, tip, packaging fee — NOT the items themselves
        - billName = the restaurant/store name at the top of the receipt
        - total = the final amount paid (Grand Total / Total Bayar / Total)
        - skip: address, phone, cashier name, date/time, table number, thank-you messages
        - if a field is unknown use null
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
                "maxOutputTokens": 2048
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
                let price = doubleFrom(item["price"])
                if price > 0 { items.append((name: name, price: price)) }
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

        return ParsedResult(
            billName:    billName,
            items:       items,
            adjustments: adjustments,
            total:       total,
            usedAI:      true
        )
    }

    // MARK: - Helpers

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
