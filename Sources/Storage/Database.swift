import Foundation
import GRDB

/// 数据库封装
final class Database {
    private let dbQueue: DatabaseQueue

    init(path: String) throws {
        let expandedPath = NSString(string: path).expandingTildeInPath

        // 确保目录存在
        let directory = (expandedPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        dbQueue = try DatabaseQueue(path: expandedPath)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            // captures 表
            try db.create(table: "captures") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .text).notNull()
                t.column("seq", .integer).notNull()
                t.column("raw_ocr", .text)
                t.column("screenshot", .text)
                t.column("captured_at", .datetime).defaults(to: Date())
            }

            // results 表
            try db.create(table: "results") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("capture_id", .integer).references("captures", onDelete: .cascade)
                t.column("name", .text)
                t.column("summary", .text)
                t.column("passed", .boolean)
                t.column("reason", .text)
                t.column("processed_at", .datetime).defaults(to: Date())
            }
        }

        try migrator.migrate(dbQueue)
    }

    /// 写入捕获数据
    func write(_ capture: CaptureData) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO captures (session_id, seq, raw_ocr, screenshot, captured_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [capture.sessionId, capture.seq, capture.rawOCR, capture.screenshotPath, capture.capturedAt]
            )
        }
    }

    /// 获取未处理的捕获数据
    func fetchUnprocessedCaptures() async throws -> [CaptureRecord] {
        try await dbQueue.read { db in
            try CaptureRecord.fetchAll(db, sql: """
                SELECT c.* FROM captures c
                LEFT JOIN results r ON r.capture_id = c.id
                WHERE r.id IS NULL
                ORDER BY c.id
                """)
        }
    }

    /// 写入处理结果
    func writeResult(_ result: ProcessResult) async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO results (capture_id, name, summary, passed, reason, processed_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [result.captureId, result.name, result.summary, result.passed, result.reason, Date()]
            )
        }
    }

    /// 获取通过的结果
    func fetchPassedResults() async throws -> [ResultRecord] {
        try await dbQueue.read { db in
            try ResultRecord.fetchAll(db, sql: "SELECT * FROM results WHERE passed = 1 ORDER BY id")
        }
    }

    /// 获取所有捕获数据
    func fetchAllCaptures() async throws -> [CaptureRecord] {
        try await dbQueue.read { db in
            try CaptureRecord.fetchAll(db, sql: "SELECT * FROM captures ORDER BY id")
        }
    }

    /// 获取采集数量
    func captureCount() async throws -> Int {
        try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM captures") ?? 0
        }
    }

    /// 获取采集数量（同步版本）
    func captureCountSync() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM captures") ?? 0
        }
    }

    /// 获取已处理数量（同步版本）
    func processedCountSync() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM results") ?? 0
        }
    }

    /// 清空处理结果
    func clearResults() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM results")
        }
    }
}

// MARK: - Database Records

struct CaptureRecord: FetchableRecord, Codable {
    var id: Int64
    var sessionId: String
    var seq: Int
    var rawOCR: String?
    var screenshot: String?
    var capturedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case seq
        case rawOCR = "raw_ocr"
        case screenshot
        case capturedAt = "captured_at"
    }
}

struct ResultRecord: FetchableRecord, Codable {
    var id: Int64
    var captureId: Int64
    var name: String?
    var summary: String?
    var passed: Bool
    var reason: String?
    var processedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case name
        case summary
        case passed
        case reason
        case processedAt = "processed_at"
    }
}
