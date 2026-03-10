import AppKit

/// 菜单栏 UI 控制器
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var pipeline: Pipeline?

    init() {
        setupStatusItem()
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
        let profileItem = NSMenuItem(title: "当前配置: 无", action: nil, keyEquivalent: "")
        menu.addItem(profileItem)

        // 状态
        let statusItem = NSMenuItem(title: "状态: 未运行", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 开始/停止
        menu.addItem(NSMenuItem(title: "开始采集", action: #selector(startCollection), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "停止采集", action: #selector(stopCollection), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 配置工具
        menu.addItem(NSMenuItem(title: "选择区域", action: #selector(selectRegion), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置按键", action: #selector(setKey), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 处理与导出
        menu.addItem(NSMenuItem(title: "批量处理", action: #selector(batchProcess), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "导出 CSV", action: #selector(exportCSV), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开配置文件夹", action: #selector(openConfigFolder), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // 设置 target
        for item in menu.items {
            item.target = self
        }

        return menu
    }

    @objc private func startCollection() {
        // TODO: 实现开始采集
    }

    @objc private func stopCollection() {
        // TODO: 实现停止采集
    }

    @objc private func selectRegion() {
        // TODO: 打开区域选择遮罩
    }

    @objc private func setKey() {
        // TODO: 打开按键监听弹窗
    }

    @objc private func batchProcess() {
        // TODO: 实现批量处理
    }

    @objc private func exportCSV() {
        // TODO: 实现 CSV 导出
    }

    @objc private func openConfigFolder() {
        let path = NSString(string: "~/.gazein/profiles").expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
