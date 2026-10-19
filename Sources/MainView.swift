import SwiftUI
import AVFoundation
import ServiceManagement

private let ink = Color(rgb: 0x0D1118)
private let panel = Color(rgb: 0x151B24)
private let muted = Color(rgb: 0x8994A6)
private let mint = Color(rgb: 0xA1F2CE)

struct VideoPreview: NSViewRepresentable {
    let url: URL
    let animated: Bool
    let fit: VideoFit
    final class Coordinator {
        let player = AVQueuePlayer()
        var looper: AVPlayerLooper?
        deinit { player.pause(); looper?.disableLooping(); player.removeAllItems() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> VideoSurface {
        let player = context.coordinator.player
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        return VideoSurface(player: player, fit: fit)
    }
    func updateNSView(_ nsView: VideoSurface, context: Context) {
        nsView.playerLayer.videoGravity = fit == .fill ? .resizeAspectFill : .resizeAspect
        if animated { context.coordinator.player.play() } else { context.coordinator.player.pause() }
    }
    static func dismantleNSView(_ nsView: VideoSurface, coordinator: Coordinator) {
        coordinator.player.pause(); coordinator.looper?.disableLooping(); coordinator.player.removeAllItems()
        nsView.playerLayer.player = nil
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 196)
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if model.page == "library" { library }
                    else if model.page == "settings" { settings }
                    else { help }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }.background(ink)
        }
        .background(ink)
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
        .tint(mint)
        .frame(minWidth: 960, minHeight: 690)
        .alert("遇到一点问题", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("知道了", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("从壁纸库移除这个视频？原始文件不受影响。", isPresented: Binding(get: { model.videoToDelete != nil }, set: { if !$0 { model.videoToDelete = nil } }), titleVisibility: .visible) {
            if let video = model.videoToDelete { Button("移除「\(video.name)」", role: .destructive) { model.removeVideo(video); model.videoToDelete = nil } }
            Button("取消", role: .cancel) { model.videoToDelete = nil }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("流光").font(.system(size: 22, weight: .semibold))
                    Text("LUMA DESKTOP").font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(muted)
                }
            }.padding(.top, 30).padding(.bottom, 43).padding(.leading, 22)
            Text("你的空间").font(.system(size: 10, weight: .medium)).foregroundStyle(muted).padding(.leading, 24).padding(.bottom, 14)
            navButton("壁纸库", icon: "square.grid.2x2", page: "library")
            navButton("偏好设置", icon: "slider.horizontal.3", page: "settings")
            navButton("使用指南", icon: "questionmark.circle", page: "help")
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(model.isPlaying ? mint : muted).frame(width: 6, height: 6)
                    Text(model.status).font(.system(size: 11, weight: .medium))
                }
                Text(model.preferences.enabled ? model.activeTitle : "让桌面也有呼吸感")
                    .font(.system(size: 11)).foregroundStyle(muted).lineLimit(1)
                if model.preferences.enabled {
                    HStack(spacing: 10) {
                        Button { model.togglePause() } label: {
                            Label(model.preferences.userPaused ? "继续" : "暂停", systemImage: model.preferences.userPaused ? "play.fill" : "pause.fill")
                        }
                        Button { model.stop() } label: { Image(systemName: "stop.fill") }.help("关闭动态壁纸，恢复原桌面")
                    }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(mint)
                }
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(panel, in: RoundedRectangle(cornerRadius: 12)).padding(14)
            HStack { Text("本地运行 · 安静陪伴"); Spacer(); Text("1.0") }
                .font(.system(size: 9)).foregroundStyle(muted.opacity(0.7)).padding(.horizontal, 18).padding(.bottom, 18)
        }.background(Color(rgb: 0x10151D))
    }
    private func navButton(_ text: String, icon: String, page: String) -> some View {
        Button { model.page = page } label: {
            HStack(spacing: 11) {
                Image(systemName: icon).frame(width: 17)
                Text(text).font(.system(size: 12, weight: model.page == page ? .semibold : .regular))
                Spacer()
                if model.page == page { RoundedRectangle(cornerRadius: 2).fill(mint).frame(width: 3, height: 14) }
            }
            .foregroundStyle(model.page == page ? mint : muted)
            .padding(.horizontal, 13).frame(height: 43)
            .background(model.page == page ? mint.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 5)
    }

    private var library: some View {
        Group {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("给桌面，一点生命。").font(.system(size: 25, weight: .semibold))
                    Text("光影在流动，灵感在发生。").font(.system(size: 12)).foregroundStyle(muted)
                }
                Spacer()
                Button { model.chooseVideo() } label: {
                    HStack(spacing: 7) {
                        if model.isImporting { ProgressView().controlSize(.small) }
                        else { Image(systemName: "plus") }
                        Text(model.isImporting ? "正在导入" : "导入视频")
                    }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.10)))
                }.buttonStyle(.plain).disabled(model.isImporting)
            }
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let scene = model.selectedScene { ScenePreview(scene: scene, animated: model.previewAnimating).id(scene) }
                        else if let video = model.selectedVideo { VideoPreview(url: model.mediaURL(video.fileName), animated: model.previewAnimating, fit: model.preferences.fit).id(video.id) }
                    }
                    Color.black.opacity(1 - model.preferences.brightness).allowsHitTesting(false)
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(model.selectedScene?.label ?? "YOUR OWN MOMENT")
                            .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(3).foregroundStyle(.white.opacity(0.65))
                        Text(model.selectedTitle).font(.system(size: 30, weight: .medium)).lineLimit(1)
                        Text(model.selectedScene?.subtitle ?? model.selectedVideo?.detail ?? "")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    }.padding(26)
                    VStack {
                        HStack {
                            Spacer()
                            Label(model.previewAnimating ? "动态预览" : "预览已暂停", systemImage: model.previewAnimating ? "waveform" : "pause.fill")
                                .font(.system(size: 9, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                                .background(.black.opacity(0.22), in: Capsule())
                        }
                        Spacer()
                    }.padding(18)
                }.frame(height: 277).clipped()
                HStack(spacing: 12) {
                    Image(systemName: "display").font(.system(size: 17)).foregroundStyle(muted)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.preferences.allDisplays ? "应用到所有显示器" : "应用到主显示器").font(.system(size: 11, weight: .medium))
                        Text("\(model.displayCount) 台已连接  ·  \(model.selectedScene != nil ? "原生动态光影" : "静音循环播放")")
                            .font(.system(size: 10)).foregroundStyle(muted)
                    }
                    Spacer()
                    if model.preferences.enabled && model.preferences.appliedID == model.selectedID {
                        Label("已应用", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(mint)
                    }
                    Button { model.applySelected() } label: {
                        HStack(spacing: 7) { Image(systemName: "play.fill").font(.system(size: 10)); Text("设为动态壁纸").font(.system(size: 12, weight: .semibold)) }
                            .foregroundStyle(Color(rgb: 0x142B24)).padding(.horizontal, 18).padding(.vertical, 12)
                            .background(mint, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.vertical, 15).background(panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    filterButton("全部壁纸", id: "all")
                    filterButton("内置精选", id: "builtin")
                    filterButton("我的视频", id: "videos")
                    Spacer()
                    Text("\(model.libraryFilter == "videos" ? model.videos.count : model.libraryFilter == "builtin" ? 4 : 4 + model.videos.count) 款壁纸")
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 16) {
                    if model.libraryFilter != "videos" {
                        ForEach(BuiltinScene.allCases) { scene in
                            wallpaperCard(id: scene.id, title: scene.title, detail: "内置 · 动态光影") {
                                ScenePreview(scene: scene, animated: false).id(scene)
                            }
                        }
                    }
                    if model.libraryFilter != "builtin" {
                        ForEach(model.videos) { video in
                            wallpaperCard(id: video.id, title: video.name, detail: video.detail) {
                                if let name = video.thumbnailName, let image = NSImage(contentsOf: model.mediaURL(name)) {
                                    Image(nsImage: image).resizable().scaledToFill()
                                } else { ZStack { panel; Image(systemName: "film").font(.largeTitle).foregroundStyle(muted) } }
                            }
                            .contextMenu { Button("从壁纸库移除", role: .destructive) { model.videoToDelete = video } }
                        }
                    }
                }
                if model.libraryFilter == "videos" && model.videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack").font(.system(size: 28)).foregroundStyle(muted)
                        Text("收藏一个会动的瞬间").font(.system(size: 13, weight: .medium))
                        Text("导入 MP4、MOV 或其他系统支持的视频，就能成为桌面。")
                            .font(.system(size: 11)).foregroundStyle(muted)
                        Button("导入第一个视频") { model.chooseVideo() }.buttonStyle(.bordered).disabled(model.isImporting)
                    }.frame(maxWidth: .infinity).padding(30).background(panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf")
                Text("屏幕休眠时自动暂停  ·  关闭窗口后可从菜单栏继续控制")
            }.font(.system(size: 10)).foregroundStyle(muted.opacity(0.8))
        }
    }
    private func filterButton(_ text: String, id: String) -> some View {
        Button { model.libraryFilter = id } label: {
            VStack(spacing: 8) {
                Text(text).font(.system(size: 12, weight: model.libraryFilter == id ? .semibold : .regular)).foregroundStyle(model.libraryFilter == id ? Color.white : muted)
                Capsule().fill(model.libraryFilter == id ? mint : .clear).frame(height: 2)
            }.fixedSize(horizontal: true, vertical: false)
        }.buttonStyle(.plain)
    }
    private func wallpaperCard<Content: View>(id: String, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        Button { model.selectedID = id } label: {
            VStack(alignment: .leading, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    content().frame(height: 100).frame(maxWidth: .infinity).clipped()
                    if model.selectedID == id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(mint).font(.system(size: 17))
                            .background(Circle().fill(.black.opacity(0.6))).padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(model.selectedID == id ? mint : Color.white.opacity(0.06), lineWidth: model.selectedID == id ? 1.5 : 1))
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(detail).font(.system(size: 9)).foregroundStyle(muted).lineLimit(1)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var settings: some View {
        Group {
            pageHeader("让流光，适合你的节奏。", subtitle: "这些设置会自动保存。")
            settingsSection("显示与播放", icon: "display") {
                Toggle("在所有显示器上播放", isOn: preference(\.allDisplays))
                Text("关闭后只使用系统设置中的主显示器。插拔显示器后会自动适配。")
                    .font(.system(size: 11)).foregroundStyle(muted)
                Divider().padding(.vertical, 8)
                HStack {
                    Text("视频画面"); Spacer()
                    Picker("视频画面", selection: preference(\.fit)) {
                        ForEach(VideoFit.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
                HStack(spacing: 16) {
                    Text("壁纸亮度")
                    Slider(value: preference(\.brightness), in: 0.15...1)
                    Text("\(Int(model.preferences.brightness * 100))%").monospacedDigit().foregroundStyle(muted).frame(width: 38)
                }.padding(.top, 8)
                Text("视频始终静音，避免打扰。亮度只影响动态壁纸。")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            settingsSection("省电与启动", icon: "leaf") {
                Toggle("使用电池时暂停", isOn: preference(\.pauseOnBattery))
                Toggle("低电量模式下暂停", isOn: preference(\.pauseInLowPower)).padding(.top, 10)
                Text("屏幕或电脑休眠、切换到其他登录会话时也会自动暂停。")
                    .font(.system(size: 11)).foregroundStyle(muted)
                Divider().padding(.vertical, 8)
                Toggle("登录 Mac 时启动", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                Text("再次打开应用时，会恢复上次启用的壁纸和暂停状态。")
                    .font(.system(size: 11)).foregroundStyle(muted)
                if model.loginNeedsApproval {
                    Button("前往系统设置允许登录启动") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            settingsSection("壁纸文件", icon: "folder") {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("已导入 \(model.videos.count) 个视频")
                        Text("视频副本保存在本机，右键点击视频卡片可以移除。")
                            .font(.system(size: 11)).foregroundStyle(muted)
                    }
                    Spacer()
                    Button("打开文件夹") { NSWorkspace.shared.open(model.store.mediaDirectory) }
                }
            }
        }.font(.system(size: 12))
    }
    private func preference<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } })
    }
    private func pageHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 25, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(muted)
        }.padding(.bottom, 4)
    }
    private func settingsSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(mint)
            content()
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(panel, in: RoundedRectangle(cornerRadius: 13))
    }
    private var help: some View {
        Group {
            pageHeader("留一片喜欢的风景。", subtitle: "三步开始，让桌面缓缓动起来。")
            settingsSection("01   挑一款壁纸", icon: "square.grid.2x2") {
                Text("在壁纸库里点击内置光影，或导入自己的视频。上方会显示动态预览。")
            }
            settingsSection("02   设为动态壁纸", icon: "play.rectangle") {
                Text("点击「设为动态壁纸」。壁纸在桌面图标下方播放，桌面文件仍可正常点击。")
            }
            settingsSection("03   关掉窗口，继续享受", icon: "menubar.rectangle") {
                Text("关闭这个窗口后壁纸会继续播放。点击屏幕顶部菜单栏的流光图标，可以暂停、恢复、打开壁纸库或退出。")
            }
            settingsSection("你可能想知道", icon: "info.circle") {
                Text("• 点击停止或退出应用，会立即显示原来的系统壁纸。\n\n• 推荐使用 H.264 / HEVC 编码的 MP4 或 MOV。视频会静音循环，循环接缝取决于素材。\n\n• 动态壁纸用于登录后的桌面，不会修改锁定屏幕或屏幕保护程序。\n\n• 导入会复制视频到本机壁纸库，需要相应的磁盘空间。\n\n• 首次使用无需网络、屏幕录制权限或辅助功能权限。")
                    .foregroundStyle(muted).lineSpacing(4)
            }
            Text("流光桌面 1.0  /  为 macOS 而生").font(.system(size: 10)).foregroundStyle(muted)
        }.font(.system(size: 12))
    }
}
