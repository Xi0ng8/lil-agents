# TODO.md — lil agents 开发任务清单

## P0 — 关键 Bug 修复

- [x] **P0-0**: 国际化基础架构（中英文）
  - 新增 `en.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings`
  - 修改所有 Swift 文件使用 `NSLocalizedString`
  - 支持系统语言自动切换

- [x] **P0-1**: `ClaudeSession.terminate()` 未清理 `readabilityHandler`，可能导致回调泄漏
  - 文件: `LilAgents/ClaudeSession.swift`
  - 方案: terminate() 中调用 super.terminate() 清理 readabilityHandler

- [x] **P0-2**: `NSScreen.main!` 强制解包可能崩溃
  - 文件: `LilAgents/WalkerCharacter.swift`
  - 方案: 改为 `guard let screen = NSScreen.main else { return }`

- [x] **P0-3**: `CopilotSession` 中 `collectedPlainText` 是局部变量，多次 send() 不累积
  - 文件: `LilAgents/CopilotSession.swift`
  - 方案: 提升为实例属性

- [x] **P0-4**: `wireSession` 的 `providerName` 默认绑定到 `AgentProvider.current`，切换后旧 session 显示错误名称
  - 文件: `LilAgents/WalkerCharacter.swift`
  - 方案: session 创建时捕获当前 provider name 传入

## P1 — 代码质量改进

- [x] **P1-1**: 提取三个 Session 的重复代码到 `BaseAgentSession` 基类
  - 新增: `BaseAgentSession.swift` 封装通用的 process/pipe/error handling 逻辑
  - 三个 Session 继承 BaseAgentSession，仅保留特有逻辑

- [x] **P1-2**: 补全 i18n 遗漏的硬编码字符串
  - 新增 8 个 key: `onboarding.greeting`, `terminal.userPrefix`, `terminal.done`, `terminal.fail`, `completion.fallback`, `thinking.fallback`, `error.codex.turn_failed`, `error.unknown`

- [x] **P1-3**: 主题切换后 thinking bubble 样式不更新
  - switchTheme 中重建 thinkingBubbleWindow

- [x] **P1-4**: 主题初始选中状态未从 UserDefaults 读取
  - PopoverTheme.current 改为计算属性，通过 UserDefaults 持久化

- [x] **P1-5**: Onboarding 的 click-outside 检测未检查点击位置
  - 改为检查点击是否在 popover/character 窗口内

- [x] **P1-6**: 角色 toggle 隐藏后再次显示不恢复播放
  - else 分支中调用 `char.queuePlayer.play()`

## P2 — 性能与可维护性

- [x] **P2-1**: 提取魔法数字为命名常量
  - 新增 `private enum Layout` 存放 12 个布局常量

- [x] **P2-2**: 缓存 `localizedThinkingPhrases`/`localizedCompletionPhrases`
  - 改为 `private lazy var`

- [x] **P2-3**: 缓存 `resolvedTheme`
  - 添加缓存属性，通过 id 比较实现缓存失效

- [x] **P2-4**: 拆分 `WalkerCharacter.update()` 过长方法
  - 拆分为 `updateIdle()`、`updatePaused()`、`updateWalking()`

- [ ] **P2-5**: 拆分 `setupMenuBar()` 过长方法
  - 文件: `LilAgents/LilAgentsApp.swift`
  - 方案: 拆分为 `createCharacterMenuItems()`、`createProviderSubmenu()` 等

- [x] **P2-6**: 统一 `PopoverTheme` 静态属性命名
  - `teenageEngineering` → `midnight`，`playful` → `peach`，`wii` → `cloud`，`iPod` → `moss`

- [ ] **P2-7**: 监听显示器热插拔刷新显示子菜单
  - 文件: `LilAgents/LilAgentsApp.swift`, `LilAgents/LilAgentsController.swift`
  - 方案: 监听 `didChangeScreenParametersNotification` 刷新菜单