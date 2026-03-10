import Foundation

/// Claude API 批处理器
final class ClaudeBatchProcessor: Processor, @unchecked Sendable {
    private let model: String
    private let systemPrompt: String
    private let apiKey: String

    init(model: String, systemPrompt: String, apiKey: String) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.apiKey = apiKey
    }

    func process(captures: [CaptureData]) async throws -> [ProcessResult] {
        var results: [ProcessResult] = []

        for (index, capture) in captures.enumerated() {
            let result = try await processOne(capture: capture, captureId: index)
            results.append(result)
        }

        return results
    }

    private func processOne(capture: CaptureData, captureId: Int) async throws -> ProcessResult {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": capture.rawOCR]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        // 解析响应
        guard let content = response.content.first?.text else {
            return ProcessResult(captureId: captureId, name: nil, summary: nil, passed: false, reason: "No response", rawJson: nil)
        }

        // 尝试解析 JSON 响应
        if let jsonData = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            return ProcessResult(
                captureId: captureId,
                name: json["name"] as? String,
                summary: json["summary"] as? String,
                passed: json["passed"] as? Bool ?? false,
                reason: json["reason"] as? String,
                rawJson: content
            )
        }

        return ProcessResult(captureId: captureId, name: nil, summary: content, passed: false, reason: nil, rawJson: content)
    }
}

// MARK: - Claude API Response Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

private struct ContentBlock: Decodable {
    let type: String
    let text: String?
}
