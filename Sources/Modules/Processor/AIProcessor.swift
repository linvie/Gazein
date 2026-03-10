import Foundation

/// 通用 AI 处理器 - 支持多种 OpenAI 兼容 API
final class AIProcessor: Processor, @unchecked Sendable {
    private let provider: AIProvider
    private let model: String
    private let systemPrompt: String
    private let apiKey: String

    /// AI 服务提供商配置
    enum AIProvider: String {
        case deepseek
        case kimi
        case moonshot  // 等同于 kimi
        case openai
        case custom

        var baseURL: String {
            switch self {
            case .deepseek:
                return "https://api.deepseek.com/v1/chat/completions"
            case .kimi, .moonshot:
                return "https://api.moonshot.cn/v1/chat/completions"
            case .openai:
                return "https://api.openai.com/v1/chat/completions"
            case .custom:
                return ""
            }
        }

        var envKey: String {
            switch self {
            case .deepseek:
                return "DEEPSEEK_API_KEY"
            case .kimi, .moonshot:
                return "MOONSHOT_API_KEY"
            case .openai:
                return "OPENAI_API_KEY"
            case .custom:
                return "AI_API_KEY"
            }
        }

        var defaultModel: String {
            switch self {
            case .deepseek:
                return "deepseek-chat"
            case .kimi, .moonshot:
                return "moonshot-v1-8k"
            case .openai:
                return "gpt-4o-mini"
            case .custom:
                return "default"
            }
        }
    }

    init(provider: AIProvider, model: String? = nil, systemPrompt: String, apiKey: String, customBaseURL: String? = nil) {
        self.provider = provider
        self.model = model ?? provider.defaultModel
        self.systemPrompt = systemPrompt
        self.apiKey = apiKey
    }

    /// 从配置创建处理器
    static func fromConfig(
        providerName: String?,
        model: String?,
        systemPrompt: String,
        customBaseURL: String? = nil
    ) -> AIProcessor? {
        let providerName = providerName?.lowercased() ?? "deepseek"
        let provider = AIProvider(rawValue: providerName) ?? .deepseek

        // 获取 API Key
        guard let apiKey = ProcessInfo.processInfo.environment[provider.envKey], !apiKey.isEmpty else {
            print("[AIProcessor] 未找到环境变量: \(provider.envKey)")
            return nil
        }

        return AIProcessor(
            provider: provider,
            model: model,
            systemPrompt: systemPrompt,
            apiKey: apiKey,
            customBaseURL: customBaseURL
        )
    }

    func process(captures: [CaptureData]) async throws -> [ProcessResult] {
        var results: [ProcessResult] = []
        let total = captures.count

        print("[AIProcessor] 使用 \(provider.rawValue) / \(model)")
        print("[AIProcessor] 开始处理 \(total) 条数据...")

        for (index, capture) in captures.enumerated() {
            let num = index + 1
            let preview = String(capture.rawOCR.prefix(50)).replacingOccurrences(of: "\n", with: " ")
            print("[AIProcessor] [\(num)/\(total)] 处理中: \(preview)...")

            let startTime = Date()
            let result = try await processOne(capture: capture, captureId: index)
            let duration = Date().timeIntervalSince(startTime)

            // 显示结果
            let passedStr = result.passed ? "✓ 通过" : "✗ 不通过"
            let name = result.name ?? "未知"
            print("[AIProcessor] [\(num)/\(total)] 完成 (\(String(format: "%.1f", duration))s) - \(name): \(passedStr)")

            results.append(result)

            // 避免请求过快
            if index < captures.count - 1 {
                print("[AIProcessor] 等待 0.5s...")
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        print("[AIProcessor] 全部处理完成!")
        return results
    }

    private func processOne(capture: CaptureData, captureId: Int) async throws -> ProcessResult {
        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                return try await callAPI(capture: capture, captureId: captureId, attempt: attempt)
            } catch let error as AIProcessorError {
                lastError = error

                // 检查是否是可重试的错误
                if case .apiError(let statusCode, _) = error {
                    if statusCode == 429 || statusCode >= 500 {
                        // 服务器过载或错误，等待后重试
                        let waitTime = attempt * 5  // 5s, 10s, 15s
                        print("[AIProcessor]   ⚠️ 服务器繁忙 (HTTP \(statusCode))，\(waitTime)秒后重试 (\(attempt)/\(maxRetries))...")
                        try await Task.sleep(nanoseconds: UInt64(waitTime) * 1_000_000_000)
                        continue
                    }
                }
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError ?? AIProcessorError.noResponse
    }

    private func callAPI(capture: CaptureData, captureId: Int, attempt: Int) async throws -> ProcessResult {
        guard let url = URL(string: provider.baseURL) else {
            throw AIProcessorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120  // 增加超时时间

        // 某些模型有特殊的 temperature 要求
        let temperature: Double = model.contains("k2") ? 1.0 : 0.3

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": capture.rawOCR]
            ]
        ]

        // kimi-k2 系列模型只允许 temperature=1，不传这个参数
        if !model.contains("k2") {
            body["temperature"] = temperature
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if attempt > 1 {
            print("[AIProcessor]   → 重试调用 API (第\(attempt)次)...")
        } else {
            print("[AIProcessor]   → 调用 API...")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        print("[AIProcessor]   ← 收到响应")

        // 检查 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIProcessorError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
            }
        }

        let apiResponse = try JSONDecoder().decode(OpenAICompatibleResponse.self, from: data)

        // 解析响应
        guard let content = apiResponse.choices.first?.message.content else {
            return ProcessResult(captureId: captureId, name: nil, summary: nil, passed: false, reason: "No response", rawJson: nil)
        }

        return parseResponse(content: content, captureId: captureId)
    }

    private func parseResponse(content: String, captureId: Int) -> ProcessResult {
        // 尝试提取 JSON
        let jsonContent = extractJSON(from: content)

        if let jsonData = jsonContent.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            // 尝试从 screening 嵌套结构提取 passed 和 reason
            var passed = json["passed"] as? Bool ?? false
            var reason = json["reason"] as? String

            if let screening = json["screening"] as? [String: Any] {
                passed = screening["passed"] as? Bool ?? passed
                reason = screening["reason"] as? String ?? reason
            }

            // 尝试提取 summary (兼容多种格式)
            let summary = json["summary"] as? String
                ?? json["position"] as? String
                ?? json["applied_position"] as? String

            return ProcessResult(
                captureId: captureId,
                name: json["name"] as? String,
                summary: summary,
                passed: passed,
                reason: reason,
                rawJson: jsonContent  // 保存完整 JSON
            )
        }

        // 如果无法解析 JSON，将整个响应作为 summary
        return ProcessResult(
            captureId: captureId,
            name: nil,
            summary: content,
            passed: true,
            reason: nil,
            rawJson: content
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

// MARK: - Response Models

private struct OpenAICompatibleResponse: Decodable {
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

enum AIProcessorError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case noResponse
    case missingAPIKey(envVar: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .noResponse:
            return "No response from API"
        case .missingAPIKey(let envVar):
            return "Missing API key: \(envVar)"
        }
    }
}
