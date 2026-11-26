# OpenNeko

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | 简体中文

OpenNeko 是一只面向 AI Agent 的原生 macOS 桌面像素猫。它会在桌面上行走，在不读取按键内容的情况下响应打字，监听本地 Agent 状态，并在你需要快速回答时打开一个小聊天气泡。

当前应用是将早期 Electron 原型移植到 Swift 和 SwiftUI macOS 应用后的版本。

## 主要功能

- 透明、始终置顶的桌面小猫
- 内置皮肤、外部皮肤文件夹和自定义皮肤导入
- 不读取按键内容的打字响应
- 检测 Cursor、Codex、Gemini、Claude、Antigravity、Kiro 等本地 AI Agent 活动
- 小聊天气泡、斜杠命令和技能提示词
- 聊天历史窗口和点击复制回答
- 同一本地网络中的邻居小猫
- 休息提醒：连续打字超过 50 分钟时提醒伸展、休息眼睛或喝水（每天最多 6 次，可在通用设置中关闭）
- 用于自动化的本地 HTTP 状态桥接
- 登录时启动、语言、声音、皮肤、AI、个人资料和邻居设置
- ZIP 和 DMG 发布打包脚本

## 要求

- macOS 14 或更高版本
- Xcode
- XcodeGen
- 可选: 默认 OpenAI 登录 provider 使用的 Codex CLI 登录
- 可选: Claude 或 Gemini 登录 provider 使用的 CLI 登录
- 可选: Gemini、Claude 或 OpenAI 兼容端点的 API Key

## 从源码运行

```bash
xcodegen generate
swift test
./script/build_and_run.sh
```

使用 Xcode 直接构建:

```bash
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug build
```

Codex 桌面 Run 操作已连接到 `./script/build_and_run.sh`。

## 首次启动

打开 `OpenNeko.app`。首次启动时会显示 onboarding，依次介绍主要功能、皮肤选择、小猫名字、权限、登录时启动、AI 连接和完成说明。

打字响应需要输入监控权限。OpenNeko 只监听 keydown 活动，不读取输入文本。

## AI Provider

OpenNeko 支持以下 provider preset:

- OpenAI 登录 (Codex): 使用本地 Codex CLI 登录会话。
- Claude 登录: 使用本地 Claude CLI 登录会话。
- Gemini 登录: 使用 Gemini CLI 的 Google 登录会话。
- Ollama: 连接本地 Ollama OpenAI 兼容服务器。
  没有订阅？在 **设置 → AI → 设置本地模型** 中检查 Mac 的内存和可用空间，引导安装 Ollama，下载合适的模型并直接连接（仅限 Apple 芯片）。
- 本地 OpenAI 兼容: 连接 LM Studio、llama.cpp、vLLM 等服务。
- Apple 设备端模型：在 macOS 26 及以上并开启 Apple Intelligence 的 Mac 上用内置模型回复（无需下载和密钥）。应用仍支持 macOS 14，只是此预设会显示为不可用。
- Gemini API Key: 使用 `GEMINI_API_KEY` 或 `GOOGLE_API_KEY`。
- Claude API Key: 使用 `ANTHROPIC_API_KEY`。
- 自定义: 手动输入 OpenAI 兼容 Base URL、API Key 和模型。

保存的 API Key 会存入 macOS Keychain，而不是 `settings.json`。

## 猫咪工具

可以像“设一个 3 分钟计时器”这样请求计时器、提醒、复制文字或打开网页。模型提出操作后，猫咪会先询问，点击气泡才会执行。计时器和提醒在 OpenNeko 运行期间有效。可在 AI 设置的 **猫咪工具** 中关闭。

## 选中的文字

在任意应用中选中文字，然后选择 **服务 → openNeko：解释 / 翻译 / 总结**（也可以右键 → 服务），猫咪会用当前 AI 连接在气泡里回答。只使用你发送的文字。如果安装后菜单没有出现，请注销并重新登录一次。

## 语音输入

点一下聊天框里的🎤按钮再说话。停顿约2秒或再点一次即结束，按 Esc 取消并恢复原来输入的文字。语音只在这台 Mac 上识别（macOS 本机语音识别），文字会进入聊天框，发送前可以修改。如果这台 Mac 无法在本机识别该语言，语音输入会保持关闭，不会把音频发送到服务器。第一次使用时会请求麦克风和语音识别权限。

## 主动搭话

猫咪主动说的话（休息提醒、午饭和下班问候、记忆提议、邻居猫、例程、新功能介绍）都经过同一套规则。在菜单的 **话痨程度** 里可选安静（每天3次）、普通（8次）、话痨（15次）。智能体通知和例程不计入次数。当会议应用（Zoom、Teams、FaceTime、Webex）在前台，或 Keynote、PowerPoint、视频应用占满屏幕时，提议会跳过，例程会等待。在提议之后回复“别说了”，这类话就会关闭，可在话痨程度菜单里恢复。

## 记忆

猫咪会在 `~/.openneko/memory/` 里保存三个普通的 Markdown 文件：

- `soul.md`：猫咪的性格和语气。只有你能修改，留空则使用默认性格。
- `user.md`：关于你的长期事实。猫咪会在气泡里问“可以记住吗？”，你点击后才新增一行。
- `memory.md`：最近的情况。猫咪自动记录（点击气泡可撤销）。超过约 4 KB 时，旧的行会移到 `archive/YYYY-MM.md`，不会删除任何内容。

