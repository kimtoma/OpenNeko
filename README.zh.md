# openNeko

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md)

openNeko 是一个面向 AI Agent 的开源桌面像素猫。它常驻屏幕底部，响应键盘输入和外部状态信号，并通过你选择的 Agent、云端模型或本地模型用简短气泡回复你。

## 功能

- **AI Agent 聊天**: 短按猫咪，打开气泡输入框。
- **优先 OAuth 连接**: 优先使用 OpenAI/Codex、Claude、Gemini CLI 登录，只有需要时才输入 API 密钥。
- **本地模型**: 可连接 Ollama 和本地 OpenAI 兼容服务器，无需云端 API 密钥。
- **AI Agent 状态桥接**: 响应 HTTP 状态事件，也会感知 Cursor、Claude Code CLI、Codex CLI/App、Antigravity、Gemini、Kiro 等代理进程活动。
- **输入反应**: 只使用“发生了按键”这个事实，不读取按键内容。
- **皮肤**: 5 个内置皮肤、外部皮肤目录、精灵图提取工具。
- **技能**: 从菜单或斜杠命令触发 `SKILL.md` 提示词。
- **邻居猫**: 自动发现同一 LAN 中的其他 openNeko，并显示为来访猫。

## 安装

macOS:

```bash
curl -fsSL https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.sh | bash
```

Windows PowerShell:

```powershell
irm https://github.com/kimtoma/openNeko/releases/latest/download/openneko-install.ps1 | iex
```

需要 `git` 和 Node.js `22.12+`。如需跳过登录自动启动，请在安装前设置 `OPENNEKO_NO_AUTOSTART=1`。

## 从源码运行

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

如果想不用 API 密钥，请先登录支持的 CLI：`codex login`、`claude`、`gemini`。Ollama 和本地 OpenAI 兼容端点可在设置中添加。

## AI Provider

- `chatgpt-oauth`: 使用本机 Codex CLI 的 OpenAI 登录。需要先运行 `codex login`。
- `claude-oauth`: 使用本机 Claude Code 登录。
- `gemini-oauth`: 使用本机 Gemini CLI 的 Google 登录。
- `ollama`: 使用本地 Ollama 服务器。
- `local-openai`: LM Studio、llama.cpp、vLLM 等本地 OpenAI 兼容服务器。
- `gemini`: 使用 Google AI Studio Gemini API 密钥。
- `claude`: 使用 Anthropic API 密钥。
- `custom`: 任意 OpenAI 兼容端点。仅当服务器要求时输入 API 密钥。

## 状态桥接

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

调试端点: `/health`, `/anim`, `/capture`。第二个实例可用 `OPENNEKO_PORT=48801` 启动。

## 技能

用户技能目录:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

技能正文会作为当前 AI provider 的 system 指令注入，不执行脚本。

## 开发

```bash
npm test
npm run build
```

修改 `src/renderer/cat2d.js` 或 `src/settings/settings.js` 后请运行 `npm run build`。

## 许可证

MIT
