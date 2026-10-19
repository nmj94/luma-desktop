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
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: model.text(.appName))
        statusItem.button?.toolTip = model.text(.appName)
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        model.onStatusChange = { [weak self] in self?.updateStatusItem() }
        model.onLanguageChange = { [weak self] in self?.refreshLanguage() }

        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1120, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = model.text(.appName)
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
        appItem.title = model.text(.appName); appMenu.title = model.text(.appName)
        appMenu.addItem(withTitle: model.text(.aboutApp), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: model.text(.preferences) + "…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: model.text(.hideApp), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: model.text(.quitApp), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let fileItem = NSMenuItem(); fileItem.title = model.text(.fileMenu); let fileMenu = NSMenu(title: model.text(.fileMenu))
        fileMenu.addItem(withTitle: model.text(.importVideo) + "…", action: #selector(importVideo), keyEquivalent: "o")
        fileMenu.addItem(withTitle: model.text(.closeWindow), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu; mainMenu.addItem(fileItem)
        let windowItem = NSMenuItem(); windowItem.title = model.text(.windowMenu); let windowMenu = NSMenu(title: model.text(.windowMenu))
        windowMenu.addItem(withTitle: model.text(.library), action: #selector(showLibrary), keyEquivalent: "1")
        windowMenu.addItem(withTitle: model.text(.minimize), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu; mainMenu.addItem(windowItem)
        NSApp.mainMenu = mainMenu
    }
    private func updateStatusItem() {
        statusItem.button?.toolTip = "\(model.text(.appName)) · \(model.status)"
        statusItem.button?.setAccessibilityLabel(model.text(.appName))
    }
    private func refreshLanguage() {
        installMainMenu()
        window?.title = model.text(.appName)
        updateStatusItem()
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: model.preferences.enabled ? "\(model.activeTitle) · \(model.status)" : "\(model.text(.appName)) · \(model.status)", action: nil, keyEquivalent: "")
        status.isEnabled = false; menu.addItem(status); menu.addItem(.separator())
        addMenuItem(menu, model.text(.openLibrary), #selector(showLibrary), key: "1")
        if model.preferences.enabled {
            addMenuItem(menu, model.preferences.userPaused ? model.text(.resumePlayback) : model.text(.pausePlayback), #selector(togglePause))
            addMenuItem(menu, model.text(.stopWallpaper), #selector(stopWallpaper))
        } else { addMenuItem(menu, model.text(.startWallpaper), #selector(togglePause)) }
        addMenuItem(menu, model.text(.preferences) + "…", #selector(showSettings), key: ",")
        menu.addItem(.separator())
        addMenuItem(menu, model.text(.quitApp), #selector(quit), key: "q")
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
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: model.text(.appName), .applicationVersion: model.appVersion, .credits: NSAttributedString(string: model.text(.headline) + "\n" + model.text(.aboutDescription))])
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
