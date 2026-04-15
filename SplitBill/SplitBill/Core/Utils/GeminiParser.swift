//
//  GeminiParser.swift
//  SplitBill
//
//  Uses Gemini 2.0 Flash (free tier: 15 RPM, 1500 RPD) to extract
//  structured receipt data from raw OCR lines.
//

import Foundation

struct GeminiParser {

    // MARK: - Result

    struct ParsedResult {
        let billName: String?
        let items: [(name: String, price: Double)]
        let adjustments: [(name: String, amount: Double)]
        let total: String?
    }

    // MARK: - Errors

    enum GeminiError: Error {
        case badResponse(Int)
        case noContent
        case jsonParseFailure(String)
    }

    // MARK: - Public API

    /// Sends OCR lines to Gemini and returns structured receipt data.
    static func parse(lines: [String]) async throws -> ParsedResult {
        let receipt = lines.joined(separator: "\n")

        let prompt = """
        You are a receipt parser. Given raw OCR text from a food/restaurant receipt, extract:
        1. Bill/restaurant name (first meaningful line, not a generic word like "RECEIPT" or "INVOICE")
        2. All ordered items with their prices (in the original currency amount, as a plain number e.g. 35000)
        3. Any adjustments like tax, service charge, discount (with positive or negative amounts)
        4. The grand total (plain number)

        Return ONLY valid JSON in this exact format (no markdown, no explanation):
        {
          "billName": "Restaurant Name or null",
          "items": [
            {"name": "Item Name", "price": 35000},
            {"name": "Another Item", "price": 15000}
          ],
          "adjustments": [
            {"name": "Tax 10%", "amount": 5000},
            {"name": "Service Charge", "amount": 3000}
          ],
          "total": "58000"
        }

        Rules:
        - prices and amounts must be plain numbers (no currency symbols, no dots/commas)
        - if a value is unknown return null
        - ignore quantity multipliers in item names (e.g. "2x Nasi Goreng" → name: "Nasi Goreng")
        - discounts should have negative amounts
        - skip header/footer lines (address, phone, cashier, date, thank you messages)

        Receipt OCR text:
        \(receipt)
        """

        // Build request body
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(Secrets.geminiAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.badResponse(code)
        }

        return try parseResponse(data)
    }

    // MARK: - Response Parsing

    private static func parseResponse(_ data: Data) throws -> ParsedResult {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.noContent
        }

        // The model may wrap JSON in markdown code fences — strip them
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let jsonData = clean.data(using: .utf8),
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            throw GeminiError.jsonParseFailure(text)
        }

        // --- billName ---
        let billName = json["billName"] as? String

        // --- items ---
        var items: [(name: String, price: Double)] = []
        if let rawItems = json["items"] as? [[String: Any]] {
            for item in rawItems {
                guard let name = item["name"] as? String, !name.isEmpty else { continue }
                let price: Double
                if let p = item["price"] as? Double { price = p }
                else if let p = item["price"] as? Int { price = Double(p) }
                else if let p = item["price"] as? String { price = Double(p.filter { $0.isNumber || $0 == "." }) ?? 0 }
                else { continue }
                if price > 0 { items.append((name: name, price: price)) }
            }
        }

        // --- adjustments ---
        var adjustments: [(name: String, amount: Double)] = []
        if let rawAdj = json["adjustments"] as? [[String: Any]] {
            for adj in rawAdj {
                guard let name = adj["name"] as? String, !name.isEmpty else { continue }
                let amount: Double
                if let a = adj["amount"] as? Double { amount = a }
                else if let a = adj["amount"] as? Int { amount = Double(a) }
                else if let a = adj["amount"] as? String { amount = Double(a.filter { $0.isNumber || $0 == "." || $0 == "-" }) ?? 0 }
                else { continue }
                adjustments.append((name: name, amount: amount))
            }
        }

        // --- total ---
        let total: String?
        if let t = json["total"] as? String, !t.isEmpty, t != "null" {
            total = t
        } else if let t = json["total"] as? Double {
            total = String(Int(t))
        } else if let t = json["total"] as? Int {
            total = String(t)
        } else {
            total = nil
        }

        return ParsedResult(
            billName: billName,
            items: items,
            adjustments: adjustments,
            total: total
        )
    }
}
