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
    private var sessionStartTime: Date?

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
        checkAccessibilityPermission()
        print("[Gazein] 启动完成")
    }

    // MARK: - 数据目录管理

    /// 获取配置的数据目录
    private func dataDirectory(for profile: Profile) -> String {
        let basePath = NSString(string: "~/Gazein").expandingTildeInPath
        return (basePath as NSString).appendingPathComponent(profile.profileName)
    }

    /// 获取配置的数据库路径
    private func databasePath(for profile: Profile) -> String {
        return (dataDirectory(for: profile) as NSString).appendingPathComponent("data.db")
    }

    /// 获取配置的截图目录
    private func screenshotsDirectory(for profile: Profile) -> String {
        return (dataDirectory(for: profile) as NSString).appendingPathComponent("screenshots")
    }

    /// 获取配置的导出目录
    private func exportsDirectory(for profile: Profile) -> String {
        return (dataDirectory(for: profile) as NSString).appendingPathComponent("exports")
    }

    /// 确保配置的数据目录存在
    private func ensureDataDirectories(for profile: Profile) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dataDirectory(for: profile), withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: screenshotsDirectory(for: profile), withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: exportsDirectory(for: profile), withIntermediateDirectories: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Gazein")
        }

        statusItem?.menu = buildMenu()
    }

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("[Gazein] ⚠️  未获得辅助功能权限，按键模拟将无法工作")
            print("[Gazein] 请前往: 系统设置 → 隐私与安全 → 辅助功能 → 允许 Gazein")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "按键模拟功能需要辅助功能权限。\n\n请前往:\n系统设置 → 隐私与安全 → 辅助功能\n\n然后允许 Gazein 或终端应用。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")

                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        } else {
            print("[Gazein] ✓ 辅助功能权限已获得")
        }
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
        let batchItem = NSMenuItem(title: "批量处理 (AI)...", action: #selector(showBatchProcessDialog), keyEquivalent: "")
        batchItem.target = self
        menu.addItem(batchItem)

        let exportOCRItem = NSMenuItem(title: "导出 OCR 结果", action: #selector(exportOCRResults), keyEquivalent: "")
        exportOCRItem.target = self
        menu.addItem(exportOCRItem)

        let exportAIItem = NSMenuItem(title: "导出 AI 结果", action: #selector(exportAIResults), keyEquivalent: "")
        exportAIItem.target = self
        menu.addItem(exportAIItem)

        let cleanupItem = NSMenuItem(title: "清理数据...", action: #selector(showCleanupDialog), keyEquivalent: "")
        cleanupItem.target = self
        menu.addItem(cleanupItem)

        menu.addItem(NSMenuItem.separator())

        let apiKeyItem = NSMenuItem(title: "配置 API Key...", action: #selector(openAPIKeyConfig), keyEquivalent: "")
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)

        let openDataItem = NSMenuItem(title: "打开数据文件夹", action: #selector(openDataFolder), keyEquivalent: "")
        openDataItem.target = self
        menu.addItem(openDataItem)

        let openConfigItem = NSMenuItem(title: "打开配置文件夹", action: #selector(openConfigFolder), keyEquivalent: "")
        openConfigItem.target = self
        menu.addItem(openConfigItem)

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
        updateProfilesSubmenu()
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
                dbPath: nil,  // 使用默认路径
                screenshotDir: nil
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

        // 确保数据目录存在
        ensureDataDirectories(for: profile)

        let region = profile.capture.region
        let key = profile.trigger.key ?? "未设置"
        print("[Gazein] 已选择配置: \(profile.profileName)")
        print("  - 区域: \(region.width)x\(region.height) @ (\(region.x), \(region.y))")
        print("  - 按键: \(key), 间隔: \(profile.trigger.intervalMs)ms")
        print("  - 数据目录: \(dataDirectory(for: profile))")

        startMenuItem?.isEnabled = !isRunning

        // 初始化数据库
        do {
            database = try Database(path: databasePath(for: profile))
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

        let trusted = AXIsProcessTrusted()
        let permissionStatus = trusted ? "✓ 已授权" : "✗ 未授权"

        // 获取数据统计
        var captureCount = 0
        var processedCount = 0
        if let db = database {
            captureCount = (try? db.captureCountSync()) ?? 0
            processedCount = (try? db.processedCountSync()) ?? 0
        }

        let message = """
        配置名称: \(profile.profileName)

        截图区域: (\(region.x), \(region.y)) - \(region.width) x \(region.height)
        触发按键: \(key)
        采集间隔: \(interval) 毫秒

        辅助功能权限: \(permissionStatus)

        数据统计:
          已采集: \(captureCount) 条
          已处理: \(processedCount) 条

        数据目录: ~/Gazein/\(profile.profileName)/
        配置文件: ~/.gazein/profiles/\(profile.profileName).json
        """

        showAlert(title: "当前配置", message: message)
    }

    // MARK: - Collection Control

    @objc private func startCollection() {
        guard let profile = currentProfile, !isRunning else { return }

        sessionStartTime = Date()
        let timeStr = formatDateTime(sessionStartTime!)

        print("\n[Gazein] ========== 开始采集 ==========")
        print("[Gazein] 时间: \(timeStr)")
        print("[Gazein] 配置: \(profile.profileName)")

        if !AXIsProcessTrusted() {
            print("[Gazein] ⚠️  警告: 未获得辅助功能权限，按键模拟可能无法工作")
        }

        do {
            // 确保数据目录存在
            ensureDataDirectories(for: profile)

            if database == nil {
                database = try Database(path: databasePath(for: profile))
            }

            let trigger = KeySimulationTrigger(
                key: profile.trigger.key ?? "arrow_down",
                intervalMs: profile.trigger.intervalMs,
                jitterMs: profile.trigger.jitterMs ?? 0
            )

            let region = profile.capture.region
            print("[Gazein] 截图区域: \(region.width)x\(region.height) @ (\(region.x), \(region.y))")
            print("[Gazein] 按键: \(profile.trigger.key ?? "arrow_down"), 间隔: \(profile.trigger.intervalMs)ms")
            print("[Gazein] 提示: 请确保目标窗口处于激活状态!")

            let capture = RegionCapture(
                region: region.cgRect,
                changeThreshold: profile.capture.changeThreshold ?? 0.05
            )

            let extractor = VisionOCRExtractor(
                languages: profile.extractor.languages ?? ["zh-Hans", "en"]
            )

            let writer = SQLiteWriter(database: database!)
            let sessionManager = SessionManager()

            let screenshotDir = screenshotsDirectory(for: profile)
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
        guard isRunning, let profile = currentProfile else { return }

        pipeline?.stop()
        pipelineTask?.cancel()
        pipelineTask = nil

        isRunning = false
        updateUIState()

        print("[Gazein] ========== 采集已停止 ==========")

        // 自动导出 OCR 结果
        if let startTime = sessionStartTime {
            autoExportOCRResults(profile: profile, startTime: startTime)
        }
    }

    private func autoExportOCRResults(profile: Profile, startTime: Date) {
        guard let db = database else { return }

        let exportsDir = exportsDirectory(for: profile)

        let filename = "ocr_\(formatFileDateTime(startTime)).csv"
        let filepath = (exportsDir as NSString).appendingPathComponent(filename)

        Task {
            do {
                let captures = try await db.fetchAllCaptures()

                if captures.isEmpty {
                    print("[Gazein] 没有数据需要导出")
                    return
                }

                var csv = "序号,时间,OCR文本,截图路径\n"
                for capture in captures {
                    let row = [
                        String(capture.seq),
                        formatDateTime(capture.capturedAt),
                        escapeCSV(capture.rawOCR ?? ""),
                        escapeCSV(capture.screenshot ?? "")
                    ].joined(separator: ",")
                    csv += row + "\n"
                }

                try csv.write(toFile: filepath, atomically: true, encoding: .utf8)

                print("[Gazein] ✓ OCR 结果已导出: \(filepath)")
                print("[Gazein] 共 \(captures.count) 条记录")

            } catch {
                print("[Gazein] 导出失败: \(error)")
            }
        }
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

    // MARK: - Batch Processing Dialog

    @objc private func showBatchProcessDialog() {
        guard !profiles.isEmpty else {
            showAlert(title: "错误", message: "没有配置文件")
            return
        }

        // 创建对话框
        let alert = NSAlert()
        alert.messageText = "AI 批量处理"
        alert.informativeText = "选择要处理的配置和模式:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "开始处理")
        alert.addButton(withTitle: "取消")

        // 创建选项视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))

        // 配置选择
        let profileLabel = NSTextField(labelWithString: "选择配置:")
        profileLabel.frame = NSRect(x: 0, y: 70, width: 80, height: 20)
        containerView.addSubview(profileLabel)

        let profilePopup = NSPopUpButton(frame: NSRect(x: 85, y: 68, width: 200, height: 24))
        for profile in profiles {
            profilePopup.addItem(withTitle: profile.profileName)
        }
        if let current = currentProfile {
            profilePopup.selectItem(withTitle: current.profileName)
        }
        containerView.addSubview(profilePopup)

        // 处理模式选择
        let modeLabel = NSTextField(labelWithString: "处理模式:")
        modeLabel.frame = NSRect(x: 0, y: 40, width: 80, height: 20)
        containerView.addSubview(modeLabel)

        let modePopup = NSPopUpButton(frame: NSRect(x: 85, y: 38, width: 200, height: 24))
        modePopup.addItem(withTitle: "仅未处理的数据")
        modePopup.addItem(withTitle: "全部数据（重新处理）")
        containerView.addSubview(modePopup)

        // 数据统计标签
        let statsLabel = NSTextField(labelWithString: "")
        statsLabel.frame = NSRect(x: 0, y: 5, width: 300, height: 25)
        statsLabel.isEditable = false
        statsLabel.isBordered = false
        statsLabel.backgroundColor = .clear
        statsLabel.textColor = .secondaryLabelColor
        containerView.addSubview(statsLabel)

        // 更新统计信息
        func updateStats() {
            guard let selectedTitle = profilePopup.selectedItem?.title,
                  let profile = profiles.first(where: { $0.profileName == selectedTitle }) else { return }

            do {
                let db = try Database(path: databasePath(for: profile))
                let total = try db.captureCountSync()
                let processed = try db.processedCountSync()
                let unprocessed = total - processed

                if modePopup.indexOfSelectedItem == 0 {
                    statsLabel.stringValue = "将处理 \(unprocessed) 条未处理数据（共 \(total) 条）"
                } else {
                    statsLabel.stringValue = "将处理全部 \(total) 条数据"
                }
            } catch {
                statsLabel.stringValue = "无法读取数据"
            }
        }

        // 初始更新
        updateStats()

        // 监听选择变化
        profilePopup.target = self
        profilePopup.action = #selector(batchDialogSelectionChanged(_:))
        modePopup.target = self
        modePopup.action = #selector(batchDialogSelectionChanged(_:))

        // 保存引用以便更新
        objc_setAssociatedObject(profilePopup, "statsLabel", statsLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(profilePopup, "modePopup", modePopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(modePopup, "statsLabel", statsLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(modePopup, "profilePopup", profilePopup, .OBJC_ASSOCIATION_RETAIN)

        alert.accessoryView = containerView

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            guard let selectedTitle = profilePopup.selectedItem?.title,
                  let profile = profiles.first(where: { $0.profileName == selectedTitle }) else { return }

            let processAll = modePopup.indexOfSelectedItem == 1
            batchProcess(profile: profile, processAll: processAll)
        }
    }

    @objc private func batchDialogSelectionChanged(_ sender: NSPopUpButton) {
        let statsLabel = objc_getAssociatedObject(sender, "statsLabel") as? NSTextField
        let profilePopup: NSPopUpButton?
        let modePopup: NSPopUpButton?

        if let pp = objc_getAssociatedObject(sender, "profilePopup") as? NSPopUpButton {
            profilePopup = pp
            modePopup = sender
        } else {
            profilePopup = sender
            modePopup = objc_getAssociatedObject(sender, "modePopup") as? NSPopUpButton
        }

        guard let profilePopup = profilePopup,
              let modePopup = modePopup,
              let statsLabel = statsLabel,
              let selectedTitle = profilePopup.selectedItem?.title,
              let profile = profiles.first(where: { $0.profileName == selectedTitle }) else { return }

        do {
            let db = try Database(path: databasePath(for: profile))
            let total = try db.captureCountSync()
            let processed = try db.processedCountSync()
            let unprocessed = total - processed

            if modePopup.indexOfSelectedItem == 0 {
                statsLabel.stringValue = "将处理 \(unprocessed) 条未处理数据（共 \(total) 条）"
            } else {
                statsLabel.stringValue = "将处理全部 \(total) 条数据"
            }
        } catch {
            statsLabel.stringValue = "无法读取数据"
        }
    }

    private func batchProcess(profile: Profile, processAll: Bool) {
        let systemPrompt = profile.processor?.systemPrompt ?? "请分析以下内容并提取关键信息，以 JSON 格式返回。"
        let providerName = profile.processor?.provider ?? "deepseek"
        let model = profile.processor?.model

        // 创建 AI 处理器
        guard let processor = AIProcessor.fromConfig(
            providerName: providerName,
            model: model,
            systemPrompt: systemPrompt
        ) else {
            let provider = AIProcessor.AIProvider(rawValue: providerName) ?? .deepseek
            showAlert(title: "需要 API Key", message: """
            批量处理需要 AI API。

            请设置环境变量:
            export \(provider.envKey)="your-key"

            支持的服务商:
            - deepseek: DEEPSEEK_API_KEY
            - kimi: MOONSHOT_API_KEY
            - openai: OPENAI_API_KEY

            然后重新启动应用。
            """)
            return
        }

        print("[Gazein] 开始 AI 批量处理")
        print("[Gazein] 配置: \(profile.profileName)")
        print("[Gazein] 服务商: \(providerName)")
        print("[Gazein] 模式: \(processAll ? "全部数据" : "仅未处理")")

        Task {
            do {
                let db = try Database(path: databasePath(for: profile))

                // 如果是全部处理，先清空 results 表
                if processAll {
                    try await db.clearResults()
                    print("[Gazein] 已清空旧的处理结果")
                }

                let captures = try await db.fetchUnprocessedCaptures()

                if captures.isEmpty {
                    showAlert(title: "提示", message: "没有需要处理的数据")
                    return
                }

                let total = captures.count
                print("[Gazein] 开始处理 \(total) 条数据 (边处理边写入)...")

                var successCount = 0
                var failCount = 0

                for (index, record) in captures.enumerated() {
                    let num = index + 1
                    let captureId = Int(record.id)
                    let preview = String((record.rawOCR ?? "").prefix(50)).replacingOccurrences(of: "\n", with: " ")

                    print("[Gazein] [\(num)/\(total)] 处理中: \(preview)...")

                    let captureData = CaptureData(
                        sessionId: record.sessionId,
                        seq: record.seq,
                        rawOCR: record.rawOCR ?? "",
                        screenshotPath: record.screenshot,
                        capturedAt: record.capturedAt
                    )

                    do {
                        let startTime = Date()
                        let result = try await processor.processSingle(capture: captureData, captureId: captureId)
                        let duration = Date().timeIntervalSince(startTime)

                        // 立即写入数据库
                        let finalResult = ProcessResult(
                            captureId: captureId,
                            name: result.name,
                            summary: result.summary,
                            passed: result.passed,
                            reason: result.reason,
                            rawJson: result.rawJson
                        )
                        try await db.writeResult(finalResult)

                        let passedStr = result.passed ? "✓ 通过" : "✗ 不通过"
                        let name = result.name ?? "未知"
                        print("[Gazein] [\(num)/\(total)] 完成 (\(String(format: "%.1f", duration))s) - \(name): \(passedStr) → 已写入数据库")
                        successCount += 1

                        // 避免请求过快
                        if index < total - 1 {
                            try await Task.sleep(nanoseconds: 500_000_000)
                        }
                    } catch {
                        print("[Gazein] [\(num)/\(total)] 处理失败: \(error.localizedDescription)")
                        failCount += 1
                        // 继续处理下一条，不中断
                    }
                }

                print("[Gazein] ✓ AI 处理完成: 成功 \(successCount) 条, 失败 \(failCount) 条")
                showAlert(title: "处理完成", message: "成功: \(successCount) 条\n失败: \(failCount) 条\n\n配置: \(profile.profileName)\n服务商: \(providerName)")

            } catch {
                print("[Gazein] 处理失败: \(error)")
                showAlert(title: "处理失败", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Export

    @objc private func exportOCRResults() {
        guard let profile = currentProfile, let db = database else {
            showAlert(title: "错误", message: "请先选择配置文件")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "\(profile.profileName)_ocr_\(formatFileDateTime(Date())).csv"
        savePanel.title = "导出 OCR 结果"
        savePanel.directoryURL = URL(fileURLWithPath: exportsDirectory(for: profile))

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }

            Task {
                do {
                    let captures = try await db.fetchAllCaptures()

                    if captures.isEmpty {
                        self?.showAlert(title: "提示", message: "没有数据可导出")
                        return
                    }

                    var csv = "序号,时间,OCR文本,截图路径\n"
                    for capture in captures {
                        let row = [
                            String(capture.seq),
                            self?.formatDateTime(capture.capturedAt) ?? "",
                            self?.escapeCSV(capture.rawOCR ?? "") ?? "",
                            self?.escapeCSV(capture.screenshot ?? "") ?? ""
                        ].joined(separator: ",")
                        csv += row + "\n"
                    }

                    try csv.write(to: url, atomically: true, encoding: .utf8)

                    print("[Gazein] ✓ 已导出 \(captures.count) 条记录到: \(url.path)")
                    NSWorkspace.shared.open(url)

                } catch {
                    self?.showAlert(title: "导出失败", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func exportAIResults() {
        guard let profile = currentProfile, let db = database else {
            showAlert(title: "错误", message: "请先选择配置文件")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "\(profile.profileName)_ai_\(formatFileDateTime(Date())).csv"
        savePanel.title = "导出 AI 处理结果"
        savePanel.directoryURL = URL(fileURLWithPath: exportsDirectory(for: profile))

        savePanel.begin { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }

            Task {
                do {
                    let results = try await db.fetchResultsWithCaptureTime()

                    if results.isEmpty {
                        self?.showAlert(title: "提示", message: "没有 AI 处理结果可导出\n请先进行批量处理")
                        return
                    }

                    // 根据是否有 rawJson 决定导出格式
                    let hasRawJson = results.contains { $0.rawJson != nil && !$0.rawJson!.isEmpty }

                    var csv: String
                    if hasRawJson {
                        // 新格式：解析 rawJson 导出详细字段
                        csv = self?.exportRichCSV(results: results) ?? ""
                    } else {
                        // 旧格式：简单字段
                        csv = self?.exportSimpleCSV(results: results) ?? ""
                    }

                    try csv.write(to: url, atomically: true, encoding: .utf8)

                    let passedCount = results.filter { $0.passed }.count
                    print("[Gazein] ✓ 已导出 \(results.count) 条 AI 结果 (通过: \(passedCount)) 到: \(url.path)")
                    NSWorkspace.shared.open(url)

                } catch {
                    self?.showAlert(title: "导出失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func exportSimpleCSV(results: [ResultWithCaptureTime]) -> String {
        var csv = "采集时间,处理时间,姓名,摘要,是否通过,原因\n"
        for result in results {
            let captureTimeStr = result.captureTime.map { formatDateTime($0) } ?? ""
            let processedTimeStr = formatDateTime(result.processedAt)
            let row = [
                captureTimeStr,
                processedTimeStr,
                escapeCSV(result.name ?? ""),
                escapeCSV(result.summary ?? ""),
                result.passed ? "通过" : "不通过",
                escapeCSV(result.reason ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    private func exportRichCSV(results: [ResultWithCaptureTime]) -> String {
        // 表头：采集时间, 姓名, 年龄, 工作年限, 学历, 应聘职位, 是否通过, 原因, 工作经历摘要, 教育摘要
        var csv = "采集时间,姓名,年龄,工作年限,学历,应聘职位,是否通过,原因,工作经历,教育背景\n"

        for result in results {
            let captureTimeStr = result.captureTime.map { formatDateTime($0) } ?? ""

            // 解析 rawJson
            var name = result.name ?? ""
            var age = ""
            var experienceYears = ""
            var educationLevel = ""
            var appliedPosition = result.summary ?? ""
            var passed = result.passed
            var reason = result.reason ?? ""
            var workSummary = ""
            var eduSummary = ""

            if let rawJson = result.rawJson,
               let jsonData = rawJson.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                name = json["name"] as? String ?? name
                if let ageNum = json["age"] as? Int {
                    age = String(ageNum)
                }
                experienceYears = json["experience_years"] as? String ?? ""
                educationLevel = json["education_level"] as? String ?? ""
                appliedPosition = json["applied_position"] as? String ?? appliedPosition

                // 从 screening 获取结果
                if let screening = json["screening"] as? [String: Any] {
                    passed = screening["passed"] as? Bool ?? passed
                    reason = screening["reason"] as? String ?? reason
                }

                // 工作经历摘要
                if let workExp = json["work_experience"] as? [[String: Any]] {
                    let summaries = workExp.compactMap { exp -> String? in
                        let company = exp["company"] as? String ?? ""
                        let title = exp["title"] as? String ?? ""
                        let valid = (exp["is_valid"] as? Bool ?? false) ? "✓" : "✗"
                        let relevant = (exp["is_relevant"] as? Bool ?? false) ? "相关" : ""
                        return "\(company)-\(title)[\(valid)\(relevant)]"
                    }
                    workSummary = summaries.joined(separator: "; ")
                }

                // 教育摘要
                if let edu = json["education"] as? [[String: Any]] {
                    let summaries = edu.compactMap { e -> String? in
                        let school = e["school"] as? String ?? ""
                        let degree = e["degree"] as? String ?? ""
                        let valid = (e["is_valid"] as? Bool ?? false) ? "✓" : "✗"
                        let is985211 = (e["is_985_211"] as? Bool ?? false) ? "985/211" : ""
                        return "\(school)-\(degree)[\(valid)\(is985211)]"
                    }
                    eduSummary = summaries.joined(separator: "; ")
                }
            }

            let row = [
                captureTimeStr,
                escapeCSV(name),
                age,
                experienceYears,
                escapeCSV(educationLevel),
                escapeCSV(appliedPosition),
                passed ? "通过" : "不通过",
                escapeCSV(reason),
                escapeCSV(workSummary),
                escapeCSV(eduSummary)
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // MARK: - Data Cleanup

    @objc private func showCleanupDialog() {
        guard let profile = currentProfile, let db = database else {
            showAlert(title: "错误", message: "请先选择配置文件")
            return
        }

        // 获取数据统计
        let stats: (captureCount: Int, resultCount: Int)
        do {
            stats = try db.getDataStats()
        } catch {
            showAlert(title: "错误", message: "无法读取数据统计: \(error.localizedDescription)")
            return
        }

        if stats.captureCount == 0 && stats.resultCount == 0 {
            showAlert(title: "提示", message: "没有数据需要清理")
            return
        }

        // 创建对话框
        let alert = NSAlert()
        alert.messageText = "清理数据"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        // 创建选项视图
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 150))

        // 数据统计标签
        let statsLabel = NSTextField(labelWithString: "当前数据: \(stats.captureCount) 条采集, \(stats.resultCount) 条 AI 结果")
        statsLabel.frame = NSRect(x: 0, y: 125, width: 320, height: 20)
        containerView.addSubview(statsLabel)

        // 归档选项
        let archiveRadio = NSButton(radioButtonWithTitle: "归档数据", target: nil, action: nil)
        archiveRadio.frame = NSRect(x: 0, y: 95, width: 320, height: 20)
        archiveRadio.state = .on
        containerView.addSubview(archiveRadio)

        let archiveDesc = NSTextField(labelWithString: "(数据保留，不出现在导出中)")
        archiveDesc.frame = NSRect(x: 20, y: 75, width: 300, height: 16)
        archiveDesc.textColor = .secondaryLabelColor
        archiveDesc.font = .systemFont(ofSize: 11)
        containerView.addSubview(archiveDesc)

        // 清空选项
        let clearRadio = NSButton(radioButtonWithTitle: "清空数据", target: nil, action: nil)
        clearRadio.frame = NSRect(x: 0, y: 50, width: 320, height: 20)
        clearRadio.state = .off
        containerView.addSubview(clearRadio)

        let clearDesc = NSTextField(labelWithString: "(永久删除所有数据)")
        clearDesc.frame = NSRect(x: 20, y: 30, width: 300, height: 16)
        clearDesc.textColor = .secondaryLabelColor
        clearDesc.font = .systemFont(ofSize: 11)
        containerView.addSubview(clearDesc)

        // 清空前导出选项
        let exportCheckbox = NSButton(checkboxWithTitle: "清空前先导出", target: nil, action: nil)
        exportCheckbox.frame = NSRect(x: 20, y: 5, width: 200, height: 20)
        exportCheckbox.state = .on
        exportCheckbox.isEnabled = false
        containerView.addSubview(exportCheckbox)

        // 设置单选按钮互斥
        archiveRadio.target = self
        archiveRadio.action = #selector(cleanupRadioChanged(_:))
        clearRadio.target = self
        clearRadio.action = #selector(cleanupRadioChanged(_:))

        objc_setAssociatedObject(archiveRadio, "otherRadio", clearRadio, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(clearRadio, "otherRadio", archiveRadio, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(archiveRadio, "exportCheckbox", exportCheckbox, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(clearRadio, "exportCheckbox", exportCheckbox, .OBJC_ASSOCIATION_RETAIN)

        alert.accessoryView = containerView

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let isArchive = archiveRadio.state == .on
            let exportBeforeClear = exportCheckbox.state == .on

            if isArchive {
                performArchive(profile: profile, db: db)
            } else {
                performClear(profile: profile, db: db, exportFirst: exportBeforeClear)
            }
        }
    }

    @objc private func cleanupRadioChanged(_ sender: NSButton) {
        guard let otherRadio = objc_getAssociatedObject(sender, "otherRadio") as? NSButton,
              let exportCheckbox = objc_getAssociatedObject(sender, "exportCheckbox") as? NSButton else { return }

        if sender.state == .on {
            otherRadio.state = .off
        }

        // 只有选择清空时才启用导出选项
        let isClearSelected = sender.title == "清空数据" && sender.state == .on ||
                              otherRadio.title == "清空数据" && otherRadio.state == .on
        exportCheckbox.isEnabled = isClearSelected
    }

    private func performArchive(profile: Profile, db: Database) {
        Task {
            do {
                let (archivedCaptures, archivedResults) = try await db.archiveAllData()
                print("[Gazein] ✓ 已归档 \(archivedCaptures) 条采集, \(archivedResults) 条 AI 结果")
                showAlert(title: "归档完成", message: "已归档 \(archivedCaptures) 条采集, \(archivedResults) 条 AI 结果\n\n归档数据不会出现在导出中，但保留在数据库可恢复。")
            } catch {
                print("[Gazein] 归档失败: \(error)")
                showAlert(title: "归档失败", message: error.localizedDescription)
            }
        }
    }

    private func performClear(profile: Profile, db: Database, exportFirst: Bool) {
        Task {
            do {
                // 如果需要先导出
                if exportFirst {
                    let exportsDir = exportsDirectory(for: profile)
                    let timestamp = formatFileDateTime(Date())

                    // 导出 OCR 结果
                    let captures = try await db.fetchAllCaptures()
                    if !captures.isEmpty {
                        let ocrFilename = "\(profile.profileName)_ocr_\(timestamp).csv"
                        let ocrPath = (exportsDir as NSString).appendingPathComponent(ocrFilename)

                        var ocrCsv = "序号,时间,OCR文本,截图路径\n"
                        for capture in captures {
                            let row = [
                                String(capture.seq),
                                formatDateTime(capture.capturedAt),
                                escapeCSV(capture.rawOCR ?? ""),
                                escapeCSV(capture.screenshot ?? "")
                            ].joined(separator: ",")
                            ocrCsv += row + "\n"
                        }
                        try ocrCsv.write(toFile: ocrPath, atomically: true, encoding: .utf8)
                        print("[Gazein] ✓ OCR 导出: \(ocrPath)")
                    }

                    // 导出 AI 结果
                    let results = try await db.fetchResultsWithCaptureTime()
                    if !results.isEmpty {
                        let aiFilename = "\(profile.profileName)_ai_\(timestamp).csv"
                        let aiPath = (exportsDir as NSString).appendingPathComponent(aiFilename)

                        let hasRawJson = results.contains { $0.rawJson != nil && !$0.rawJson!.isEmpty }
                        let aiCsv = hasRawJson ? exportRichCSV(results: results) : exportSimpleCSV(results: results)
                        try aiCsv.write(toFile: aiPath, atomically: true, encoding: .utf8)
                        print("[Gazein] ✓ AI 导出: \(aiPath)")
                    }
                }

                // 清空数据
                try await db.clearAllData()

                var message = "已清空所有数据"
                if exportFirst {
                    message += "\n\n数据已导出到:\n~/Gazein/\(profile.profileName)/exports/"
                }

                print("[Gazein] ✓ 已清空所有数据")
                showAlert(title: "清空完成", message: message)

            } catch {
                print("[Gazein] 清空失败: \(error)")
                showAlert(title: "清空失败", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Folder Actions

    @objc private func openDataFolder() {
        guard let profile = currentProfile else {
            showAlert(title: "提示", message: "请先选择配置")
            return
        }
        let path = dataDirectory(for: profile)
        ensureDataDirectories(for: profile)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func openConfigFolder() {
        let path = NSString(string: "~/.gazein/profiles").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func openAPIKeyConfig() {
        let secretsPath = NSString(string: "~/.gazein/secrets.json").expandingTildeInPath
        let fm = FileManager.default

        // 确保目录存在
        let dir = (secretsPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // 如果文件不存在，创建模板
        if !fm.fileExists(atPath: secretsPath) {
            let template = """
            {
              "DEEPSEEK_API_KEY": "",
              "MOONSHOT_API_KEY": "",
              "OPENAI_API_KEY": ""
            }
            """
            try? template.write(toFile: secretsPath, atomically: true, encoding: .utf8)
            print("[Gazein] 已创建 API Key 配置模板: \(secretsPath)")
        }

        // 用默认编辑器打开
        NSWorkspace.shared.open(URL(fileURLWithPath: secretsPath))
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatFileDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private func escapeCSV(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        if escaped.contains(",") || escaped.contains("\"") {
            return "\"\(escaped.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return escaped
    }
}
