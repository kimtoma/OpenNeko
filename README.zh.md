# openNeko

[English](README.md) · [한국어](README.ko.md) · [日本語](README.ja.md)

openNeko 是一个面向 GPT 的开源桌面像素猫。它常驻屏幕底部，响应键盘输入和外部状态信号，并通过简短气泡回复你。

## 功能

- **GPT 聊天**: 短按猫咪，打开气泡输入框。
- **OpenAI 兼容 provider**: 默认 OpenAI GPT、本地 Ollama、自定义 `/v1/chat/completions` 端点。
- **状态桥接**: 通过 HTTP 发送 `thinking`, `coding`, `success`, `error` 等状态。
- **输入反应**: 只使用“发生了按键”这个事实，不读取按键内容。
- **皮肤**: 5 个内置皮肤、外部皮肤目录、精灵图提取工具。
- **技能**: 从菜单或斜杠命令触发 `SKILL.md` 提示词。
- **邻居猫**: 自动发现同一 LAN 中的其他 openNeko，并显示为来访猫。

## 安装

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.ps1 | iex
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

启动前设置 `OPENAI_API_KEY`，或在设置中保存 API key。

## Provider

- `openai`: `https://api.openai.com/v1`，默认模型 `gpt-4o-mini`。
- `ollama`: `http://localhost:11434/v1`，默认模型 `llama3.2`。
- `custom`: 任意 OpenAI 兼容端点。

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

技能正文会作为当前 GPT provider 的 system 指令注入，不执行脚本。

## 开发

```bash
npm test
npm run build
```

修改 `src/renderer/cat2d.js` 或 `src/settings/settings.js` 后请运行 `npm run build`。

## 许可证

MIT
