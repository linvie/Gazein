import Foundation

/// 管道调度器 - 协调各模块的执行
final class Pipeline {
    private let trigger: Trigger
    private let capture: Capture
    private let extractor: Extractor
    private let writer: Writer

    private var isRunning = false
    private var sessionManager: SessionManager
    private var lastCaptureResult: CaptureResult?

    init(
        trigger: Trigger,
        capture: Capture,
        extractor: Extractor,
        writer: Writer,
        sessionManager: SessionManager
    ) {
        self.trigger = trigger
        self.capture = capture
        self.extractor = extractor
        self.writer = writer
        self.sessionManager = sessionManager
    }

    /// 开始采集循环
    func start() async {
        guard !isRunning else { return }
        isRunning = true

        sessionManager.startNewSession()

        while isRunning {
            do {
                // 1. 触发动作（模拟按键等）
                try await trigger.fire()

                // 2. 等待指定间隔
                try await Task.sleep(nanoseconds: UInt64(trigger.intervalMs) * 1_000_000)

                // 3. 捕获截图
                let captureResult = try await capture.capture()

                // 4. 检测变化
                if let last = lastCaptureResult, !capture.hasChanged(from: last) {
                    continue
                }
                lastCaptureResult = captureResult

                // 5. OCR 提取
                let text = try await extractor.extract(from: captureResult.image)

                // 6. 写入数据库
                let data = CaptureData(
                    sessionId: sessionManager.currentSessionId,
                    seq: sessionManager.nextSeq(),
                    rawOCR: text,
                    screenshotPath: nil, // TODO: 保存截图
                    capturedAt: captureResult.timestamp
                )
                try await writer.write(data)

            } catch {
                print("Pipeline error: \(error)")
            }
        }
    }

    /// 停止采集
    func stop() {
        isRunning = false
    }
}
