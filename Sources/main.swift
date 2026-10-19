import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var model: AppModel!
    var window: NSWindow!
    private var statusItem: NSStatusItem!
    private let testing = CommandLine.arguments.contains("--self-test")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let testRoot = testing ? URL(fileURLWithPath: ProcessInfo.processInfo.environment["LUMA_TEST_ROOT"] ?? NSTemporaryDirectory() + "LumaDesktopTests") : nil
        model = AppModel(root: testRoot, observeSystem: !testing)
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "流光桌面")
        statusItem.button?.toolTip = "流光桌面"
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        model.onStatusChange = { [weak self] in self?.statusItem.button?.toolTip = "流光桌面 · \(self?.model.status ?? "")" }

        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "流光桌面"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(rgb: 0x10151D)
        window.minSize = NSSize(width: 980, height: 720)
        window.isReleasedWhenClosed = false
        window.delegate = self
        let hosting = NSHostingView(rootView: MainView(model: model).padding(.top, 28).background(Color(rgb: 0x10151D)))
        window.contentView = hosting
        window.center()
        if !testing { window.setFrameAutosaveName("LumaLibraryWindow") }
        showWindow()
        if testing {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                await runIntegrationChecks(model: model, window: window)
            }
        } else { model.restoreWallpaper() }
    }

    func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于流光桌面", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "偏好设置…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏流光桌面", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出流光桌面", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let fileItem = NSMenuItem(); fileItem.title = "文件"; let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(withTitle: "导入视频…", action: #selector(importVideo), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu; mainMenu.addItem(fileItem)
        let windowItem = NSMenuItem(); windowItem.title = "窗口"; let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "壁纸库", action: #selector(showLibrary), keyEquivalent: "1")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu; mainMenu.addItem(windowItem)
        NSApp.mainMenu = mainMenu
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: model.preferences.enabled ? "\(model.activeTitle) · \(model.status)" : "流光桌面 · 尚未开启", action: nil, keyEquivalent: "")
        status.isEnabled = false; menu.addItem(status); menu.addItem(.separator())
        addMenuItem(menu, "打开壁纸库", #selector(showLibrary), key: "1")
        if model.preferences.enabled {
            addMenuItem(menu, model.preferences.userPaused ? "继续播放" : "暂停播放", #selector(togglePause))
            addMenuItem(menu, "停止并恢复原桌面", #selector(stopWallpaper))
        } else { addMenuItem(menu, "开启动态壁纸", #selector(togglePause)) }
        addMenuItem(menu, "偏好设置…", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        addMenuItem(menu, "退出流光桌面", #selector(quit), key: "q")
    }
    private func addMenuItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.previewVisible = true
    }
    @objc func showLibrary() { model.page = "library"; showWindow() }
    @objc func showSettings() { model.page = "settings"; model.refreshLoginStatus(); showWindow() }
    @objc func importVideo() { showWindow(); model.chooseVideo() }
    @objc func togglePause() { model.togglePause() }
    @objc func stopWallpaper() { model.stop() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "流光桌面", .applicationVersion: "1.0.0", .credits: NSAttributedString(string: "给桌面，一点生命。\n原生动态光影 · 本地视频壁纸")])
    }
    func windowWillClose(_ notification: Notification) { model.previewVisible = false }
    func windowDidChangeOcclusionState(_ notification: Notification) { model.previewVisible = window.occlusionState.contains(.visible) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.engine.stop() }
    func application(_ application: NSApplication, open urls: [URL]) { showWindow(); Task { await model.importVideos(urls) } }
}

@main
enum LumaApplication {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}
