import Foundation

enum BuiltinScene: String, Codable, CaseIterable, Identifiable {
    case aurora, ocean, ember, cosmos
    var id: String { rawValue }
    var title: String { title(in: .system) }
    func title(in language: AppLanguage) -> String {
        let key: TextKey
        switch self { case .aurora: key = .auroraTitle; case .ocean: key = .oceanTitle; case .ember: key = .emberTitle; case .cosmos: key = .cosmosTitle }
        return key.string(in: language)
    }
    func subtitle(in language: AppLanguage) -> String {
        let key: TextKey
        switch self { case .aurora: key = .auroraSubtitle; case .ocean: key = .oceanSubtitle; case .ember: key = .emberSubtitle; case .cosmos: key = .cosmosSubtitle }
        return key.string(in: language)
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
    func detail(in language: AppLanguage) -> String {
        TextKey.videoDetail.string(in: language, arguments: [width, height, Int(duration.rounded())])
    }
}

enum VideoFit: String, Codable, CaseIterable {
    case fill, fit
    func title(in language: AppLanguage) -> String {
        (self == .fill ? TextKey.fillScreen : .fitScreen).string(in: language)
    }
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
    var language = AppLanguage.system

    init() {}
    private enum CodingKeys: String, CodingKey {
        case appliedID, enabled, userPaused, allDisplays, pauseOnBattery, pauseInLowPower, fit, brightness, language
    }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appliedID = try values.decodeIfPresent(String.self, forKey: .appliedID) ?? appliedID
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        userPaused = try values.decodeIfPresent(Bool.self, forKey: .userPaused) ?? userPaused
        allDisplays = try values.decodeIfPresent(Bool.self, forKey: .allDisplays) ?? allDisplays
        pauseOnBattery = try values.decodeIfPresent(Bool.self, forKey: .pauseOnBattery) ?? pauseOnBattery
        pauseInLowPower = try values.decodeIfPresent(Bool.self, forKey: .pauseInLowPower) ?? pauseInLowPower
        fit = try values.decodeIfPresent(VideoFit.self, forKey: .fit) ?? fit
        brightness = try values.decodeIfPresent(Double.self, forKey: .brightness) ?? brightness
        // Version 1 libraries have no language field. Keep every existing setting.
        let code = try values.decodeIfPresent(String.self, forKey: .language)
        language = code.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }
}

struct LibraryState: Codable, Equatable {
    var version = 1
    var preferences = Preferences()
    var videos: [VideoWallpaper] = []
}

enum PauseReason: Equatable {
    case manual, sleeping, inactiveSession, battery, lowPower
    func title(in language: AppLanguage) -> String {
        let key: TextKey
        switch self {
        case .manual: key = .paused
        case .sleeping: key = .pausedSleeping
        case .inactiveSession: key = .pausedSession
        case .battery: key = .pausedBattery
        case .lowPower: key = .pausedLowPower
        }
        return key.string(in: language)
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
