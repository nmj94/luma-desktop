# 流光桌面 · Luma Desktop

[简体中文](#zh-cn) | [English](#en)

给桌面，一点生命。 / Bring your desktop to life.

![流光桌面壁纸库 / Luma Desktop wallpaper library](docs/images/library.png)

<a id="zh-cn"></a>

## 简体中文

流光桌面是一个使用 Swift、SwiftUI、AppKit 和 AVFoundation 编写的 macOS 原生动态壁纸应用。它支持内置动态光影、本地视频壁纸和菜单栏控制，无需联网，也不依赖网页容器。

应用界面目前为简体中文，本说明提供中文和英文两个版本。

### 下载与使用

1. 下载 [Apple 芯片 Mac 应用压缩包](downloads/LumaDesktop-macOS-AppleSilicon.zip)。进入文件页面后，点击下载按钮保存压缩包。
2. 解压并打开「流光桌面.app」。也可以将应用移到 Mac 的「应用程序」文件夹。
3. 选择一款内置壁纸，或点击「导入视频」选择本地视频。
4. 点击「设为动态壁纸」。

首次启动只显示预览，点击应用按钮后才改变桌面。关闭主窗口后，壁纸会继续播放；点击屏幕顶部的菜单栏图标，可以暂停、继续、停止、打开壁纸库或退出。停止或退出会显示原来的系统壁纸。

**运行要求：** 提供的压缩包适用于 Apple 芯片 Mac，最低系统版本为 macOS 13；已在 macOS 27.0.1 上验证。当前应用包仅使用本地 ad-hoc 签名，尚未进行 Developer ID 签名或 Apple 公证；也可以按下方说明从源码构建。

### 功能

- **四款内置动态背景：** 极光漫游、深海呼吸、日落余温、星际漂流，使用 Core Animation 绘制并适配屏幕尺寸。
- **本地视频壁纸：** 导入视频、生成缩略图、静音循环播放；推荐 H.264 / HEVC 编码的 MP4、MOV。
- **独立预览：** 点击壁纸卡片可预览，确认应用后才替换桌面。
- **多显示器：** 应用到全部显示器或主显示器，连接或断开显示器后自动适配。
- **画面设置：** 视频填满屏幕 / 完整显示、壁纸亮度调节。
- **播放与节能：** 手动暂停，屏幕或电脑休眠、非活动登录会话时自动暂停；可选电池供电暂停和低电量模式暂停。
- **启动与恢复：** 可选登录启动，保存壁纸库、设置、最近应用的壁纸及手动暂停状态。
- **保留桌面操作：** 壁纸位于桌面图标下方，不拦截鼠标操作，不修改系统原壁纸文件。

### 从源码构建

需要 macOS、Apple Command Line Tools（包含 Swift 编译器）和 Python 3，不需要第三方 Swift 包。

```sh
git clone https://github.com/nmj94/luma-desktop.git
cd luma-desktop
./scripts/build.sh
```

构建结果为 `dist/流光桌面.app`。脚本按照当前 Mac 的处理器架构编译程序、生成应用图标，并进行本地签名。源码尚未在 Intel Mac 上实机验证。

### 运行检查

先完成构建并安装 `ffmpeg`，再运行：

```sh
./scripts/test.sh
```

检查包含状态与持久化测试，以及真实桌面窗口、视频导入、缩略图、循环、暂停恢复、删除副本等流程。脚本会生成一个短视频，使用独立临时壁纸库，短暂创建桌面窗口，随后清理窗口并退出，不修改正式壁纸库。

已在上述测试环境通过 **15 项模型检查和 25 项集成检查**。报告和界面截图位于 `build/test-artifacts/`。这些结果不代表已经验证多台实体显示器、所有 macOS 版本或实际关机登录流程。

### 文件与隐私

应用本身不联网，不需要屏幕录制或辅助功能权限。导入的视频会复制到：

```text
~/Library/Application Support/LumaDesktop/Media/
```

设置保存在同级 `library.json`。右键点击视频卡片可移除应用保存的副本和缩略图，原始视频不会被删除。偏好设置中可以打开媒体文件夹。

仓库包含源码、使用说明、应用截图和可下载的应用压缩包。临时编译缓存、测试媒体及用户导入的视频不纳入版本管理。

### 已知限制

- 用于登录后的桌面，不替换锁定屏幕或屏幕保护程序。
- 每个显示器使用独立播放器，不保证视频逐帧同步；高分辨率或多显示器播放会增加资源占用。
- 电池供电状态最长约 15 秒更新一次，休眠与低电量模式通过系统通知响应。
- 视频首尾是否衔接自然取决于素材。
- 开启登录启动后，建议保持应用位置不变。
- 下载的预编译包尚未完成 Developer ID 签名和 Apple 公证。

---

<a id="en"></a>

## English

Luma Desktop is a native macOS live wallpaper app built with Swift, SwiftUI, AppKit, and AVFoundation. It offers animated backgrounds, local video wallpapers, and menu bar controls. The app runs offline without a web container.

The application interface is currently in Simplified Chinese. This README is available in both Chinese and English.

### Download and use

1. Download the [app archive for Apple Silicon Macs](downloads/LumaDesktop-macOS-AppleSilicon.zip). On the file page, use the download button to save the archive.
2. Extract it and open `流光桌面.app`. You can also move the app to your Applications folder.
3. Choose a built-in wallpaper, or click **导入视频** (Import Video) to select a local video.
4. Click **设为动态壁纸** (Set as Live Wallpaper).

On first launch, the app only displays a preview; your desktop changes when you apply a wallpaper. Closing the main window keeps the wallpaper running. Use the menu bar icon to pause, resume, stop, reopen the library, or quit. Stopping or quitting reveals your original system wallpaper.

**Requirements:** The supplied archive is for Apple Silicon Macs running macOS 13 or later. It has been tested on macOS 27.0.1. The app bundle is locally ad-hoc signed; it has no Developer ID signature or Apple notarization. You can also build it from source as described below.

### Features

- **Four animated backgrounds:** Aurora, Deep Blue, Afterglow, and Stardust, rendered with Core Animation and scaled to fit the display.
- **Local video wallpapers:** Import videos, generate thumbnails, and loop playback with audio muted. H.264 / HEVC videos in MP4 or MOV containers are recommended.
- **Independent preview:** Selecting a card previews the wallpaper; the desktop changes only after you apply it.
- **Multiple displays:** Apply to all displays or the primary display, with automatic updates when displays are connected or disconnected.
- **Appearance controls:** Fill or fit video scaling and wallpaper brightness adjustment.
- **Playback and power saving:** Manual pause; automatic pause during display or system sleep and inactive login sessions; optional pause on battery power or in Low Power Mode.
- **Startup and restoration:** Optional launch at login, a persistent library and settings, and restoration of the last applied wallpaper and manual pause state.
- **Normal desktop interaction:** Wallpapers sit below desktop icons, ignore mouse input, and leave the original system wallpaper files intact.

### Build from source

You need macOS, Apple Command Line Tools with the Swift compiler, and Python 3. No third-party Swift packages are required.

```sh
git clone https://github.com/nmj94/luma-desktop.git
cd luma-desktop
./scripts/build.sh
```

The output is `dist/流光桌面.app`. The build script compiles for the architecture of the current Mac, generates the app icon, and applies a local signature. The source has not been tested on a physical Intel Mac.

### Run checks

Build the app and install `ffmpeg`, then run:

```sh
./scripts/test.sh
```

The checks cover state and persistence, actual desktop windows, video import, thumbnail generation, looping, pause and resume, and removal of imported copies. The script generates a short video and uses an isolated temporary library. It briefly creates desktop windows, cleans them up, and exits without modifying the normal wallpaper library.

**15 model checks and 25 integration checks** passed in the environment described above. Reports and UI screenshots are saved to `build/test-artifacts/`. These results do not establish coverage of multiple physical displays, every macOS version, or an actual reboot and login sequence.

### Files and privacy

The app itself does not connect to the internet or require Screen Recording or Accessibility permissions. Imported videos are copied to:

```text
~/Library/Application Support/LumaDesktop/Media/
```

Settings are stored in `library.json` alongside the `Media` folder. Right-clicking a video card lets you remove the app's copy and thumbnail while keeping the original video intact. You can open the media folder from Preferences.

The repository includes source code, documentation, an app screenshot, and a downloadable app archive. Temporary build caches, test media, and user-imported videos are excluded from version control.

### Known limitations

- Wallpapers run on the logged-in desktop; they do not replace the lock screen or screen saver.
- Each display uses a separate player, so frame-perfect synchronization is not guaranteed. High-resolution or multi-display playback uses more resources.
- Battery power status is refreshed approximately every 15 seconds. Sleep and Low Power Mode changes are handled through system notifications.
- The smoothness of a video loop depends on its first and last frames.
- Keep the app in a stable location after enabling launch at login.
- The downloadable build has no Developer ID signature or Apple notarization.

---

## 项目结构 / Project structure

| 路径 / Path | 用途 / Purpose |
| --- | --- |
| `Sources/MainView.swift` | 中文壁纸库、预览与设置 / Chinese library, preview, and settings UI |
| `Sources/AppModel.swift` | 导入、存储、节能与登录启动 / Import, persistence, power policies, and launch at login |
| `Sources/WallpaperEngine.swift` | 桌面窗口与视频播放 / Desktop windows and video playback |
| `Sources/SceneView.swift` | 原生动态场景 / Native animated scenes |
| `Sources/Models.swift` | 数据模型、存储与暂停策略 / Data models, storage, and pause policies |
| `Sources/main.swift` | 应用生命周期与菜单栏 / App lifecycle and menu bar |
| `Tests/` | 模型检查 / Model checks |
| `Sources/IntegrationChecks.swift` | 应用内集成检查 / In-app integration checks |
| `scripts/` | 构建、图标生成与验证 / Build, icon generation, and validation |
| `docs/images/` | 界面截图 / UI screenshot |
| `downloads/` | Apple 芯片 Mac 应用压缩包 / App archive for Apple Silicon Macs |

## 参考文档 / References

- [Apple: CGWindowLevelKey](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey)
- [Apple: AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper)
