import Foundation

/// 采集数据模型
/// (在 Protocols.swift 中已定义 CaptureData 和 ProcessResult)

// MARK: - Extensions

extension CaptureData {
    /// 从数据库记录创建
    init(from record: CaptureRecord) {
        self.sessionId = record.sessionId
        self.seq = record.seq
        self.rawOCR = record.rawOCR ?? ""
        self.screenshotPath = record.screenshot
        self.capturedAt = record.capturedAt
    }
}
