# lil agents

![lil agents](hero-thumbnail.png)

住在你 macOS Dock 栏上的桌面小精灵。

**Bruce** 和 **Jazz** 会在你的 Dock 栏上方来回走动。点击它们即可打开 AI 终端。它们走路、思考、陪伴你工作。

支持 **Claude Code**、**OpenAI Codex** 和 **GitHub Copilot** CLI — 通过菜单栏随时切换。

## 功能特性

- 透明 HEVC 视频渲染的动画角色
- 点击角色打开主题化的弹出式 AI 终端
- 通过菜单栏在 Claude、Codex 和 Copilot 之间切换
- 四款视觉主题：蜜桃、午夜、云朵、青苔
- AI 工作时显示有趣的思考气泡
- 完成时播放音效
- 首次运行的友好引导界面
- 通过 Sparkle 自动更新

## 系统要求

- macOS Sonoma (14.0+)
- 至少安装一个支持的 CLI：
  - [Claude Code](https://claude.ai/download)
  - [OpenAI Codex](https://github.com/openai/codex) — `npm install -g @openai/codex`
  - [GitHub Copilot](https://github.com/github/copilot-cli) — `brew install copilot-cli`

## 构建

在 Xcode 中打开 `lil-agents.xcodeproj`，然后按 Cmd+R 运行。

## 隐私

lil agents 完全在你的 Mac 上运行，不会向任何地方发送个人数据。

- **数据留在本地。** 应用播放内置动画并计算 Dock 大小来定位角色。不收集或传输任何项目数据、文件路径或个人信息。
- **AI 提供商。** 对话完全由你选择的 CLI 进程（Claude、Codex 或 Copilot）在本地处理。lil agents 不会拦截、存储或传输你的聊天内容。发送给提供商的任何数据受其各自的条款和隐私政策约束。
- **无需账号。** 无登录、无用户数据库、应用内无分析。
- **更新。** lil agents 使用 Sparkle 检查更新，仅发送你的应用版本和 macOS 版本，不发送其他信息。

## 许可证

MIT 许可证。详见 [LICENSE](LICENSE)。
