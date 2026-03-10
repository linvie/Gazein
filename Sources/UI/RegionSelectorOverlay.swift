import AppKit

/// 全屏透明遮罩，用于框选区域
final class RegionSelectorOverlay: NSWindow {
    private var selectionRect: NSRect = .zero

    var onRegionSelected: ((CGRect) -> Void)?

    init() {
        super.init(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.3)
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        let contentView = RegionSelectorView()
        contentView.overlay = self
        self.contentView = contentView
    }

    func show() {
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
        }
        makeKeyAndOrderFront(nil)

        // 激活应用以接收键盘事件
        NSApp.activate(ignoringOtherApps: true)
    }

    override func keyDown(with event: NSEvent) {
        // ESC 键取消选择
        if event.keyCode == 53 {
            orderOut(nil)
            return
        }
        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    fileprivate func updateSelection(start: NSPoint, current: NSPoint) {
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        selectionRect = NSRect(x: x, y: y, width: width, height: height)
        contentView?.needsDisplay = true
    }

    fileprivate func completeSelection() {
        // 检查选择是否有效（至少 10x10 像素）
        guard selectionRect.width >= 10 && selectionRect.height >= 10 else {
            print("[Gazein] 选择区域太小，已取消")
            orderOut(nil)
            return
        }

        // 转换为屏幕坐标（原点在左上角）
        if let screen = NSScreen.main {
            let flippedY = screen.frame.height - selectionRect.origin.y - selectionRect.height
            let screenRect = CGRect(
                x: selectionRect.origin.x,
                y: flippedY,
                width: selectionRect.width,
                height: selectionRect.height
            )

            // 先关闭窗口
            orderOut(nil)

            // 然后回调
            onRegionSelected?(screenRect)
        } else {
            orderOut(nil)
        }
    }
}

// MARK: - Selection View

private class RegionSelectorView: NSView {
    weak var overlay: RegionSelectorOverlay?
    private var startPoint: NSPoint = .zero
    private var currentPoint: NSPoint = .zero
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = event.locationInWindow
        overlay?.updateSelection(start: startPoint, current: currentPoint)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        overlay?.completeSelection()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // 绘制半透明背景
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        // 绘制选择框
        if isDragging {
            let rect = NSRect(
                x: min(startPoint.x, currentPoint.x),
                y: min(startPoint.y, currentPoint.y),
                width: abs(currentPoint.x - startPoint.x),
                height: abs(currentPoint.y - startPoint.y)
            )

            // 清除选择区域（显示原始内容）
            NSColor.clear.setFill()
            rect.fill()

            // 绘制边框
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // 显示尺寸
            let sizeText = "\(Int(rect.width)) x \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.7)
            ]
            let textSize = sizeText.size(withAttributes: attributes)
            let textRect = NSRect(
                x: rect.midX - textSize.width / 2,
                y: rect.midY - textSize.height / 2,
                width: textSize.width + 8,
                height: textSize.height + 4
            )

            // 背景
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()

            // 文字
            sizeText.draw(
                at: NSPoint(x: textRect.origin.x + 4, y: textRect.origin.y + 2),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
            )
        }
    }
}
