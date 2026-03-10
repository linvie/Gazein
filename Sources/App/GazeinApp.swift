import AppKit

@main
struct GazeinApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保默认配置文件存在
        DefaultProfile.ensureDefaultProfileExists()

        // 初始化菜单栏控制器
        menuBarController = MenuBarController()
    }
}
