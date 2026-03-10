import Foundation
import Carbon

/// 按键模拟触发器
final class KeySimulationTrigger: Trigger, @unchecked Sendable {
    private let keyCode: CGKeyCode
    private let baseIntervalMs: Int
    private let jitterMs: Int

    var intervalMs: Int {
        baseIntervalMs + Int.random(in: 0...jitterMs)
    }

    init(key: String, intervalMs: Int, jitterMs: Int = 0) {
        self.keyCode = Self.keyCodeFor(key: key)
        self.baseIntervalMs = intervalMs
        self.jitterMs = jitterMs
    }

    @MainActor
    func fire() async throws {
        // 创建按键按下事件
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw TriggerError.eventCreationFailed
        }

        // 创建按键释放事件
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw TriggerError.eventCreationFailed
        }

        // 发送事件
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func keyCodeFor(key: String) -> CGKeyCode {
        switch key.lowercased() {
        case "arrow_down", "down":
            return CGKeyCode(kVK_DownArrow)
        case "arrow_up", "up":
            return CGKeyCode(kVK_UpArrow)
        case "arrow_left", "left":
            return CGKeyCode(kVK_LeftArrow)
        case "arrow_right", "right":
            return CGKeyCode(kVK_RightArrow)
        case "return", "enter":
            return CGKeyCode(kVK_Return)
        case "space":
            return CGKeyCode(kVK_Space)
        case "tab":
            return CGKeyCode(kVK_Tab)
        case "escape", "esc":
            return CGKeyCode(kVK_Escape)
        default:
            return 0
        }
    }
}

enum TriggerError: Error {
    case eventCreationFailed
}
