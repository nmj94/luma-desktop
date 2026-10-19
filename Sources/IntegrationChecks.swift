import AppKit
import AVFoundation

@MainActor
func runIntegrationChecks(model: AppModel, window: NSWindow) async {
    let environment = ProcessInfo.processInfo.environment
    let artifactRoot = URL(fileURLWithPath: environment["LUMA_ARTIFACT_ROOT"] ?? NSTemporaryDirectory() + "LumaArtifacts")
    try? FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
    var checks: [[String: Any]] = []
    func check(_ value: Bool, _ name: String) {
        checks.append(["name": name, "passed": value]); print("\(value ? "PASS" : "FAIL"): \(name)")
    }
    func snapshot(_ name: String) {
        guard let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: artifactRoot.appendingPathComponent(name + ".png")) }
    }
    check(window.isVisible, "主窗口可见")
    check(model.engine.windows.isEmpty, "首次运行不会自动覆盖桌面")
    snapshot("library")
    for scene in BuiltinScene.allCases {
        model.selectedID = scene.rawValue; model.applySelected()
        check(model.engine.windows.count == NSScreen.screens.count, "\(scene.title)：每个显示器都有桌面窗口")
        check(model.engine.windows.allSatisfy { $0.ignoresMouseEvents && !$0.canBecomeKey && $0.level.rawValue < Int(CGWindowLevelForKey(.desktopIconWindow)) }, "\(scene.title)：图标和鼠标不受影响")
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    model.togglePause()
    check(model.pauseReason == .manual, "内置壁纸手动暂停")
    model.togglePause()
    check(model.pauseReason == nil, "内置壁纸恢复")
    model.updatePreferences { $0.allDisplays = false; $0.brightness = 0.64; $0.fit = .fit }
    check(model.engine.windows.count == min(1, NSScreen.screens.count), "只应用到主显示器")
    do {
        let persisted = try model.store.load()
        check(persisted.preferences.brightness == 0.64 && persisted.preferences.fit == .fit, "实际应用设置持久化")
    } catch { check(false, "实际应用设置持久化：\(error)") }
    model.stop()
    check(model.engine.windows.isEmpty && model.engine.player == nil, "停止清理窗口和播放器，显示原桌面")
    model.page = "settings"
    try? await Task.sleep(nanoseconds: 350_000_000)
    snapshot("settings")
    model.page = "library"
    if let videoPath = environment["LUMA_TEST_VIDEO"] {
        do {
            let source = URL(fileURLWithPath: videoPath)
            try await model.importVideo(source)
            check(model.videos.count == 1 && model.selectedVideo?.width == 640, "导入真实视频并读取尺寸")
            check(model.selectedVideo?.thumbnailName != nil, "生成视频缩略图")
            model.applySelected()
            try? await Task.sleep(nanoseconds: 700_000_000)
            let firstItem = model.engine.player?.currentItem
            check(model.engine.player?.rate == 1 && (model.engine.player?.currentTime().seconds ?? 0) > 0.1, "视频实际播放进度前进")
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            check(model.engine.player?.currentItem !== firstItem && model.engine.player?.rate == 1, "视频结束后进入下一轮循环")
            model.togglePause()
            let pausedTime = model.engine.player?.currentTime().seconds ?? -1
            try? await Task.sleep(nanoseconds: 250_000_000)
            check(model.engine.player?.rate == 0 && abs((model.engine.player?.currentTime().seconds ?? -2) - pausedTime) < 0.05, "暂停后视频进度不再前进")
            model.togglePause()
            try? await Task.sleep(nanoseconds: 200_000_000)
            check(model.engine.player?.rate == 1, "视频恢复播放")
            snapshot("video")
            let invalid = artifactRoot.appendingPathComponent("invalid.mp4")
            try Data("invalid media".utf8).write(to: invalid)
            do { try await model.importVideo(invalid); check(false, "拒绝无效视频") }
            catch { check(model.videos.count == 1, "拒绝无效视频且不污染壁纸库") }
            if let video = model.selectedVideo {
                let imported = model.mediaURL(video.fileName)
                model.removeVideo(video)
                check(model.videos.isEmpty && !FileManager.default.fileExists(atPath: imported.path), "移除视频同时清理副本")
                check(FileManager.default.fileExists(atPath: source.path), "移除视频保留原始文件")
                check(model.engine.windows.isEmpty, "移除正在播放的视频会恢复桌面")
            }
        } catch { check(false, "视频流程：\(error.localizedDescription)") }
    } else { check(false, "缺少测试视频") }
    model.stop()
    model.selectedID = BuiltinScene.aurora.rawValue
    model.updatePreferences { $0 = Preferences() }
    let success = checks.allSatisfy { $0["passed"] as? Bool == true }
    let report: [String: Any] = ["passed": success, "checks": checks, "screenCount": NSScreen.screens.count, "system": ProcessInfo.processInfo.operatingSystemVersionString]
    if let json = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
        try? json.write(to: artifactRoot.appendingPathComponent("integration-report.json"))
    }
    print("Integration checks \(success ? "PASSED" : "FAILED")")
    fflush(stdout)
    NSApp.terminate(nil)
}
