import Foundation

/// CSV 导出器
final class CSVExporter: Exporter {
    func export(results: [ProcessResult], to path: URL) async throws {
        var csv = "ID,Name,Summary,Passed,Reason\n"

        for result in results {
            let row = [
                String(result.captureId),
                escapeCSV(result.name ?? ""),
                escapeCSV(result.summary ?? ""),
                result.passed ? "Yes" : "No",
                escapeCSV(result.reason ?? "")
            ].joined(separator: ",")

            csv += row + "\n"
        }

        try csv.write(to: path, atomically: true, encoding: .utf8)
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
