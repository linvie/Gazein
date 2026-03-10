import AppKit

/// 菜单栏 UI 控制器
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var pipeline: Pipeline?
    private var pipelineTask: Task<Void, Never>?
    private var database: Database?

    // 状态
    private var profiles: [Profile] = []
    private var currentProfile: Profile?
    private var currentProfileFilename: String?
    private var isRunning = false
    private var isConfiguring = false

    // UI 组件引用
    private var regionOverlay: RegionSelectorOverlay?
    private var keyPanel: KeyCapturePanel?

    // 菜单项引用
    private var profileMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var startMenuItem: NSMenuItem?
    private var stopMenuItem: NSMenuItem?
    private var configWizardMenuItem: NSMenuItem?
    private var endConfigMenuItem: NSMenuItem?
    private var profilesSubmenuItem: NSMenuItem?

    override init() {
        super.init()
        setupStatusItem()
        loadProfiles()
        print("[Gazein] 启动完成")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Gazein")
        }

        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // 当前配置
        profileMenuItem = NSMenuItem(title: "当前配置: 无", action: nil, keyEquivalent: "")
        profileMenuItem?.isEnabled = false
        menu.addItem(profileMenuItem!)

        // 切换配置子菜单
        profilesSubmenuItem = NSMenuItem(title: "切换配置", action: nil, keyEquivalent: "")
        profilesSubmenuItem?.submenu = NSMenu()
        menu.addItem(profilesSubmenuItem!)

        // 状态
        statusMenuItem = NSMenuItem(title: "状态: 未运行", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        menu.addItem(statusMenuItem!)

        menu.addItem(NSMenuItem.separator())

        // 开始/停止采集
        startMenuItem = NSMenuItem(title: "开始采集", action: #selector(startCollection), keyEquivalent: "s")
        startMenuItem?.target = self
        startMenuItem?.isEnabled = false
        menu.addItem(startMenuItem!)

        stopMenuItem = NSMenuItem(title: "停止采集", action: #selector(stopCollection), keyEquivalent: "")
        stopMenuItem?.target = self
        stopMenuItem?.isEnabled = false
        menu.addItem(stopMenuItem!)

        menu.addItem(NSMenuItem.separator())

        // 配置向导
        configWizardMenuItem = NSMenuItem(title: "开始配置...", action: #selector(startConfigWizard), keyEquivalent: "")
        configWizardMenuItem?.target = self
        menu.addItem(configWizardMenuItem!)

        endConfigMenuItem = NSMenuItem(title: "结束配置", action: #selector(endConfigWizard), keyEquivalent: "")
        endConfigMenuItem?.target = self
        endConfigMenuItem?.isHidden = true
        menu.addItem(endConfigMenuItem!)

        menu.addItem(NSMenuItem.separator())

        // 处理与导出
        let batchItem = NSMenuItem(title: "批量处理", action: #selector(batchProcess), keyEquivalent: "")
        batchItem.target = self
        menu.addItem(batchItem)

        let exportItem = NSMenuItem(title: "导出 CSV", action: #selector(exportCSV), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(NSMenuItem.separator())

        let openFolderItem = NSMenuItem(title: "打开配置文件夹", action: #selector(openConfigFolder), keyEquivalent: "")
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        let openScreenshotsItem = NSMenuItem(title: "打开截图文件夹", action: #selector(openScreenshotsFolder), keyEquivalent: "")
        openScreenshotsItem.target = self
        menu.addItem(openScreenshotsItem)

        let showConfigItem = NSMenuItem(title: "查看当前配置", action: #selector(showCurrentConfig), keyEquivalent: "")
        showConfigItem.target = self
        menu.addItem(showConfigItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(title: "退出 Gazein", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = nil
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Profile Management

    private func loadProfiles() {
        do {
            profiles = try ConfigLoader.loadAllProfiles()

            if profiles.isEmpty {
                print("[Gazein] 无配置文件，创建默认配置...")
                DefaultProfile.ensureDefaultProfileExists()
                profiles = try ConfigLoader.loadAllProfiles()
            }

            updateProfilesSubmenu()

            if let first = profiles.first {
                selectProfile(first, filename: first.profileName + ".json")
            }
        } catch {
            print("[Gazein] 加载配置失败: \(error)")
        }
    }

    private func updateProfilesSubmenu() {
        guard let submenu = profilesSubmenuItem?.submenu else { return }
        submenu.removeAllItems()

        for profile in profiles {
            let item = NSMenuItem(
                title: profile.profileName,
                action: #selector(profileSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile

            // 标记当前选中的配置
            if profile.profileName == currentProfile?.profileName {
                item.state = .on
            }

            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(title: "刷新列表", action: #selector(reloadProfiles), keyEquivalent: "")
        reloadItem.target = self
        submenu.addItem(reloadItem)

        let newItem = NSMenuItem(title: "新建配置...", action: #selector(createNewProfile), keyEquivalent: "")
        newItem.target = self
        submenu.addItem(newItem)
    }

    @objc private func profileSelected(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? Profile else { return }
        selectProfile(profile, filename: profile.profileName + ".json")
        updateProfilesSubmenu()  // 更新选中状态
    }

    @objc private func reloadProfiles() {
        loadProfiles()
        print("[Gazein] 配置列表已刷新")
    }

    @objc private func createNewProfile() {
        let alert = NSAlert()
        alert.messageText = "新建配置"
        alert.informativeText = "请输入配置名称:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "my_profile"
        alert.accessoryView = input

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                createProfile(named: name)
            }
        }
    }

    private func createProfile(named name: String) {
        let profile = Profile(
            profileName: name,
            trigger: TriggerConfig(
                type: "key_simulation",
                key: "arrow_down",
                intervalMs: 2000,
                jitterMs: 500
            ),
            capture: CaptureConfig(
                region: RegionConfig(x: 100, y: 100, width: 800, height: 600),
                changeThreshold: 0.05,
                saveScreenshot: true
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
            processor: nil
        )

        do {
            try ConfigLoader.saveProfile(profile, to: "\(name).json")
            loadProfiles()
            selectProfile(profile, filename: "\(name).json")
            print("[Gazein] 已创建配置: \(name)")
        } catch {
            showAlert(title: "创建失败", message: error.localizedDescription)
        }
    }

    private func selectProfile(_ profile: Profile, filename: String) {
        currentProfile = profile
        currentProfileFilename = filename
        profileMenuItem?.title = "当前配置: \(profile.profileName)"

        let region = profile.capture.region
        let key = profile.trigger.key ?? "未设置"
        print("[Gazein] 已选择配置: \(profile.profileName)")
        print("  - 区域: \(region.width)x\(region.height) @ (\(region.x), \(region.y))")
        print("  - 按键: \(key), 间隔: \(profile.trigger.intervalMs)ms")

        startMenuItem?.isEnabled = !isRunning

        let dbPath = profile.writer.dbPath ?? "~/Gazein/data.db"
        do {
            database = try Database(path: dbPath)
        } catch {
            print("[Gazein] 数据库初始化失败: \(error)")
        }
    }

    // MARK: - Configuration Wizard

    @objc private func startConfigWizard() {
        print("[Gazein] 开始配置向导...")

        if currentProfile == nil {
            DefaultProfile.ensureDefaultProfileExists()
            loadProfiles()
        }

        guard currentProfile != nil else {
            showAlert(title: "错误", message: "无法创建配置文件")
            return
        }

        isConfiguring = true
        configWizardMenuItem?.isHidden = true
        endConfigMenuItem?.isHidden = false
        statusMenuItem?.title = "状态: 配置中 - 请框选区域"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showRegionSelector()
        }
    }

    private func showRegionSelector() {
        print("[Gazein] 显示区域选择器...")

        regionOverlay = RegionSelectorOverlay()
        regionOverlay?.onRegionSelected = { [weak self] rect in
            guard let self = self else { return }

            print("[Gazein] 区域已选择: \(Int(rect.width))x\(Int(rect.height)) @ (\(Int(rect.origin.x)), \(Int(rect.origin.y)))")

            self.saveRegionToProfile(rect)
            self.regionOverlay = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.statusMenuItem?.title = "状态: 配置中 - 请设置按键"
                self.showKeyCapture()
            }
        }
        regionOverlay?.show()
    }

    private func saveRegionToProfile(_ rect: CGRect) {
        guard var profile = currentProfile, let filename = currentProfileFilename else { return }

        profile.capture.region = RegionConfig(
            x: Int(rect.origin.x),
            y: Int(rect.origin.y),
            width: Int(rect.width),
            height: Int(rect.height)
        )

        do {
            try ConfigLoader.saveProfile(profile, to: filename)
            currentProfile = profile
        } catch {
            print("[Gazein] 保存失败: \(error)")
        }
    }

    private func showKeyCapture() {
        print("[Gazein] 显示按键捕获...")

        keyPanel = KeyCapturePanel()
        keyPanel?.onKeyCaptured = { [weak self] keyName in
            guard let self = self else { return }

            print("[Gazein] 按键已捕获: \(keyName)")
            self.saveKeyToProfile(keyName)
            self.keyPanel = nil
            self.finishConfigWizard()
        }
        keyPanel?.show()
    }

    private func saveKeyToProfile(_ keyName: String) {
        guard var profile = currentProfile, let filename = currentProfileFilename else { return }

        profile.trigger.key = keyName

        do {
            try ConfigLoader.saveProfile(profile, to: filename)
            currentProfile = profile
        } catch {
            print("[Gazein] 保存失败: \(error)")
        }
    }

    private func finishConfigWizard() {
        isConfiguring = false
        configWizardMenuItem?.isHidden = false
        endConfigMenuItem?.isHidden = true
        statusMenuItem?.title = "状态: 未运行"

        showCurrentConfigAlert()
    }

    @objc private func endConfigWizard() {
        regionOverlay?.close()
        regionOverlay = nil
        keyPanel?.close()
        keyPanel = nil
        finishConfigWizard()
    }

    @objc private func showCurrentConfig() {
        showCurrentConfigAlert()
    }

    private func showCurrentConfigAlert() {
        guard let profile = currentProfile else {
            showAlert(title: "无配置", message: "请先创建配置文件")
            return
        }

        let region = profile.capture.region
        let key = profile.trigger.key ?? "未设置"
        let interval = profile.trigger.intervalMs
        let screenshotDir = profile.writer.screenshotDir ?? "~/Gazein/screenshots"

        let message = """
        配置名称: \(profile.profileName)

        截图区域:
          位置: (\(region.x), \(region.y))
          大小: \(region.width) x \(region.height)

        触发设置:
          按键: \(key)
          间隔: \(interval) 毫秒

        截图保存:
          \(NSString(string: screenshotDir).expandingTildeInPath)

        配置文件:
          ~/.gazein/profiles/\(profile.profileName).json

        提示: AI 处理等高级设置请直接编辑配置文件
        """

        showAlert(title: "当前配置", message: message)
    }

    // MARK: - Collection Control

    @objc private func startCollection() {
        guard let profile = currentProfile, !isRunning else { return }

        print("\n[Gazein] ========== 开始采集 ==========")
        print("[Gazein] 配置: \(profile.profileName)")

        do {
            if database == nil {
                let dbPath = profile.writer.dbPath ?? "~/Gazein/data.db"
                database = try Database(path: dbPath)
            }

            let trigger = KeySimulationTrigger(
                key: profile.trigger.key ?? "arrow_down",
                intervalMs: profile.trigger.intervalMs,
                jitterMs: profile.trigger.jitterMs ?? 0
            )

            let region = profile.capture.region
            print("[Gazein] 截图区域: \(region.width)x\(region.height) @ (\(region.x), \(region.y))")

            let capture = RegionCapture(
                region: region.cgRect,
                changeThreshold: profile.capture.changeThreshold ?? 0.05
            )

            let extractor = VisionOCRExtractor(
                languages: profile.extractor.languages ?? ["zh-Hans", "en"]
            )

            let writer = SQLiteWriter(database: database!)
            let sessionManager = SessionManager()

            let screenshotDir = profile.writer.screenshotDir ?? "~/Gazein/screenshots"
            let saveScreenshots = profile.capture.saveScreenshot ?? true

            pipeline = Pipeline(
                trigger: trigger,
                capture: capture,
                extractor: extractor,
                writer: writer,
                sessionManager: sessionManager,
                saveScreenshots: saveScreenshots,
                screenshotDir: screenshotDir
            )

            isRunning = true
            updateUIState()

            pipelineTask = Task {
                await pipeline?.start()
            }

        } catch {
            print("[Gazein] 启动失败: \(error)")
            showAlert(title: "启动失败", message: error.localizedDescription)
        }
    }

    @objc private func stopCollection() {
        guard isRunning else { return }

        pipeline?.stop()
        pipelineTask?.cancel()
        pipelineTask = nil

        isRunning = false
        updateUIState()
        print("[Gazein] ========== 采集已停止 ==========\n")
    }

    private func updateUIState() {
        if isRunning {
            statusMenuItem?.title = "状态: 采集中"
            startMenuItem?.isEnabled = false
            stopMenuItem?.isEnabled = true
            configWizardMenuItem?.isEnabled = false
            profilesSubmenuItem?.isEnabled = false
        } else {
            statusMenuItem?.title = "状态: 未运行"
            startMenuItem?.isEnabled = currentProfile != nil
            stopMenuItem?.isEnabled = false
            configWizardMenuItem?.isEnabled = true
            profilesSubmenuItem?.isEnabled = true
        }
    }

    // MARK: - Processing & Export

    @objc private func batchProcess() {
        guard let db = database else {
            showAlert(title: "错误", message: "请先选择配置文件")
            return
        }

        guard let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !apiKey.isEmpty else {
            showAlert(title: "需要 API Key", message: """
            请设置环境变量 DEEPSEEK_API_KEY

            在终端运行:
            export DEEPSEEK_API_KEY="your-key"

            然后重新启动应用
            """)
            return
        }

        let systemPrompt = currentProfile?.processor?.systemPrompt ?? "请分析以下内容并提取关键信息，以 JSON 格式返回。"
        let model = currentProfile?.processor?.model ?? "deepseek-chat"

        Task {
            do {
                let captures = try await db.fetchUnprocessedCaptures()

                if captures.isEmpty {
                    showAlert(title: "提示", message: "没有未处理的数据")
                    return
                }

                print("[Gazein] 开始批量处理 \(captures.count) 条数据...")

                let captureDataList = captures.map { record in
                    CaptureData(
                        sessionId: record.sessionId,
                        seq: record.seq,
                        rawOCR: record.rawOCR ?? "",
                        screenshotPath: record.screenshot,
                        capturedAt: record.capturedAt
                    )
                }

                let processor = DeepSeekProcessor(model: model, systemPrompt: systemPrompt, apiKey: apiKey)
                let results = try await processor.process(captures: captureDataList)

                for (index, result) in results.enumerated() {
                    let captureId = Int(captures[index].id)
                    let finalResult = ProcessResult(
                        captureId: captureId,
                        name: result.name,
                        summary: result.summary,
                        passed: result.passed,
                        reason: result.reason
                    )
                    try await db.writeResult(finalResult)
                }

                print("[Gazein] 批量处理完成")
                showAlert(title: "处理完成", message: "已处理 \(results.count) 条数据")

            } catch {
                showAlert(title: "处理失败", message: error.localizedDescription)
            }
        }
    }

    @objc private func exportCSV() {
        guard let db = database else {
            showAlert(title: "错误", message: "请先选择配置文件")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "gazein_export.csv"
        savePanel.title = "导出 CSV"

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }

            Task {
                do {
                    let results = try await db.fetchPassedResults()

                    let processResults = results.map { record in
                        ProcessResult(
                            captureId: Int(record.captureId),
                            name: record.name,
                            summary: record.summary,
                            passed: record.passed,
                            reason: record.reason
                        )
                    }

                    let exporter = CSVExporter()
                    try await exporter.export(results: processResults, to: url)

                    NSWorkspace.shared.open(url)

                } catch {
                    self?.showAlert(title: "导出失败", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func openConfigFolder() {
        let path = NSString(string: "~/.gazein/profiles").expandingTildeInPath

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func openScreenshotsFolder() {
        let screenshotDir = currentProfile?.writer.screenshotDir ?? "~/Gazein/screenshots"
        let path = NSString(string: screenshotDir).expandingTildeInPath

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
