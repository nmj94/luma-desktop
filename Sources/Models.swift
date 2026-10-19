import Foundation

enum BuiltinScene: String, Codable, CaseIterable, Identifiable {
    case aurora, ocean, ember, cosmos
    var id: String { rawValue }
    var title: String {
        switch self { case .aurora: return "极光漫游"; case .ocean: return "深海呼吸"; case .ember: return "日落余温"; case .cosmos: return "星际漂流" }
    }
    var subtitle: String {
        switch self { case .aurora: return "让一抹极光，缓缓流过桌面。"; case .ocean: return "沉入蓝色，给专注留一点空间。"; case .ember: return "把日落的最后一分钟，留在这里。"; case .cosmos: return "在安静的星海里，慢慢漂流。" }
    }
    var label: String {
        switch self { case .aurora: return "AURORA"; case .ocean: return "DEEP BLUE"; case .ember: return "AFTERGLOW"; case .cosmos: return "STARDUST" }
    }
    var colors: [UInt32] {
        switch self {
        case .aurora: return [0x030C19, 0x103244, 0x49E0B0, 0x5365DA, 0x8A4CD9]
        case .ocean: return [0x020B1B, 0x062342, 0x167DC2, 0x37CDD8, 0x22448D]
        case .ember: return [0x170F25, 0x562640, 0xF38567, 0xD04E6A, 0xC1A185]
        case .cosmos: return [0x07091C, 0x20163B, 0x8661C9, 0x4D62CA, 0xC189B7]
        }
    }
}

struct VideoWallpaper: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let fileName: String
    let thumbnailName: String?
    let duration: Double
    let width: Int
    let height: Int
    var detail: String { "\(width) × \(height)  ·  \(Int(duration.rounded())) 秒" }
}

enum VideoFit: String, Codable, CaseIterable {
    case fill, fit
    var title: String { self == .fill ? "填满屏幕" : "完整显示" }
}

struct Preferences: Codable, Equatable {
    var appliedID = BuiltinScene.aurora.rawValue
    var enabled = false
    var userPaused = false
    var allDisplays = true
    var pauseOnBattery = false
    var pauseInLowPower = true
    var fit = VideoFit.fill
    var brightness = 0.85
}

struct LibraryState: Codable, Equatable {
    var version = 1
    var preferences = Preferences()
    var videos: [VideoWallpaper] = []
}

enum PauseReason: Equatable {
    case manual, sleeping, inactiveSession, battery, lowPower
    var title: String {
        switch self {
        case .manual: return "已暂停"
        case .sleeping: return "屏幕休眠，已暂停"
        case .inactiveSession: return "会话未激活，已暂停"
        case .battery: return "使用电池，已暂停"
        case .lowPower: return "低电量模式，已暂停"
        }
    }
    static func resolve(preferences: Preferences, sleeping: Bool, inactive: Bool, onBattery: Bool, lowPower: Bool) -> PauseReason? {
        if preferences.userPaused { return .manual }
        if sleeping { return .sleeping }
        if inactive { return .inactiveSession }
        if preferences.pauseOnBattery && onBattery { return .battery }
        if preferences.pauseInLowPower && lowPower { return .lowPower }
        return nil
    }
}

struct LibraryStore {
    let root: URL
    var mediaDirectory: URL { root.appendingPathComponent("Media", isDirectory: true) }
    var stateURL: URL { root.appendingPathComponent("library.json") }
    func prepare() throws { try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true) }
    func load() throws -> LibraryState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return LibraryState() }
        let state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
        guard state.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }
    func save(_ state: LibraryState) throws {
        try prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: .atomic)
    }
}
