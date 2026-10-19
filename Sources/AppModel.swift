import AppKit
import AVFoundation
import Combine
import IOKit.ps
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: LibraryState
    @Published var selectedID = BuiltinScene.aurora.rawValue
    @Published var page = "library"
    @Published var libraryFilter = "all"
    @Published var videoToDelete: VideoWallpaper?
    @Published var errorMessage: String?
    @Published private(set) var isImporting = false
    @Published private(set) var pauseReason: PauseReason?
    @Published private(set) var displayCount = NSScreen.screens.count
    @Published var previewVisible = true
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    let store: LibraryStore
    let engine = WallpaperEngine()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var observers: [NSObjectProtocol] = []
    private var powerTimer: Timer?
    private var screenSleeping = false
    private var systemSleeping = false
    private var inactive = false
    var onStatusChange: (() -> Void)?

    var preferences: Preferences { state.preferences }
    var videos: [VideoWallpaper] { state.videos }
    var selectedScene: BuiltinScene? { BuiltinScene(rawValue: selectedID) }
    var selectedVideo: VideoWallpaper? { videos.first { $0.id == selectedID } }
    var selectedTitle: String { selectedScene?.title ?? selectedVideo?.name ?? "选择壁纸" }
    var activeTitle: String {
        BuiltinScene(rawValue: preferences.appliedID)?.title ?? videos.first { $0.id == preferences.appliedID }?.name ?? "未选择"
    }
    var status: String { !preferences.enabled ? "尚未开启" : pauseReason?.title ?? "正在播放" }
    var isPlaying: Bool { preferences.enabled && pauseReason == nil }
    var previewAnimating: Bool { previewVisible && pauseReason == nil }

    init(root: URL? = nil, observeSystem: Bool = true) {
        let directory = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LumaDesktop", isDirectory: true)
        store = LibraryStore(root: directory)
        var initialError: String?
        do { try store.prepare(); state = try store.load() }
        catch { state = LibraryState(); initialError = "读取壁纸库失败：\(error.localizedDescription)" }
        state.preferences.brightness = min(1, max(0.15, state.preferences.brightness))
        if BuiltinScene(rawValue: state.preferences.appliedID) == nil && !state.videos.contains(where: { $0.id == state.preferences.appliedID }) {
            state.preferences.appliedID = BuiltinScene.aurora.rawValue
            state.preferences.enabled = false
        }
        selectedID = state.preferences.appliedID
        errorMessage = initialError
        engine.onPlaybackError = { [weak self] message in
            self?.stop(); self?.errorMessage = "无法播放这个视频：\(message)"
        }
        if observeSystem { installObservers(); refreshLoginStatus() }
        refreshPowerState()
    }

    func restoreWallpaper() {
        guard preferences.enabled else { return }
        apply(id: preferences.appliedID, resetPause: false)
    }
    func applySelected() { apply(id: selectedID, resetPause: true) }
    private func apply(id: String, resetPause: Bool) {
        var next = preferences
        next.appliedID = id; next.enabled = true
        if resetPause { next.userPaused = false }
        let videoURL = videos.first { $0.id == id }.map { mediaURL($0.fileName) }
        do {
            let reason = calculatePause(next)
            try engine.apply(id: id, videoURL: videoURL, preferences: next, paused: reason != nil)
            state.preferences = next; pauseReason = reason
            persist(); onStatusChange?()
        } catch {
            errorMessage = error.localizedDescription
            if engine.windows.isEmpty { state.preferences.enabled = false; persist() }
        }
    }
    func stop() {
        engine.stop(); state.preferences.enabled = false
        state.preferences.userPaused = false; pauseReason = nil
        persist(); onStatusChange?()
    }
    func togglePause() {
        guard preferences.enabled else { applySelected(); return }
        state.preferences.userPaused.toggle()
        refreshPowerState(); persist()
    }
    func updatePreferences(_ update: (inout Preferences) -> Void) {
        let oldAll = preferences.allDisplays
        update(&state.preferences)
        state.preferences.brightness = min(1, max(0.15, state.preferences.brightness))
        if preferences.enabled && oldAll != preferences.allDisplays {
            apply(id: preferences.appliedID, resetPause: false)
        } else {
            engine.updateAppearance(preferences)
            refreshPowerState(); persist()
        }
    }
    func mediaURL(_ filename: String) -> URL {
        store.mediaDirectory.appendingPathComponent((filename as NSString).lastPathComponent)
    }
    private func persist() {
        do { try store.save(state) }
        catch { errorMessage = "保存设置失败：\(error.localizedDescription)" }
    }

    func chooseVideo() {
        guard !isImporting else { return }
        let panel = NSOpenPanel()
        panel.title = "导入动态壁纸"
        panel.message = "选择本地视频。导入后会保存一份副本，原文件不会被修改。"
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "导入视频"
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in await self?.importVideos(panel.urls) }
        }
    }
    func importVideos(_ urls: [URL]) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        var failures: [String] = []
        for url in urls {
            do { try await importVideo(url) }
            catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
        }
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
    }
    func importVideo(_ url: URL) async throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let duration = try await asset.load(.duration).seconds
        guard playable, let track = tracks.first, duration.isFinite, duration > 0 else {
            throw NSError(domain: "LumaDesktop", code: 2, userInfo: [NSLocalizedDescriptionKey: "这不是可播放的视频，请使用 H.264 或 HEVC 编码的 MP4 / MOV。"])
        }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let dimensions = size.applying(transform)
        let id = UUID().uuidString
        let filename = id + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension.lowercased())
        let destination = mediaURL(filename)
        do {
            try await Task.detached(priority: .userInitiated) {
                try FileManager.default.copyItem(at: url, to: destination)
            }.value
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        var thumbnail: String?
        do {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 960, height: 600)
            let result = try await generator.image(at: CMTime(seconds: min(1, duration / 2), preferredTimescale: 600))
            let bitmap = NSBitmapImageRep(cgImage: result.image)
            if let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                let name = id + ".jpg"
                try data.write(to: mediaURL(name), options: .atomic)
                thumbnail = name
            }
            let video = VideoWallpaper(id: id, name: url.deletingPathExtension().lastPathComponent, fileName: filename, thumbnailName: thumbnail, duration: duration, width: Int(abs(dimensions.width)), height: Int(abs(dimensions.height)))
            var next = state; next.videos.append(video)
            try store.save(next)
            state = next; selectedID = id; page = "library"
        } catch {
            try? FileManager.default.removeItem(at: destination)
            if let thumbnail { try? FileManager.default.removeItem(at: mediaURL(thumbnail)) }
            throw error
        }
    }
    func removeVideo(_ video: VideoWallpaper) {
        if preferences.appliedID == video.id { stop() }
        var next = state
        next.videos.removeAll { $0.id == video.id }
        if next.preferences.appliedID == video.id { next.preferences.appliedID = BuiltinScene.aurora.rawValue }
        do {
            try store.save(next)
            state = next
            if selectedID == video.id { selectedID = BuiltinScene.aurora.rawValue }
            try FileManager.default.removeItem(at: mediaURL(video.fileName))
            if let name = video.thumbnailName { try? FileManager.default.removeItem(at: mediaURL(name)) }
        } catch { errorMessage = "移除视频时遇到问题：\(error.localizedDescription)" }
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = "修改登录启动失败。可将应用移到「应用程序」后重试。\n\(error.localizedDescription)"
        }
        refreshLoginStatus()
    }
    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    private func calculatePause(_ prefs: Preferences) -> PauseReason? {
        var onBattery = false
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() {
            onBattery = (source as String) == kIOPSBatteryPowerValue
        }
        return PauseReason.resolve(preferences: prefs, sleeping: screenSleeping || systemSleeping, inactive: inactive, onBattery: onBattery, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
    func refreshPowerState() {
        pauseReason = calculatePause(preferences)
        engine.setPaused(pauseReason != nil)
        onStatusChange?()
    }
    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, (AppModel) -> Void)] = [
            (NSWorkspace.screensDidSleepNotification, { $0.screenSleeping = true }),
            (NSWorkspace.screensDidWakeNotification, { $0.screenSleeping = false }),
            (NSWorkspace.willSleepNotification, { $0.systemSleeping = true }),
            (NSWorkspace.didWakeNotification, { $0.systemSleeping = false }),
            (NSWorkspace.sessionDidResignActiveNotification, { $0.inactive = true }),
            (NSWorkspace.sessionDidBecomeActiveNotification, { $0.inactive = false })
        ]
        for (event, action) in events {
            workspaceObservers.append(center.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in guard let self else { return }; action(self); self.refreshPowerState() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.displayCount = NSScreen.screens.count
                if self.preferences.enabled { self.apply(id: self.preferences.appliedID, resetPause: false) }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshPowerState() }
        })
        powerTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPowerState() }
        }
    }
}
