import Foundation
import GRDB

/// SQLite 数据写入器
final class SQLiteWriter: Writer {
    private let database: Database

    init(database: Database) {
        self.database = database
    }

    func write(_ capture: CaptureData) async throws {
        try await database.write(capture)
    }
}
