# AGENTS.md — lil agents 开发指南

## 项目概述

**lil agents** 是一个 macOS 菜单栏应用，在 Dock 栏上方显示动画角色（Bruce & Jazz）。点击角色打开弹出式 AI 终端，支持 Claude Code、OpenAI Codex 和 GitHub Copilot CLI。

- **平台：** macOS Sonoma 14.0+
- **语言：** Swift 5.0
- **UI 框架：** AppKit + SwiftUI（SwiftUI 仅用于 `App` 入口，所有视图均为 AppKit）
- **外部依赖：** [Sparkle](https://github.com/sparkle-project/Sparkle) v2.6.0+（自动更新，通过 SPM）
- **无测试目标**

## 构建与运行

在 Xcode 中打开项目并按 Cmd+R，或使用命令行：

```bash
# Debug 构建
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Debug build

# Release 构建
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Release build

# 清理构建目录
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents clean
```

构建产物输出到 `build/Debug/` 或 `build/Release/`。项目**无测试、无 lint、无类型检查命令** — 没有测试目标，也没有配置 SwiftLint 等工具。

## 项目结构

```
lil-agents/
├── LilAgents/
│   ├── LilAgentsApp.swift          # App 入口，AppDelegate，菜单栏设置
│   ├── LilAgentsController.swift   # 主控制器，Dock 几何检测，动画调度
│   ├── WalkerCharacter.swift       # 角色视频、弹出框、思考气泡、Session 管理
│   ├── CharacterContentView.swift  # 基于 Alpha 透明度的点击检测
│   ├── TerminalView.swift          # NSTextView 终端，支持 Markdown 渲染
│   ├── PopoverTheme.swift          # 主题定义（午夜、蜜桃、云朵、青苔）
│   ├── AgentSession.swift          # AgentSession 协议 + AgentProvider 枚举
│   ├── BaseAgentSession.swift      # Session 基类，封装通用逻辑
│   ├── ClaudeSession.swift         # Claude CLI 集成
│   ├── CodexSession.swift          # OpenAI Codex CLI 集成
│   ├── CopilotSession.swift        # GitHub Copilot CLI 集成
│   ├── ShellEnvironment.swift      # Shell PATH 解析与二进制查找
│   ├── Info.plist                  # 应用元数据，Sparkle 配置
│   ├── LilAgents.entitlements      # 应用沙盒已禁用
│   ├── Assets.xcassets/            # 应用图标、菜单栏图标
│   ├── Sounds/                     # 提示音效（mp3/m4a）
│   ├── en.lproj/                   # 英文本地化
│   ├── zh-Hans.lproj/              # 简体中文本地化
│   └── walk-*.mov                  # 角色行走动画（HEVC，透明背景）
├── lil-agents.xcodeproj/
├── README.md                       # 项目说明
├── DESIGN.md                       # 设计文档
├── TODO.md                         # 开发任务清单
├── AGENTS.md                       # 本文件，开发指南
├── LICENSE                         # MIT 许可证
└── appcast.xml                     # Sparkle 更新源
```

## 代码规范

### 命名约定
- **类型：** PascalCase（`WalkerCharacter`、`AgentSession`、`PopoverTheme`）
- **属性/方法：** camelCase（`currentProvider`、`startWalking()`）
- **常量：** camelCase，无 `k` 前缀
- **UserDefaults 键：** camelCase 字符串字面量（`"hasCompletedOnboarding"`、`"selectedProvider"`）
- **文件名：** 与主类型名完全一致

### 导入
- 每个文件只导入需要的模块：`SwiftUI`、`AppKit`、`AVFoundation`、`Foundation`
- 不使用 `@testable import`（无测试目标）

### 架构模式
- **不使用 SwiftUI 视图** — 所有 UI 均为纯 AppKit（`NSWindow`、`NSTextView`、`NSPopover`）
- 唯一的 SwiftUI 是带 `@NSApplicationDelegateAdaptor` 的 `@main App` 结构体
- 控制器是普通类（非 `ObservableObject`），通过 `AppDelegate` 中的强引用管理
- 使用 `CVDisplayLink` 驱动动画，而非 `Timer`
- 协议定义 Agent Session 契约（`AgentSession` 协议使用闭包回调）

### 错误处理
- 错误通过可选闭包回调传递，不使用 `throws`
- 模式：`onError: ((String) -> Void)?`
- CLI 未找到的错误显示安装说明作为用户可见的字符串

### 内存管理
- 在闭包和事件监听器中使用 `[weak self]`
- 在 CVDisplayLink 回调中使用 `Unmanaged.passUnretained(self)`（性能关键）
- 存储 `NSEvent.addGlobalMonitorForEvents` 监听器并在清理时移除

### 并发
- 所有 UI 更新使用 `DispatchQueue.main.async` 从后台线程调度
- 不使用 async/await — 基于 Process/pipe 的子进程执行
- 角色动画更新在 CVDisplayLink 线程运行，UI 更新调度到主线程

### 字符串与国际化
- 使用 `NSLocalizedString` + `Localizable.strings` 进行国际化
- 支持语言：英文 (`en`)、简体中文 (`zh-Hans`)
- Key 命名规范：`{类别}.{语义}`，如 `menu.bruce`、`thinking.hmm`

### 代码格式
- 4 空格缩进
- 左花括号同行：`if condition {`
- 优先使用尾随闭包
- 无强制格式化工具（未配置 SwiftFormat/SwiftLint）

## 关键实现细节

- **Dock 检测：** 通过 `UserDefaults(suiteName:)` 读取 macOS Dock 磁贴大小
- **角色定位：** 计算屏幕宽度减去 Dock 磁贴数量来找到空闲空间
- **视频播放：** 使用 `AVPlayerLooper` + `AVQueuePlayer` 无缝循环播放透明 HEVC `.mov` 文件
- **弹出式终端：** 自定义 `NSTextView` 子类，使用正则表达式将 Markdown 解析为 NSAttributedString
- **Sparkle 集成：** `SPUStandardUpdaterController` 由 `AppDelegate` 持有；菜单项提供"检查更新"功能
