<div align="center">
    <img src="icon.png" width="160" height="160" alt="Ice++">
    <h1>Ice++</h1>
    <p>macOS 菜单栏管理。隐藏图标，用 Ice Bar 打开，用预设和自动化切换布局。</p>
    <p>只提供 Apple 芯片安装包。系统要求 macOS 14 或更高。</p>
</div>

<p align="center"><a href="README.md">English</a></p>

[![Release](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml/badge.svg)](https://github.com/itworksig/IcePlusPlus/actions/workflows/release.yml)
[![Download](https://img.shields.io/badge/download-Apple%20silicon-brightgreen?style=flat-square)](https://github.com/itworksig/IcePlusPlus/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20arm64-blue?style=flat-square)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)

界面上的名称是 **Ice++**。包标识仍是 `com.jordanbaird.Ice`，偏好设置也写在这个标识下，所以这份应用可以换掉已经装好的 Ice。

## 它做什么

把应用放进「隐藏」或「始终隐藏」。之后用 Ice Bar、快捷键、快捷指令、AppleScript 或链接把它们叫出来。保存下来的布局也可以跟着接入的显示器、前台应用、一天里的时段，或当前网络一起切换。

隐藏是按 macOS 27 写的。系统不再给每个菜单栏图标单独的窗口，所以一次隐藏作用于整个应用。

## 这条线从哪来

| | |
| --- | --- |
| [Jordan Baird 的 Ice](https://github.com/jordanbaird/Ice) | 原始项目。分区、Ice Bar、菜单栏外观、间距和快捷键都从这里来。许可是 GPL-3.0。 |
| [cavaldos/Ice](https://github.com/cavaldos/Ice) | 把 Ice 接到 macOS 27 上的社区分支。本仓库的 `upstream` 指向它。分叉点是 `38c8a95`（`fix: remove padding left menubar`）。 |
| [itworksig/IcePlusPlus](https://github.com/itworksig/IcePlusPlus) | 本仓库。 |

分叉之后，cavaldos 继续改了 Ice Bar 的图标发现、悬停不要写进布局，以及更新后请求 star。这些提交不在本仓库里。

## 和原始项目的区别

原始项目是 Jordan Baird 的 Ice。直接上游是 cavaldos/Ice。

| | 原始 Ice | cavaldos/Ice | Ice++ |
| --- | --- | --- | --- |
| 名称 | Ice | Ice | Ice++。包标识 `com.jordanbaird.Ice` |
| 界面语言 | 英文 | 英文 | 英文和简体中文。切换语言后应用会重新打开 |
| 更新 | Sparkle 的 appcast | 自己的发布页，另有 Homebrew tap `cavaldos/tap` | 关于页读取本仓库的 GitHub Release。没有 Homebrew 公式 |
| 安装包 | 由原仓库发布 | 由 cavaldos/Ice 发布 | 只构建 arm64。推送到 `main` 会发布下一个版本。项目里的主版本或次版本高于现有 Release 时，按项目里写的版本发布 |
| macOS 27 上的隐藏 | 按当时每个图标自己的窗口来排 | 修过图标消失或被卡住的问题，让原来的布局方式继续可用 | 用系统的评估模式按应用隐藏。`com.apple.*` 和 Ice 自己留在菜单栏上 |
| 系统图标 | 跟菜单栏外观走 | 跟菜单栏外观走 | Wi-Fi、电池、时钟、控制中心各自有开关。蓝牙和音量没有单独开关 |
| Ice Bar | 用来展开隐藏区的第二条栏 | 同一条栏，后来又修过点击和图标发现 | 玻璃底，圆角和着色单独设置。搜索图标、预设和自动化。方向键选择，回车执行。位置跟鼠标所在的屏幕 |
| 预设 | | | 保存当前布局，一点套用。绑上当前这组显示器后，再接上同一组屏幕会自动套用 |
| 自动化 | | | 前台应用、电量、时段、Wi-Fi、地点、日期、电源、脚本。应用从正在运行的程序里选，网络和地点填入当前值，时段用时间选择器 |
| 专注 | | | 只藏第三方图标。时钟和控制中心留着，音量和亮度界面继续可用 |
| 刘海 | 靠布局和 Ice Bar 躲开 | 靠布局和 Ice Bar 躲开 | 默认关闭。打开后，只挪中心点确实在刘海下的第三方图标，并且不会为了刷新去重启控制中心 |
| 从外面控制 | 快捷键 | 快捷键 | 快捷键、快捷指令、Siri、App Intents、AppleScript、`iceplusplus://`，以及一份 Raycast 源码 |
| 分组和小部件 | | | 属于 Ice 自己的图标。见下面的限制 |
| 配置 | 本机偏好设置 | 本机偏好设置 | 本机偏好设置，另外可以导出、导入、恢复最近一次备份 |

Ice++ 仍有可见、隐藏、始终隐藏三个分区，可以拖拽布局，可以改菜单栏外观和间距，可以登录时打开，也可以按智能规则、定时或切换应用自动收回。它仍然需要辅助功能和屏幕录制。

## macOS 27 的限制

布局页上也写了这些。

- 隐藏按整个应用生效。一个应用的多个图标会一起移动。
- 蓝牙和音量不在那四项开关里，它们留在菜单栏上。
- 分组是 Ice 自己放上去的一个图标。点开某个成员后，那个应用会回到菜单栏大约 8 秒。macOS 不能把别人的图标合成进这一个菜单项。间隔条和小部件也属于 Ice。
- 没有 iCloud 同步。换一台 Mac 时，用导出的文件带走配置。

## 安装

到 [Releases](https://github.com/itworksig/IcePlusPlus/releases/latest) 下载。

| 文件 | 用途 |
| --- | --- |
| `Ice-arm64.dmg` | 手动安装。打开后把 `Ice.app` 拖进「应用程序」。 |
| `Ice.zip` | 同一个 arm64 应用。「检查更新」用这个包替换正在运行的副本。 |
| `release.json` | 这次构建的版本号、构建号和芯片架构。 |

安装包没有公证。第一次打开若被拦截，在终端执行：

```bash
xattr -d com.apple.quarantine /Applications/Ice.app
```

然后到「系统设置 → 隐私与安全性」打开辅助功能和屏幕录制。之后用同一份签名再安装，这两项授权可以继续匹配。从 GitHub 下载的包是临时签名，第一次换上时可能要重新打开一次授权。

只有自动化用到地点或 Wi-Fi 名称，或者你点了「使用当前位置」「使用当前网络」时，Ice++ 才会向系统申请位置。

## 检查更新

关于页的「检查更新」读取本仓库的最新 Release。

1. 读取正在运行的应用的 `CFBundleShortVersionString`。
2. 请求 `https://api.github.com/repos/itworksig/IcePlusPlus/releases/latest`。未登录时，这个接口全网每小时共享 60 次。遇到 HTTP 403 或 429，就打开 `https://github.com/itworksig/IcePlusPlus/releases/latest` 看它跳到的标签，并下载 `Ice.zip`。
3. 把标签 `vX.Y.Z` 和本机版本按数字比较。`v` 前缀和 `-beta` 这类后缀不参与比较。`1.0` 和 `1.0.0` 是同一个版本。
4. 远程版本更高才是更新。相等或更低表示当前已是最新。仓库还没有任何 Release 时，会提示还没有已发布的版本。
5. 「安装并重新打开」会下载 `Ice.zip`；没有 zip 时用 `Ice-arm64.dmg`。它会确认包里的应用标识是 `com.jordanbaird.Ice`、版本更高、并且是 arm64，然后换掉正在运行的副本并重新打开。

打开「自动检查更新」后，启动时查一次，之后大约每 24 小时再查一次。已经是最新时不弹窗。打开「自动下载更新」后，发现新版本会先下载，安装前会先问你。

`Info.plist` 里还留着 Sparkle 的 feed 字段。关于页不读那份 appcast。

## 不用打开菜单也能操作

```text
iceplusplus://focus
iceplusplus://show-hidden
iceplusplus://hide-hidden
iceplusplus://ice-bar
iceplusplus://preset?name=办公室
```

AppleScript 里的应用名是 `Ice++`。命令文本和链接的主机名相同。预设写成 `preset:` 加上名称。

```applescript
tell application "Ice++" to do command "focus"
tell application "Ice++" to do command "preset:办公室"
```

快捷指令和 Siri 使用这些 App Intent：切换专注、显示隐藏区、隐藏隐藏区、显示 Ice Bar、套用预设。

`raycast/ice-plusplus` 是一份通过这些链接调用 Ice++ 的 Raycast 扩展源码。克隆本仓库不会把它装进 Raycast。

## 发布一个版本

推送到 `main` 会跑 [Release 工作流](.github/workflows/release.yml)。Xcode 项目里的主版本或次版本如果高于 GitHub 上最新的 Release，就按项目里写的版本发布。同一条主次版本上的后续推送，会取项目版本和最新 Release 里较高的那个，再把最后一位加一。项目文件里现在是 **28.0.0**。不需要自己打 `vX.Y.Z` 标签。

任务跑在带 Xcode 27 的 `xcode-27` Apple 芯片镜像上。它上传 `Ice.zip`、`Ice-arm64.dmg` 和 `release.json`，再把新版本号写回项目。这次写回的提交信息里有 `[skip ci]`，所以这次记账推送不会再打一个包。

在 Actions 页手动运行 **Release Apple silicon** 会再发一个构建。

如果 Mac 托管机还没分到、任务在任何步骤开始前就被取消，[重试工作流](.github/workflows/retry-release.yml) 会再排队，最多三次。编译已经开始之后的失败会留在那里。

这个仓库是 fork。GitHub 在 [Actions](https://github.com/itworksig/IcePlusPlus/actions) 页启用之前不会跑工作流。启用之前的推送不会事后补跑。

## 本地开发

用本机的 Xcode.app 和 macOS 27 SDK 编译。调试版装到 `/Applications/Ice-Dev.app`，并用登录钥匙串里的 **Ice Dev** 证书签名，这样辅助功能和屏幕录制不用每次编译都重新授权。命令见 [script/README.md](script/README.md)。

## 许可

[GPL-3.0](LICENSE)。感谢 [Jordan Baird](https://github.com/jordanbaird) 的原始 Ice，以及 [cavaldos/Ice](https://github.com/cavaldos/Ice) 把它接到 macOS 27 上。
