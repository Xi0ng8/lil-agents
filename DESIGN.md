# DESIGN.md — lil agents 设计文档

## 项目架构

### 整体架构

```
┌─────────────────────────────────────────────────┐
│                 LilAgentsApp                    │
│           (SwiftUI App Entry + AppDelegate)     │
├─────────────────────────────────────────────────┤
│              LilAgentsController                │
│     (Dock几何检测 · CVDisplayLink · 角色调度)    │
├──────────────┬──────────────┬───────────────────┤
│ WalkerCharacter │ WalkerCharacter │ ...          │
│   (Bruce)       │   (Jazz)        │              │
├─────────────────┴─────────────────┴──────────────┤
│  AVPlayer/Looper │ PopoverWindow │ TerminalView  │
│  (视频播放)       │ (窗口管理)    │ (终端渲染)    │
├──────────────────────────────────────────────────┤
│            AgentSession Protocol                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  │ Claude   │ │ Codex    │ │ Copilot  │         │
│  │ Session  │ │ Session  │ │ Session  │         │
│  └──────────┘ └──────────┘ └──────────┘         │
├──────────────────────────────────────────────────┤
│          ShellEnvironment (PATH 解析)            │
└──────────────────────────────────────────────────┘
```

### 核心组件职责

| 组件 | 职责 | 文件 |
|------|------|------|
| `LilAgentsApp` | SwiftUI App 入口，AppDelegate 管理菜单栏 | `LilAgentsApp.swift` |
| `LilAgentsController` | 角色生命周期管理，Dock 几何检测，动画调度 | `LilAgentsController.swift` |
| `WalkerCharacter` | 角色视频播放，行走动画，Popover 管理，Session 管理，气泡显示 | `WalkerCharacter.swift` |
| `CharacterContentView` | Alpha 透明度点击检测 | `CharacterContentView.swift` |
| `TerminalView` | NSTextView 终端，Markdown 渲染，输入处理 | `TerminalView.swift` |
| `PopoverTheme` | 主题定义（颜色/字体/布局），主题切换 | `PopoverTheme.swift` |
| `AgentSession` | 协议定义，Provider 枚举 | `AgentSession.swift` |
| `ClaudeSession` | Claude CLI 集成 | `ClaudeSession.swift` |
| `CodexSession` | OpenAI Codex CLI 集成 | `CodexSession.swift` |
| `CopilotSession` | GitHub Copilot CLI 集成 | `CopilotSession.swift` |
| `ShellEnvironment` | Shell PATH 解析，二进制查找 | `ShellEnvironment.swift` |

### 动画系统

使用 `CVDisplayLink` 驱动 60fps 动画循环。角色状态机：

```
Idle → Walking → Idle (pause) → Walking → ...
       ↑                         ↑
    CVDisplayLink tick          random delay
```

行走参数（per-character）：
- `accelStart`: 开始加速时间
- `fullSpeedStart`: 达到全速时间
- `decelStart`: 开始减速时间
- `walkStop`: 停止时间

### Session 生命周期

```
start() → onSessionReady() → send(message)
    ↓         ↓                    ↓
Process    CLI就绪            onText/onToolUse/onToolResult
    ↓                              ↓
onError/onProcessExit          onTurnComplete → 等待下一次 send
```

### 国际化方案

- 使用 `NSLocalizedString` + `Localizable.strings`
- 支持语言：英文 (`en`)、简体中文 (`zh-Hans`)
- 系统自动根据语言偏好选择
- Key 命名规范：`{类别}.{语义}`，如 `menu.bruce`、`thinking.hmm`

### 主题系统

4 个预设主题：Midnight、Peach、Cloud、Moss

主题属性包含：
- Popover 外观（背景/边框/圆角）
- 标题栏样式（字体/颜色/格式）
- 终端字体（等宽/系统字体）
- 颜色方案（文本/强调色/错误/成功）
- 气泡样式（背景/边框/文字）
- 输入框样式

### 外部依赖

- **Sparkle** (v2.6.0+): 自动更新，通过 SPM 集成
- **AVFoundation**: 视频播放
- **AppKit**: 全部 UI 组件

## 设计决策记录

### D001: 选择 AppKit 而非 SwiftUI
**原因**: 角色动画需要精确的窗口层级控制、CVDisplayLink 集成、透明窗口等 AppKit 特有能力。SwiftUI 仅用于 App 入口。

### D002: CVDisplayLink 而非 Timer
**原因**: 与显示器刷新率同步，动画更流畅。CVDisplayLink 回调在独立线程运行，通过 DispatchQueue.main.async 调度 UI 更新。

### D003: Process/pipe 而非 async/await
**原因**: CLI 子进程需要实时读取 stdout/stderr 流。Process + pipe + readabilityHandler 提供逐行处理能力。

### D004: 无测试目标
**原因**: 项目初期快速迭代，核心逻辑（行走动画、CLI 集成）高度依赖系统环境，难以单元测试。后期可为纯逻辑（markdown 渲染、JSON 解析）添加测试。

### D005: 国际化使用 NSLocalizedString
**原因**: 标准方案，系统自动处理语言选择。不引入第三方库。角色名（Bruce/Jazz）保持英文不翻译。

### D006: 主题通过 id 而非 name 比较
**原因**: name 是本地化字符串，运行时会变化。使用固定 id（"midnight"/"peach"/"cloud"/"moss"）做逻辑判断。
