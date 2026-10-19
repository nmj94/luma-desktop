# 流光桌面 · Luma Desktop

**简体中文** | [English](README.en.md)

给桌面，一点生命。

![流光桌面中文版壁纸库](docs/images/library.png)

流光桌面是一个使用 Swift、SwiftUI、AppKit 和 AVFoundation 编写的 macOS 原生动态壁纸应用。它支持内置动态光影、本地视频壁纸和菜单栏控制，无需联网，也不依赖网页容器。

界面支持简体中文和英文，默认跟随系统；也可以在侧栏或偏好设置中手动切换。

### 下载与使用

1. 下载 [Apple 芯片 Mac 应用压缩包](downloads/LumaDesktop-macOS-AppleSilicon.zip)。进入文件页面后，点击下载按钮保存压缩包。
2. 解压并打开「流光桌面.app」。也可以将应用移到 Mac 的「应用程序」文件夹。
3. 选择一款内置壁纸，或点击「导入视频」选择本地视频。
4. 点击「设为动态壁纸」。

首次启动只显示预览，点击应用按钮后才改变桌面。关闭主窗口后，壁纸会继续播放；点击屏幕顶部的菜单栏图标，可以暂停、继续、停止、打开壁纸库或退出。停止或退出会显示原来的系统壁纸。

**运行要求：** 提供的压缩包适用于 Apple 芯片 Mac，最低系统版本为 macOS 13；已在 macOS 27.0.1 上验证。当前应用包仅使用本地 ad-hoc 签名，尚未进行 Developer ID 签名或 Apple 公证；也可以按下方说明从源码构建。

### 功能

- **中英文界面：** 跟随系统或手动切换，立即生效并自动保存，无需重启。
- **四款内置动态背景：** 极光漫游、深海呼吸、日落余温、星际漂流，使用 Core Animation 绘制并适配屏幕尺寸。
- **本地视频壁纸：** 导入视频、生成缩略图、静音循环播放；推荐 H.264 / HEVC 编码的 MP4、MOV。
- **独立预览：** 点击壁纸卡片可预览，确认应用后才替换桌面。
- **多显示器：** 应用到全部显示器或主显示器，连接或断开显示器后自动适配。
- **画面设置：** 视频填满屏幕 / 完整显示、壁纸亮度调节。
- **播放与节能：** 手动暂停，屏幕或电脑休眠、非活动登录会话时自动暂停；可选电池供电暂停和低电量模式暂停。
- **启动与恢复：** 可选登录启动，保存壁纸库、设置、最近应用的壁纸及手动暂停状态。
- **保留桌面操作：** 壁纸位于桌面图标下方，不拦截鼠标操作，不修改系统原壁纸文件。

### 切换界面语言

点击侧栏底部的地球图标，或进入「偏好设置 → 界面语言」，选择「跟随系统」「简体中文」或「English」。切换会同步更新壁纸库、设置、使用指南、应用菜单与菜单栏操作，并保留壁纸和播放状态。

「跟随系统」会选择系统首选语言列表中的中文或英文；没有匹配项时使用英文。旧版本的壁纸库会保留，并默认使用「跟随系统」。

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

检查包含中英文切换、语言偏好持久化、旧版配置迁移、状态与存储测试，以及真实桌面窗口、视频导入、缩略图、循环、暂停恢复、删除副本等流程。脚本会生成一个短视频，使用独立临时壁纸库，短暂创建桌面窗口，随后清理窗口并退出，不修改正式壁纸库。

已在上述测试环境通过 **26 项模型检查和 32 项集成检查**。报告和界面截图位于 `build/test-artifacts/`。这些结果不代表已经验证多台实体显示器、所有 macOS 版本或实际关机登录流程。

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

### 项目结构

| 路径 | 用途 |
| --- | --- |
| `Sources/Localization.swift` | 中英文文案、语言选择与错误提示 |
| `Sources/MainView.swift` | 壁纸库、预览与设置界面 |
| `Sources/AppModel.swift` | 导入、存储、节能与登录启动 |
| `Sources/WallpaperEngine.swift` | 桌面窗口与视频播放 |
| `Sources/SceneView.swift` | 原生动态场景 |
| `Sources/Models.swift` | 数据模型、兼容旧版的存储与暂停策略 |
| `Sources/main.swift` | 应用生命周期与菜单栏 |
| `Resources/*.lproj/` | 系统显示的应用名称 |
| `Tests/` | 模型与本地化检查 |
| `Sources/IntegrationChecks.swift` | 应用内集成检查 |
| `scripts/` | 构建、图标生成与验证 |
| `docs/images/` | 中英文界面截图 |
| `downloads/` | Apple 芯片 Mac 应用压缩包 |

### 参考文档

- [Apple：CGWindowLevelKey](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey)
- [Apple：AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper)

---

[English documentation →](README.en.md)
