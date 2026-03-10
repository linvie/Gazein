import Foundation

/// DeepSeek API 批处理器 (OpenAI 兼容格式)
final class DeepSeekProcessor: Processor, @unchecked Sendable {
    private let model: String
    private let systemPrompt: String
    private let apiKey: String
    private let baseURL: String

    init(
        model: String = "deepseek-chat",
        systemPrompt: String,
        apiKey: String,
        baseURL: String = "https://api.deepseek.com/v1/chat/completions"
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func process(captures: [CaptureData]) async throws -> [ProcessResult] {
        var results: [ProcessResult] = []

        for (index, capture) in captures.enumerated() {
            let result = try await processOne(capture: capture, captureId: index)
            results.append(result)

            // 避免请求过快
            if index < captures.count - 1 {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }

        return results
    }

    private func processOne(capture: CaptureData, captureId: Int) async throws -> ProcessResult {
        guard let url = URL(string: baseURL) else {
            throw ProcessorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": capture.rawOCR]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ProcessorError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
            }
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        // 解析响应
        guard let content = apiResponse.choices.first?.message.content else {
            return ProcessResult(captureId: captureId, name: nil, summary: nil, passed: false, reason: "No response")
        }

        // 尝试解析 JSON 响应
        return parseResponse(content: content, captureId: captureId)
    }

    private func parseResponse(content: String, captureId: Int) -> ProcessResult {
        // 尝试提取 JSON (支持 markdown 代码块)
        let jsonContent = extractJSON(from: content)

        if let jsonData = jsonContent.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            return ProcessResult(
                captureId: captureId,
                name: json["name"] as? String,
                summary: json["summary"] as? String,
                passed: json["passed"] as? Bool ?? false,
                reason: json["reason"] as? String
            )
        }

        // 如果无法解析 JSON，将整个响应作为 summary
        return ProcessResult(
            captureId: captureId,
            name: nil,
            summary: content,
            passed: true,
            reason: nil
        )
    }

    private func extractJSON(from content: String) -> String {
        // 尝试从 markdown 代码块中提取 JSON
        let patterns = [
            "```json\\s*\\n([\\s\\S]*?)\\n```",
            "```\\s*\\n([\\s\\S]*?)\\n```",
            "\\{[\\s\\S]*\\}"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
                if match.numberOfRanges > 1 {
                    if let range = Range(match.range(at: 1), in: content) {
                        return String(content[range])
                    }
                } else if let range = Range(match.range, in: content) {
                    return String(content[range])
                }
            }
        }

        return content
    }
}

// MARK: - OpenAI Compatible Response Models

private struct OpenAIResponse: Decodable {
    let id: String?
    let choices: [Choice]
    let usage: Usage?
}

private struct Choice: Decodable {
    let index: Int
    let message: Message
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

private struct Message: Decodable {
    let role: String
    let content: String?
}

private struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Errors

enum ProcessorError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .noResponse:
            return "No response from API"
        }
    }
}
