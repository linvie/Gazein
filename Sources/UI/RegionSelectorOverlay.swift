import AppKit

/// 全屏透明遮罩，用于框选区域
final class RegionSelectorOverlay: NSWindow {
    private var selectionRect: NSRect = .zero
    private var startPoint: NSPoint = .zero
    private var isDragging = false

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
    }

    fileprivate func updateSelection(start: NSPoint, current: NSPoint) {
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        selectionRect = NSRect(x: x, y: y, width: width, height: height)
        contentView?.needsDisplay = true
    }

    fileprivate func completeSelection() {
        // 转换为屏幕坐标（原点在左上角）
        if let screen = NSScreen.main {
            let flippedY = screen.frame.height - selectionRect.origin.y - selectionRect.height
            let screenRect = CGRect(
                x: selectionRect.origin.x,
                y: flippedY,
                width: selectionRect.width,
                height: selectionRect.height
            )
            onRegionSelected?(screenRect)
        }
        close()
    }
}

// MARK: - Selection View

private class RegionSelectorView: NSView {
    weak var overlay: RegionSelectorOverlay?
    private var startPoint: NSPoint = .zero
    private var currentPoint: NSPoint = .zero
    private var isDragging = false

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
        }
    }
}