当你提到以前聊过的事，猫咪会搜索本地聊天记录，把最多三段相关对话加入提示词。可以在菜单的 **记忆笔记**（或 设置 > 记忆）里查看和编辑这些文件。本地模型始终使用记忆；对云端 AI 可以选择发送范围（全部、仅性格、不发送）。看起来像密码、密钥或卡号的内容不会被保存。

## 委派任务

在聊天气泡中输入 `/task 要做的事` 并选择项目文件夹，猫咪会把任务交给本地 Claude Code CLI，只在该文件夹内执行。允许读取和编辑文件夹内的文件，其他操作（shell 命令、网络）会作为批准请求返回：点击气泡即可仅针对本次任务允许或拒绝。主目录、根目录和系统文件夹会被拒绝。所有步骤都会记录到 `~/Library/Application Support/openNeko/agent-activity.jsonl`，可用 `/tasklog` 打开。`/task stop` 取消。

## 例程

在设置 → 日常 → 例程里，可以让猫咪在固定时间做事，比如工作日早间简报或下班收尾（OpenNeko 运行时生效）。没有文件夹的例程会用当前 AI 连接在气泡里回答；选了文件夹的例程会在该文件夹内以只读方式运行 Claude Code（例如总结昨天的提交）。其他操作会先询问你。每个例程每天最多运行一次；Mac 睡眠时错过的例程，如果在两小时内唤醒仍会运行。

## 日历

打开 **设置 → 日常 → 查看日历和提醒事项** 后，macOS 会请求一次权限。之后猫咪在聊天时会知道今天剩余的日程和今天到期的提醒事项（早间简报例程也会用到），并在日程开始前约10分钟用气泡提醒你。只读取标题和时间，不读取备注、参与者或地点。日程标题作为数据而不是指令传给 AI。会议或演示画面在前台时，提醒会等一等再说。关闭开关即可停止。

## 技能

内置技能和用户技能都是保存为 `SKILL.md` 的提示词指令。技能中的脚本不会被执行。

- 内置技能: `App/Resources/skills/builtin/`
- 用户技能: `~/.openneko/skills/<id>/SKILL.md`

可以通过设置窗口、菜单栏技能菜单或聊天输入框中的斜杠命令列表运行技能。

## 自定义皮肤

皮肤设置页面支持两种自定义皮肤流程。

- 用猫咪照片创建请求文件: 保存一个 `.openneko-skin-request` 包，包含照片、元数据、当前 manifest 和生成提示词。
- 导入完成的 `.openneko-skin`、`.zip` 或皮肤文件夹。

完成的皮肤包含 `manifest.json`、`openneko-skin.json`，以及与 manifest 文件名匹配的透明 PNG 帧。导入的皮肤会安装到:

```text
~/Library/Application Support/openNeko/skins/<id>/
```

## 状态桥接

OpenNeko 默认监听 `127.0.0.1:48800`。

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

调试端点:

- `GET /health`
- `GET /anim`
- `GET /pos`
- `GET /debug/position`
- `GET /capture`
- `GET /debug/settings`
- `POST /debug/settings/apply`
- `GET /debug/agent`
- `POST /debug/drag`
- `POST /debug/typing`

使用其他本地端口:

```bash
OPENNEKO_PORT=48801 /path/to/OpenNeko.app/Contents/MacOS/OpenNeko
```

### 智能体通知

Claude Code 或 Codex 完成任务或需要你批准时，猫咪会提醒你。
在 设置 > 高级 > 智能体通知 中复制配置片段。

- Claude Code (`~/.claude/settings.json`)：`Notification` 钩子发送 `waiting`，
  `Stop` 钩子发送 `done`。
- Codex (`~/.codex/config.toml` 顶部)：`notify` 命令发送 `done`。

桥接还接受 `waiting`、`needs_input`、`attention`(猫咪请求你确认并保持 10 分钟)
以及 `done`、`finished`、`complete`(显示为 `success`)。OpenNeko 不会自动修改这些文件。

## 打包

运行本地发布检查:

```bash
scripts/release-preflight.sh local
scripts/release-preflight.sh distribution
scripts/release-preflight.sh notarized
```

创建 ZIP 和 DMG 包:

```bash
scripts/package-macos.sh
```

产物位置:

- `dist/OpenNeko-macOS-Release.zip`
- `dist/OpenNeko-macOS-Release.dmg`

验证包:

```bash
scripts/verify-macos-package.sh
```

`distribution` 和 `notarized` 检查需要签名机器上可用的 Developer ID Application 证书和 Apple 公证凭据。

## 从 Electron 迁移

原生应用会从以下位置读取旧 Electron `settings.json`:

```text
~/Library/Application Support/openNeko/
```

它会保留所选皮肤、AI provider preset/base URL/model、onboarding 状态、登录时启动偏好、语言、声音、网页搜索、用户资料、邻居设置和 peer ID。

Electron `safeStorage` 的 API Key 密文不会导入。请在 AI 设置页面重新保存 API Key，使其存入 macOS Keychain。

## 许可证

OpenNeko 以 MIT License 发布。
