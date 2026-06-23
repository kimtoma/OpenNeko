# openNeko

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh.md)

openNeko は GPT と会話するオープンソースのデスクトップ・ピクセル猫です。画面下部に常駐し、タイピングやエージェントの状態シグナルに反応し、短い吹き出しで返事します。

## 機能

- **GPT チャット**: 猫を短くクリックして吹き出し入力欄で会話。
- **OpenAI 互換 provider**: OpenAI GPT、ローカル Ollama、任意の `/v1/chat/completions` エンドポイント。
- **状態ブリッジ**: HTTP で `thinking`, `coding`, `success`, `error` などを送信。
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

起動前に `OPENAI_API_KEY` を設定するか、設定画面で API キーを保存してください。

## Provider

- `openai`: `https://api.openai.com/v1`, default model `gpt-4o-mini`.
- `ollama`: `http://localhost:11434/v1`, default model `llama3.2`.
- `custom`: 任意の OpenAI 互換エンドポイント。

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

スキル本文は現在の GPT provider の system 指示として注入されます。スクリプトは実行しません。

## 開発

```bash
npm test
npm run build
```

`src/renderer/cat2d.js` または `src/settings/settings.js` を変更したら `npm run build` を実行してください。

## ライセンス

MIT
