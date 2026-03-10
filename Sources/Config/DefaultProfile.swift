import Foundation

/// 默认配置文件生成器
enum DefaultProfile {
    /// 确保默认配置文件存在
    static func ensureDefaultProfileExists() {
        let profilesPath = NSString(string: ConfigLoader.profilesDirectory).expandingTildeInPath
        let defaultProfilePath = (profilesPath as NSString).appendingPathComponent("default.json")

        let fileManager = FileManager.default

        // 确保目录存在
        if !fileManager.fileExists(atPath: profilesPath) {
            try? fileManager.createDirectory(atPath: profilesPath, withIntermediateDirectories: true)
        }

        // 如果默认配置不存在，创建一个
        if !fileManager.fileExists(atPath: defaultProfilePath) {
            let defaultProfile = createDefaultProfile()
            try? ConfigLoader.saveProfile(defaultProfile, to: "default.json")
        }
    }

    /// 创建默认配置
    private static func createDefaultProfile() -> Profile {
        Profile(
            profileName: "default",
            trigger: TriggerConfig(
                type: "key_simulation",
                key: "arrow_down",
                intervalMs: 2000,
                jitterMs: 500
            ),
            capture: CaptureConfig(
                region: RegionConfig(
                    x: 100,
                    y: 100,
                    width: 800,
                    height: 600
                ),
                changeThreshold: 0.05,
                saveScreenshot: false
            ),
            extractor: ExtractorConfig(
                type: "vision_ocr",
                languages: ["zh-Hans", "en"]
            ),
            writer: WriterConfig(
                type: "sqlite",
                dbPath: "~/Gazein/data.db",
                screenshotDir: "~/Gazein/screenshots"
            ),
            processor: ProcessorConfig(
                model: "deepseek-chat",
                systemPrompt: """
                请分析以下 OCR 提取的文本内容，提取关键信息。

                以 JSON 格式返回，包含以下字段:
                - name: 项目名称或标题
                - summary: 内容摘要 (100字以内)
                - passed: 是否为有效数据 (true/false)
                - reason: 判断理由

                如果内容无效或无法识别，设置 passed 为 false。
                """,
                outputFields: ["name", "summary", "passed", "reason"]
            )
        )
    }
}
