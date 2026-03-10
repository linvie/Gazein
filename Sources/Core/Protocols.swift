import Foundation
import AppKit

// MARK: - Trigger Protocol

/// 触发器协议 - 控制何时进行下一次捕获
protocol Trigger: Sendable {
    /// 执行触发动作（如模拟按键）
    @MainActor func fire() async throws

    /// 获取下次触发的间隔时间（毫秒）
    var intervalMs: Int { get }
}

// MARK: - Capture Protocol

/// 捕获协议 - 负责截取屏幕区域
protocol Capture: Sendable {
    /// 捕获指定区域的截图
    @MainActor func capture() async throws -> CaptureResult

    /// 检测内容是否发生变化
    func hasChanged(from previous: CaptureResult) -> Bool
}

struct CaptureResult: Sendable {
    let image: NSImage
    let timestamp: Date
    let imageHash: String
}

// MARK: - Extractor Protocol

/// 提取器协议 - 从截图中提取文本
protocol Extractor: Sendable {
    /// 从图像中提取文本
    func extract(from image: NSImage) async throws -> String
}

// MARK: - Writer Protocol

/// 写入器协议 - 将数据持久化
protocol Writer: Sendable {
    /// 写入捕获数据
    func write(_ capture: CaptureData) async throws
}

struct CaptureData: Sendable {
    let sessionId: String
    let seq: Int
    let rawOCR: String
    let screenshotPath: String?
    let capturedAt: Date
}

// MARK: - Processor Protocol

/// 处理器协议 - AI 批处理
protocol Processor: Sendable {
    /// 处理一批捕获数据
    func process(captures: [CaptureData]) async throws -> [ProcessResult]
}

struct ProcessResult: Sendable {
    let captureId: Int
    let name: String?
    let summary: String?
    let passed: Bool
    let reason: String?
    let rawJson: String?  // 完整的 AI JSON 响应
}

// MARK: - Exporter Protocol

/// 导出器协议 - 导出处理结果
protocol Exporter: Sendable {
    /// 导出结果到文件
    func export(results: [ProcessResult], to path: URL) async throws
}
