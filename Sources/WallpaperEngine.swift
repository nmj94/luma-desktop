import AppKit
import AVFoundation
import QuartzCore

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class VideoSurface: NSView {
    let playerLayer = AVPlayerLayer()
    init(player: AVPlayer, fit: VideoFit) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.player = player
        playerLayer.videoGravity = fit == .fill ? .resizeAspectFill : .resizeAspect
        layer?.addSublayer(playerLayer)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

@MainActor
final class WallpaperEngine {
    private(set) var windows: [DesktopWindow] = []
    private(set) var players: [AVQueuePlayer] = []
    var player: AVQueuePlayer? { players.first }
    private var loopers: [AVPlayerLooper] = []
    private var scenes: [SceneView] = []
    private var surfaces: [VideoSurface] = []
    private var dimLayers: [CALayer] = []
    private var itemObservations: [NSKeyValueObservation] = []
    var onPlaybackError: ((String) -> Void)?

    func apply(id: String, videoURL: URL?, preferences: Preferences, paused: Bool) throws {
        let scene = BuiltinScene(rawValue: id)
        guard scene != nil || (videoURL != nil && FileManager.default.fileExists(atPath: videoURL!.path)) else {
            throw NSError(domain: "LumaDesktop", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到这个视频，请重新导入。"])
        }
        stop()
        let screens = preferences.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for screen in screens {
            let window = DesktopWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.hasShadow = false
            window.isOpaque = true
            window.backgroundColor = .black
            window.hidesOnDeactivate = false
            window.canHide = false
            window.isExcludedFromWindowsMenu = true
            window.setFrame(screen.frame, display: true)
            let root: NSView
            if let scene {
                let view = SceneView(scene: scene)
                scenes.append(view); root = view
            } else if let videoURL {
                // A separate player per screen keeps each AVPlayerLayer independent.
                let queue = AVQueuePlayer()
                queue.isMuted = true
                queue.preventsDisplaySleepDuringVideoPlayback = false
                players.append(queue)
                loopers.append(AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: videoURL)))
                itemObservations.append(queue.observe(\.currentItem?.status, options: [.new]) { [weak self] queue, _ in
                    guard queue.currentItem?.status == .failed else { return }
                    let message = queue.currentItem?.error?.localizedDescription ?? "视频播放失败，请尝试其他视频。"
                    Task { @MainActor in self?.onPlaybackError?(message) }
                })
                let view = VideoSurface(player: queue, fit: preferences.fit)
                surfaces.append(view); root = view
            } else { continue }
            window.contentView = root
            root.frame = CGRect(origin: .zero, size: screen.frame.size)
            root.layoutSubtreeIfNeeded()
            let dim = CALayer()
            dim.frame = root.bounds
            dim.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            dim.backgroundColor = NSColor.black.cgColor
            dim.opacity = Float(1 - preferences.brightness)
            root.layer?.addSublayer(dim)
            dimLayers.append(dim)
            window.orderFrontRegardless()
            windows.append(window)
        }
        setPaused(paused)
    }

    func updateAppearance(_ preferences: Preferences) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dimLayers.forEach { $0.opacity = Float(1 - preferences.brightness) }
        surfaces.forEach { $0.playerLayer.videoGravity = preferences.fit == .fill ? .resizeAspectFill : .resizeAspect }
        CATransaction.commit()
    }
    func setPaused(_ paused: Bool) {
        scenes.forEach { $0.setPaused(paused) }
        players.forEach { if paused { $0.pause() } else { $0.play() } }
    }
    func stop() {
        players.forEach { $0.pause() }
        itemObservations.removeAll()
        loopers.forEach { $0.disableLooping() }; loopers.removeAll()
        surfaces.forEach { $0.playerLayer.player = nil }
        players.forEach { $0.removeAllItems() }; players.removeAll()
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll(); scenes.removeAll(); surfaces.removeAll(); dimLayers.removeAll()
    }
}
