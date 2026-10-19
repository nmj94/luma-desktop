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
        .environment(\.locale, Locale(identifier: model.language.resolved().rawValue))
        .tint(mint)
        .frame(minWidth: 960, minHeight: 690)
        .alert(model.text(.problemTitle), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(model.text(.dismiss), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog(model.text(.removeConfirmation), isPresented: Binding(get: { model.videoToDelete != nil }, set: { if !$0 { model.videoToDelete = nil } }), titleVisibility: .visible) {
            if let video = model.videoToDelete { Button(model.text(.removeNamedVideo, video.name), role: .destructive) { model.removeVideo(video); model.videoToDelete = nil } }
            Button(model.text(.cancel), role: .cancel) { model.videoToDelete = nil }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.text(.brand)).font(.system(size: 22, weight: .semibold))
                    Text("LUMA DESKTOP").font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(muted)
                }
            }.padding(.top, 30).padding(.bottom, 43).padding(.leading, 22)
            Text(model.text(.yourSpace)).font(.system(size: 10, weight: .medium)).foregroundStyle(muted).padding(.leading, 24).padding(.bottom, 14)
            navButton(model.text(.library), icon: "square.grid.2x2", page: "library")
            navButton(model.text(.preferences), icon: "slider.horizontal.3", page: "settings")
            navButton(model.text(.guide), icon: "questionmark.circle", page: "help")
            Spacer()
            Menu {
                languagePicker
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text(model.language.resolved().displayName(in: model.language))
                    Spacer()
                }.font(.system(size: 11)).foregroundStyle(muted)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(model.text(.language))
            .padding(.horizontal, 24).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle().fill(model.isPlaying ? mint : muted).frame(width: 6, height: 6)
                    Text(model.status).font(.system(size: 11, weight: .medium))
                }
                Text(model.preferences.enabled ? model.activeTitle : model.text(.idleTagline))
                    .font(.system(size: 11)).foregroundStyle(muted).lineLimit(1)
                if model.preferences.enabled {
                    HStack(spacing: 10) {
                        Button { model.togglePause() } label: {
                            Label(model.preferences.userPaused ? model.text(.resume) : model.text(.pause), systemImage: model.preferences.userPaused ? "play.fill" : "pause.fill")
                        }
                        Button { model.stop() } label: { Image(systemName: "stop.fill") }.help(model.text(.stopHint))
                    }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(mint)
                }
            }
            .padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(panel, in: RoundedRectangle(cornerRadius: 12)).padding(14)
            HStack { Text(model.text(.offlineTagline)); Spacer(); Text(model.appVersion) }
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
                    Text(model.text(.headline)).font(.system(size: 25, weight: .semibold))
                    Text(model.text(.librarySubtitle)).font(.system(size: 12)).foregroundStyle(muted)
                }
                Spacer()
                Button { model.chooseVideo() } label: {
                    HStack(spacing: 7) {
                        if model.isImporting { ProgressView().controlSize(.small) }
                        else { Image(systemName: "plus") }
                        Text(model.isImporting ? model.text(.importing) : model.text(.importVideo))
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
                        Text(model.selectedScene?.subtitle(in: model.language) ?? model.selectedVideo?.detail(in: model.language) ?? "")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                    }.padding(26)
                    VStack {
                        HStack {
                            Spacer()
                            Label(model.previewAnimating ? model.text(.livePreview) : model.text(.pausedPreview), systemImage: model.previewAnimating ? "waveform" : "pause.fill")
                                .font(.system(size: 9, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7)
                                .background(.black.opacity(0.22), in: Capsule())
                        }
                        Spacer()
                    }.padding(18)
                }.frame(height: 277).clipped()
                HStack(spacing: 12) {
                    Image(systemName: "display").font(.system(size: 17)).foregroundStyle(muted)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.preferences.allDisplays ? model.text(.applyAll) : model.text(.applyPrimary)).font(.system(size: 11, weight: .medium))
                        Text(model.text(.displaySummary, model.displayCount, model.text(model.selectedScene != nil ? .nativeAnimation : .mutedLoop)))
                            .font(.system(size: 10)).foregroundStyle(muted)
                    }
                    Spacer()
                    if model.preferences.enabled && model.preferences.appliedID == model.selectedID {
                        Label(model.text(.applied), systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(mint)
                    }
                    Button { model.applySelected() } label: {
                        HStack(spacing: 7) { Image(systemName: "play.fill").font(.system(size: 10)); Text(model.text(.applyWallpaper)).font(.system(size: 12, weight: .semibold)) }
                            .foregroundStyle(Color(rgb: 0x142B24)).padding(.horizontal, 18).padding(.vertical, 12)
                            .background(mint, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 20).padding(.vertical, 15).background(panel)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.06)))

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    filterButton(model.text(.allWallpapers), id: "all")
                    filterButton(model.text(.builtins), id: "builtin")
                    filterButton(model.text(.myVideos), id: "videos")
                    Spacer()
                    Text(wallpaperCountText)
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 16) {
                    if model.libraryFilter != "videos" {
                        ForEach(BuiltinScene.allCases) { scene in
                            wallpaperCard(id: scene.id, title: scene.title(in: model.language), detail: model.text(.builtinDetail)) {
                                ScenePreview(scene: scene, animated: false).id(scene)
                            }
                        }
                    }
                    if model.libraryFilter != "builtin" {
                        ForEach(model.videos) { video in
                            wallpaperCard(id: video.id, title: video.name, detail: video.detail(in: model.language)) {
                                if let name = video.thumbnailName, let image = NSImage(contentsOf: model.mediaURL(name)) {
                                    Image(nsImage: image).resizable().scaledToFill()
                                } else { ZStack { panel; Image(systemName: "film").font(.largeTitle).foregroundStyle(muted) } }
                            }
                            .contextMenu { Button(model.text(.removeFromLibrary), role: .destructive) { model.videoToDelete = video } }
                        }
                    }
                }
                if model.libraryFilter == "videos" && model.videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack").font(.system(size: 28)).foregroundStyle(muted)
                        Text(model.text(.emptyTitle)).font(.system(size: 13, weight: .medium))
                        Text(model.text(.emptyDescription))
                            .font(.system(size: 11)).foregroundStyle(muted)
                        Button(model.text(.importFirst)) { model.chooseVideo() }.buttonStyle(.bordered).disabled(model.isImporting)
                    }.frame(maxWidth: .infinity).padding(30).background(panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "leaf")
                Text(model.text(.libraryFooter))
            }.font(.system(size: 10)).foregroundStyle(muted.opacity(0.8))
        }
    }
    private var wallpaperCountText: String {
        let count = model.libraryFilter == "videos" ? model.videos.count : model.libraryFilter == "builtin" ? BuiltinScene.allCases.count : BuiltinScene.allCases.count + model.videos.count
        return count == 1 ? model.text(.oneWallpaper) : model.text(.wallpaperCount, count)
    }

    private var languagePicker: some View {
        Picker(model.text(.language), selection: preference(\.language)) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.displayName(in: model.language)).tag(language)
            }
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
            pageHeader(model.text(.settingsHeadline), subtitle: model.text(.settingsSubtitle))
            settingsSection(model.text(.language), icon: "globe") {
                languagePicker.pickerStyle(.segmented)
                Text(model.text(.languageHint)).font(.system(size: 11)).foregroundStyle(muted)
            }
            settingsSection(model.text(.displayPlayback), icon: "display") {
                Toggle(model.text(.playAllDisplays), isOn: preference(\.allDisplays))
                Text(model.text(.displayHint))
                    .font(.system(size: 11)).foregroundStyle(muted)
                Divider().padding(.vertical, 8)
                HStack {
                    Text(model.text(.videoScaling)); Spacer()
                    Picker(model.text(.videoScaling), selection: preference(\.fit)) {
                        ForEach(VideoFit.allCases, id: \.self) { Text($0.title(in: model.language)).tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
                HStack(spacing: 16) {
                    Text(model.text(.brightness))
                    Slider(value: preference(\.brightness), in: 0.15...1)
                    Text("\(Int(model.preferences.brightness * 100))%").monospacedDigit().foregroundStyle(muted).frame(width: 38)
                }.padding(.top, 8)
                Text(model.text(.mutedHint))
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            settingsSection(model.text(.powerStartup), icon: "leaf") {
                Toggle(model.text(.pauseOnBattery), isOn: preference(\.pauseOnBattery))
                Toggle(model.text(.pauseLowPower), isOn: preference(\.pauseInLowPower)).padding(.top, 10)
                Text(model.text(.autoPauseHint))
                    .font(.system(size: 11)).foregroundStyle(muted)
                Divider().padding(.vertical, 8)
                Toggle(model.text(.launchAtLogin), isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                Text(model.text(.restoreHint))
                    .font(.system(size: 11)).foregroundStyle(muted)
                if model.loginNeedsApproval {
                    Button(model.text(.approveLogin)) { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            settingsSection(model.text(.wallpaperFiles), icon: "folder") {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.text(.importedCount, model.videos.count))
                        Text(model.text(.importedHint))
                            .font(.system(size: 11)).foregroundStyle(muted)
                    }
                    Spacer()
                    Button(model.text(.openFolder)) { NSWorkspace.shared.open(model.store.mediaDirectory) }
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
            pageHeader(model.text(.guideHeadline), subtitle: model.text(.guideSubtitle))
            settingsSection(model.text(.guideStep1), icon: "square.grid.2x2") {
                Text(model.text(.guideStep1Body))
            }
            settingsSection(model.text(.guideStep2), icon: "play.rectangle") {
                Text(model.text(.guideStep2Body))
            }
            settingsSection(model.text(.guideStep3), icon: "menubar.rectangle") {
                Text(model.text(.guideStep3Body))
            }
            settingsSection(model.text(.goodToKnow), icon: "info.circle") {
                Text(model.text(.guideDetails))
                    .foregroundStyle(muted).lineSpacing(4)
            }
            Text(model.text(.guideFooter, model.appVersion)).font(.system(size: 10)).foregroundStyle(muted)
        }.font(.system(size: 12))
    }
}
