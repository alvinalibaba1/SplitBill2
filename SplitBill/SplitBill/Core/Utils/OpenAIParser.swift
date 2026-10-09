//
//  OpenAIParser.swift
//  SplitBill
//
//  Primary multimodal AI parser using OpenAI GPT-4o mini.
//  Sends receipt image directly to OpenAI Chat Completions API with detail "high".
//

import Foundation
import UIKit

struct OpenAIParser {

    typealias ParsedResult = GeminiParser.ParsedResult

    static let model = "gpt-4o-mini"

    enum OpenAIError: Error {
        case missingAPIKey
        case imageEncodingFailed
        case badResponse(Int, String)
        case noContent
    }

    // MARK: - Public API

    /// Sends the receipt image to GPT and returns structured data.
    /// Retries once after 2 s on transient errors before throwing.
    static func parse(image: UIImage) async throws -> ParsedResult {
        let key = Secrets.openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key != "YOUR_OPENAI_API_KEY_HERE" else {
            throw OpenAIError.missingAPIKey
        }

        let resized = image.normalizedUp().resizedForUpload(maxSide: 1024)
        guard let jpegData = resized.jpegData(compressionQuality: 0.75) else {
            throw OpenAIError.imageEncodingFailed
        }
        let base64 = jpegData.base64EncodedString()

        do {
            return try await sendRequest(base64: base64, apiKey: key)
        } catch OpenAIError.missingAPIKey {
            throw OpenAIError.missingAPIKey
        } catch let OpenAIError.badResponse(code, body) where code == 401 || code == 403 {
            // Bad auth / invalid key — fail immediately so fallback can take over
            throw OpenAIError.badResponse(code, body)
        } catch {
            print("[OpenAIParser] ⚠️ First attempt failed (\(error)) — retrying in 2 s")
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return try await sendRequest(base64: base64, apiKey: key)
        }
    }

    // MARK: - Request

    private static func sendRequest(base64: String, apiKey: String) async throws -> ParsedResult {
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "max_tokens": 4096,
            "response_format": ["type": "json_object"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": GeminiParser.receiptPrompt],
                    ["type": "image_url", "image_url": [
                        "url": "data:image/jpeg;base64,\(base64)",
                        "detail": "high"
                    ]]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[OpenAIParser] 🚀 Sending image to \(model)...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[OpenAIParser] ❌ HTTP \(code): \(bodyText.prefix(300))")
            throw OpenAIError.badResponse(code, bodyText)
        }

        guard
            let root    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text    = message["content"] as? String
        else {
            throw OpenAIError.noContent
        }

        print("[OpenAIParser] ✅ HTTP 200 — received response (\(data.count) bytes)")
        return try GeminiParser.parseReceiptPayload(text)
    }
}

// MARK: - UIImage helpers (file-scoped)

private extension UIImage {
    /// Redraws into a new bitmap with .up orientation, fixing EXIF rotation.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Resize so the longest side is ≤ maxSide, preserving aspect ratio.
    func resizedForUpload(maxSide: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard w > maxSide || h > maxSide else { return self }
        let scale   = maxSide / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
