import Foundation
import AppKit
import ScreenCaptureKit
import CryptoKit

/// 区域截图捕获器
final class RegionCapture: Capture {
    private let region: CGRect
    private let changeThreshold: Double

    init(region: CGRect, changeThreshold: Double = 0.05) {
        self.region = region
        self.changeThreshold = changeThreshold
    }

    func capture() async throws -> CaptureResult {
        // 使用 ScreenCaptureKit 截取指定区域
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = region
        config.width = Int(region.width)
        config.height = Int(region.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let image = try await captureImage(filter: filter, config: config)
        let hash = computeHash(image: image)

        return CaptureResult(
            image: image,
            timestamp: Date(),
            imageHash: hash
        )
    }

    func hasChanged(from previous: CaptureResult) -> Bool {
        // 基于哈希比较，这里简化处理
        // 实际实现应该计算汉明距离或像素差异比例
        return true // TODO: 实现变化检测
    }

    private func captureImage(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> NSImage {
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func computeHash(image: NSImage) -> String {
        guard let tiffData = image.tiffRepresentation else {
            return ""
        }
        let hash = SHA256.hash(data: tiffData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum CaptureError: Error {
    case noDisplayFound
    case captureFailure
}
