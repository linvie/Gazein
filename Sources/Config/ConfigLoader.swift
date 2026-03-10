import Foundation

/// 配置加载器
final class ConfigLoader {
    static let profilesDirectory = "~/.gazein/profiles"

    /// 加载所有配置文件
    static func loadAllProfiles() throws -> [Profile] {
        let path = NSString(string: profilesDirectory).expandingTildeInPath
        let fileManager = FileManager.default

        // 确保目录存在
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
            return []
        }

        let files = try fileManager.contentsOfDirectory(atPath: path)
        let jsonFiles = files.filter { $0.hasSuffix(".json") }

        return try jsonFiles.compactMap { file in
            let filePath = (path as NSString).appendingPathComponent(file)
            return try loadProfile(from: filePath)
        }
    }

    /// 加载单个配置文件
    static func loadProfile(from path: String) throws -> Profile {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Profile.self, from: data)
    }

    /// 保存配置文件
    static func saveProfile(_ profile: Profile, to filename: String) throws {
        let path = NSString(string: profilesDirectory).expandingTildeInPath
        let filePath = (path as NSString).appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(profile)
        try data.write(to: URL(fileURLWithPath: filePath))
    }
}

// MARK: - Profile Model

struct Profile: Codable {
    let profileName: String
    var trigger: TriggerConfig
    var capture: CaptureConfig
    var extractor: ExtractorConfig
    var writer: WriterConfig
    var processor: ProcessorConfig?
}

struct TriggerConfig: Codable {
    let type: String
    var key: String?
    var intervalMs: Int
    var jitterMs: Int?
}

struct CaptureConfig: Codable {
    var region: RegionConfig
    var changeThreshold: Double?
    var saveScreenshot: Bool?
}

struct RegionConfig: Codable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct ExtractorConfig: Codable {
    let type: String
    var languages: [String]?
}

struct WriterConfig: Codable {
    let type: String
    var dbPath: String?
    var screenshotDir: String?
}

struct ProcessorConfig: Codable {
    var provider: String?  // deepseek, kimi, openai
    let model: String
    let systemPrompt: String
    var outputFields: [String]?
}
