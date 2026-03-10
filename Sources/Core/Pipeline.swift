import Foundation
import AppKit

/// 管道调度器 - 协调各模块的执行
@MainActor
final class Pipeline: Sendable {
    private let trigger: Trigger
    private let capture: Capture
    private let extractor: Extractor
    private let writer: Writer

    private var isRunning = false
    private var sessionManager: SessionManager
    private var lastCaptureResult: CaptureResult?
    private var lastOCRText: String?  // 用于 OCR 去重

    // 截图保存设置
    private let saveScreenshots: Bool
    private let screenshotDir: String

    init(
        trigger: Trigger,
        capture: Capture,
        extractor: Extractor,
        writer: Writer,
        sessionManager: SessionManager,
        saveScreenshots: Bool = true,
        screenshotDir: String = "~/Gazein/screenshots"
    ) {
        self.trigger = trigger
        self.capture = capture
        self.extractor = extractor
        self.writer = writer
        self.sessionManager = sessionManager
        self.saveScreenshots = saveScreenshots
        self.screenshotDir = NSString(string: screenshotDir).expandingTildeInPath
    }

    /// 开始采集循环
    func start() async {
        guard !isRunning else { return }
        isRunning = true

        sessionManager.startNewSession()
        lastOCRText = nil  // 重置 OCR 去重
        lastCaptureResult = nil  // 重置截图对比
        let sessionId = sessionManager.currentSessionId
        print("[Pipeline] 会话开始: \(sessionId.prefix(8))...")

        // 确保截图目录存在
        if saveScreenshots {
            try? FileManager.default.createDirectory(
                atPath: screenshotDir,
                withIntermediateDirectories: true
            )
            print("[Pipeline] 截图保存目录: \(screenshotDir)")
        }

        while isRunning {
            do {
                let seq = sessionManager.nextSeq()
                print("\n[Pipeline] === 第 \(seq) 次采集 ===")

                // 1. 触发动作（模拟按键等）
                let triggerStart = Date()
                try await trigger.fire()
                print("[Pipeline] 触发按键完成")

                // 2. 等待指定间隔
                let intervalMs = trigger.intervalMs
                print("[Pipeline] 等待 \(intervalMs)ms...")
                try await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)

                // 3. 捕获截图
                let captureStart = Date()
                let captureResult = try await capture.capture()
                let captureDuration = Date().timeIntervalSince(captureStart) * 1000
                print("[Pipeline] 截图完成 (\(String(format: "%.0f", captureDuration))ms)")

                // 4. 保存截图结果用于后续变化检测
                lastCaptureResult = captureResult

                // 5. 保存截图
                var screenshotPath: String? = nil
                if saveScreenshots {
                    screenshotPath = saveScreenshot(captureResult.image, seq: seq)
                    if let path = screenshotPath {
                        print("[Pipeline] 截图已保存: \(path)")
                    }
                }

                // 6. OCR 提取
                let ocrStart = Date()
                let text = try await extractor.extract(from: captureResult.image)
                let ocrDuration = Date().timeIntervalSince(ocrStart) * 1000
                print("[Pipeline] OCR 完成 (\(String(format: "%.0f", ocrDuration))ms)")

                // 显示 OCR 结果
                let preview = text.prefix(200).replacingOccurrences(of: "\n", with: " ")
                if text.isEmpty {
                    print("[Pipeline] OCR 结果: (空)")
                } else {
                    print("[Pipeline] OCR 结果: \(preview)\(text.count > 200 ? "..." : "")")
                }

                // 6.5 OCR 去重
                if let lastText = lastOCRText, lastText == text {
                    print("[Pipeline] OCR 与上一条相同，跳过")
                    continue
                }
                lastOCRText = text

                // 7. 写入数据库
                let data = CaptureData(
                    sessionId: sessionManager.currentSessionId,
                    seq: seq,
                    rawOCR: text,
                    screenshotPath: screenshotPath,
                    capturedAt: captureResult.timestamp
                )
                try await writer.write(data)
                print("[Pipeline] 已保存到数据库")

                let totalDuration = Date().timeIntervalSince(triggerStart) * 1000
                print("[Pipeline] 本次采集总耗时: \(String(format: "%.0f", totalDuration))ms")

            } catch {
                print("[Pipeline] 错误: \(error)")
            }
        }

        print("[Pipeline] 会话结束")
    }

    /// 停止采集
    func stop() {
        isRunning = false
    }

    /// 保存截图到文件
    private func saveScreenshot(_ image: NSImage, seq: Int) -> String? {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "capture_\(seq)_\(timestamp).png"
        let filepath = (screenshotDir as NSString).appendingPathComponent(filename)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: filepath))
            return filepath
        } catch {
            print("[Pipeline] 保存截图失败: \(error)")
            return nil
        }
    }

}
