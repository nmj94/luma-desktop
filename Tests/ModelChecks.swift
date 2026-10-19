import Foundation

@main
struct ModelChecks {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }
            count += 1; print("PASS: \(name)")
        }
        var preferences = Preferences()
        func pause(sleep: Bool = false, inactive: Bool = false, battery: Bool = false, low: Bool = false) -> PauseReason? {
            PauseReason.resolve(preferences: preferences, sleeping: sleep, inactive: inactive, onBattery: battery, lowPower: low)
        }
        check(!preferences.enabled, "首次启动不替换桌面")
        check(pause(battery: true) == nil, "默认允许电池供电播放")
        check(pause(low: true) == .lowPower, "低电量模式暂停")
        check(pause(sleep: true) == .sleeping, "休眠暂停")
        check(pause(inactive: true) == .inactiveSession, "非活动会话暂停")
        preferences.pauseOnBattery = true
        check(pause(battery: true) == .battery, "电池省电策略")
        check(pause(battery: false) == nil, "接通电源恢复")
        preferences.userPaused = true
        check(pause(sleep: true, battery: true, low: true) == .manual, "手动暂停优先，唤醒不擅自恢复")
        check(pause() == .manual, "手动暂停在电源变化后保持")
        preferences.userPaused = false
        check(pause() == nil, "手动恢复")
        check(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]) == .simplifiedChinese, "跟随中文系统")
        check(AppLanguage.system.resolved(preferredLanguages: ["en-AU", "zh-Hans"]) == .english, "遵循系统语言优先级")
        check(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "zh-TW"]) == .simplifiedChinese, "使用后续支持的系统语言")
        check(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .english, "未支持的系统语言回退英文")
        check(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans"]) == .english, "手动语言优先于系统语言")
        check(TextKey.allCases.allSatisfy { !$0.rawValue.isEmpty && !$0.english.isEmpty }, "所有界面文案具有中英文翻译")
        let format = try NSRegularExpression(pattern: "%[@d]")
        func placeholders(_ text: String) -> [String] {
            format.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
        }
        check(TextKey.allCases.allSatisfy { placeholders($0.rawValue) == placeholders($0.english) }, "中英文动态文本参数保持一致")
        check(TextKey.removeNamedVideo.string(in: .english, arguments: ["海边 100%.mp4"]) == "Remove “海边 100%.mp4”", "翻译不改变用户文件名或百分号")

        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("LumaModelChecks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root)
        let empty = try store.load()
        check(empty == LibraryState(), "空壁纸库默认值")
        var state = LibraryState()
        state.preferences = preferences
        state.preferences.enabled = true
        state.preferences.appliedID = "video-1"
        state.videos = [VideoWallpaper(id: "video-1", name: "海边 日落", fileName: "a.mp4", thumbnailName: "a.jpg", duration: 2.5, width: 1920, height: 1080)]
        try store.save(state)
        let restored = try store.load()
        check(restored == state, "设置与中文视频信息完整持久化")
        state.preferences.fit = .fit
        try store.save(state)
        let updated = try store.load()
        check(updated == state, "原子更新现有配置")
        state.preferences.language = .english
        state.preferences.userPaused = true
        state.preferences.brightness = 0.42
        try store.save(state)
        let englishState = try store.load()
        check(englishState == state, "英文选择与现有壁纸设置完整持久化")
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        var legacyPreferences = legacy["preferences"] as! [String: Any]
        legacyPreferences.removeValue(forKey: "language")
        legacy["preferences"] = legacyPreferences
        let migrated = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: legacy))
        var expected = state; expected.preferences.language = .system
        check(migrated == expected, "旧版配置无语言字段时保留全部壁纸与设置")
        legacyPreferences["language"] = "future-language"
        legacy["preferences"] = legacyPreferences
        let unknown = try JSONDecoder().decode(LibraryState.self, from: JSONSerialization.data(withJSONObject: legacy))
        check(unknown == expected, "未知语言标识安全回退且不丢失数据")
        try Data("not json".utf8).write(to: store.stateURL)
        do { _ = try store.load(); fatalError("损坏状态未报错") } catch { count += 1; print("PASS: 损坏状态不会静默覆盖") }
        check(Set(BuiltinScene.allCases.map(\.id)).count == 4, "四个唯一内置场景")
        print("\(count) model checks passed")
    }
}
