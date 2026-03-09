import Foundation

/// 批次管理器 - 管理采集会话
final class SessionManager {
    private(set) var currentSessionId: String = ""
    private var currentSeq: Int = 0

    /// 开始新的采集会话
    func startNewSession() {
        currentSessionId = UUID().uuidString
        currentSeq = 0
    }

    /// 获取下一个序号
    func nextSeq() -> Int {
        currentSeq += 1
        return currentSeq
    }
}
