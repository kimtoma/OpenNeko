# openNeko

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh.md)

openNeko は AI Agent と会話するオープンソースのデスクトップ・ピクセル猫です。画面下部に常駐し、タイピングやエージェントの状態シグナルに反応し、選んだAgent、クラウドモデル、ローカルモデルで短い吹き出し返答をします。

## 機能

- **AI Agent チャット**: 猫を短くクリックして吹き出し入力欄で会話。
- **OAuth 優先接続**: OpenAI/Codex、Claude、Gemini CLI ログインを先に使い、必要な場合だけ API キーを入力。
- **ローカルモデル**: Ollama とローカル OpenAI 互換サーバーをクラウド API キーなしで接続できます。
- **AI Agent 状態ブリッジ**: HTTP 状態イベントに加え、Cursor、Claude Code CLI、Codex CLI/App、Antigravity、Gemini、Kiro などのエージェントプロセス活動に反応します。
- **タイピング反応**: キー内容は読まず、入力が発生した事実だけを使います。
- **スキン**: 5つの同梱スキン、外部スキンフォルダ、スプライト抽出ツール。
- **スキル**: `SKILL.md` プロンプトをメニューやスラッシュコマンドから実行。
- **ご近所猫**: 同じ LAN の openNeko を発見し、ゲスト猫として表示。

## インストール

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/kimtoma/openNeko/refs/heads/main/scripts/install.ps1 | iex
```

`git` と Node.js `22.12+` が必要です。ログイン時の自動起動を無効にするには、実行前に `OPENNEKO_NO_AUTOSTART=1` を設定してください。

## ソースから実行

```bash
git clone https://github.com/kimtoma/openNeko.git
cd openNeko
npm install
npm run build
npm start
```

API キーなしで使う場合は、対応 CLI に先にログインしてください: `codex login`, `claude`, `gemini`。Ollama とローカル OpenAI 互換エンドポイントは設定で追加できます。

## AI Provider

- `chatgpt-oauth`: ローカル Codex CLI の OpenAI ログインを使用。`codex login` が必要です。
- `claude-oauth`: ローカル Claude Code ログインを使用。
- `gemini-oauth`: ローカル Gemini CLI の Google ログインを使用。
- `ollama`: ローカル Ollama サーバーを使用。
- `local-openai`: LM Studio、llama.cpp、vLLM などのローカル OpenAI 互換サーバー。
- `gemini`: Google AI Studio の Gemini API キーを使用。
- `claude`: Anthropic API キーを使用。
- `custom`: 任意の OpenAI 互換エンドポイント。サーバーが必要とする場合だけ API キーを入力します。

## 状態ブリッジ

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

デバッグ: `/health`, `/anim`, `/capture`。2つ目のインスタンスは `OPENNEKO_PORT=48801` で起動できます。

## スキル

ユーザースキル:

```text
~/.openneko/skills/<skill-id>/SKILL.md
```

スキル本文は現在の AI provider の system 指示として注入されます。スクリプトは実行しません。

## 開発

```bash
npm test
npm run build
```

`src/renderer/cat2d.js` または `src/settings/settings.js` を変更したら `npm run build` を実行してください。

## ライセンス

MIT
