import AppKit
import Carbon

/// 按键监听弹窗
final class KeyCapturePanel: NSPanel {
    private var eventMonitor: Any?
    var onKeyCaptured: ((String) -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        title = "按键监听"
        level = .floating
        center()

        setupUI()
    }

    private func setupUI() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))

        let label = NSTextField(labelWithString: "请按下要模拟的按键...")
        label.frame = NSRect(x: 20, y: 60, width: 260, height: 30)
        label.alignment = .center
        label.font = .systemFont(ofSize: 16)
        contentView.addSubview(label)

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.frame = NSRect(x: 100, y: 20, width: 100, height: 30)
        contentView.addSubview(cancelButton)

        self.contentView = contentView
    }

    func show() {
        makeKeyAndOrderFront(nil)
        startMonitoring()
    }

    private func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
            return nil
        }
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        let keyName = keyNameFor(keyCode: event.keyCode)
        onKeyCaptured?(keyName)
        stopMonitoring()
        close()
    }

    @objc private func cancel() {
        stopMonitoring()
        close()
    }

    private func keyNameFor(keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_DownArrow: return "arrow_down"
        case kVK_UpArrow: return "arrow_up"
        case kVK_LeftArrow: return "arrow_left"
        case kVK_RightArrow: return "arrow_right"
        case kVK_Return: return "return"
        case kVK_Space: return "space"
        case kVK_Tab: return "tab"
        case kVK_Escape: return "escape"
        default: return "unknown_\(keyCode)"
        }
    }
}
