# OpenNeko

[English](README.md) | [한국어](README.ko.md) | 日本語 | [简体中文](README.zh.md)

OpenNekoは、AIエージェントのためのネイティブmacOSデスクトップピクセル猫です。デスクトップ上を歩き、キーの内容を読まずにタイピングへ反応し、ローカルエージェント状態を受け取り、短い回答が必要なときに小さなチャット吹き出しを開きます。

現在のアプリは、以前のElectronプロトタイプをSwiftとSwiftUIのmacOSアプリへ移植したものです。

## 主な機能

- 透明で常に前面に表示されるデスクトップ猫
- 同梱スキン、外部スキンフォルダ、カスタムスキンのインポート
- キー内容を読まないタイピング反応
- Cursor、Codex、Gemini、Claude、Antigravity、KiroなどのローカルAIエージェント活動検知
- 小さなチャット吹き出し、スラッシュコマンド、スキルプロンプト
- チャット履歴ウィンドウと回答クリックコピー
- 同じローカルネットワーク上の近所の猫
- 休憩リマインダー: 50分以上入力が続くとストレッチ・目の休憩・水分補給をすすめる (1日最大6回、一般設定でオフ可)
- 自動化用のローカルHTTP状態ブリッジ
- ログイン時に起動、言語、サウンド、スキン、AI、プロフィール、近所設定
- ZIPとDMGのリリースパッケージスクリプト

## 必要環境

- macOS 14以降
- Xcode
- XcodeGen
- 任意: デフォルトのOpenAIログインprovider用Codex CLIログイン
- 任意: ClaudeまたはGeminiログインprovider用CLIログイン
- 任意: Gemini、Claude、OpenAI互換エンドポイント用APIキー

## ソースから実行

```bash
xcodegen generate
swift test
./script/build_and_run.sh
```

Xcodeで直接ビルド:

```bash
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug build
```

CodexデスクトップのRunアクションは`./script/build_and_run.sh`に接続されています。

## 初回起動

`OpenNeko.app`を開くと、初回オンボーディングが表示されます。主な機能、スキン選択、猫の名前、権限、ログイン時起動、AI接続、完了案内の順に進みます。

タイピング反応には入力監視権限が必要です。OpenNekoはkeydown活動だけを検知し、入力されたテキストは読みません。

## AI Provider

OpenNekoは次のprovider presetをサポートします。

- OpenAIログイン (Codex): ローカルCodex CLIログインセッションを使います。
- Claudeログイン: ローカルClaude CLIログインセッションを使います。
- Geminiログイン: Gemini CLIのGoogleログインセッションを使います。
- Ollama: ローカルOllama OpenAI互換サーバーへ接続します。
  サブスクがなくても **設定 → AI → ローカルモデルの設定** でMacのメモリと空き容量を確認し、Ollamaの導入を案内して、合うモデルをダウンロードして接続します (Apple Silicon専用)。
- ローカルOpenAI互換: LM Studio、llama.cpp、vLLMなどへ接続します。
- Appleオンデバイスモデル: macOS 26以降でApple IntelligenceがオンのMacなら内蔵モデルで返答します（ダウンロード・キー不要）。アプリはmacOS 14でも動作し、このプリセットだけが利用不可と表示されます。
- Gemini APIキー: `GEMINI_API_KEY`または`GOOGLE_API_KEY`を使います。
- Claude APIキー: `ANTHROPIC_API_KEY`を使います。
- カスタム: OpenAI互換Base URL、APIキー、モデルを直接入力します。

保存されたAPIキーは`settings.json`ではなくmacOS Keychainに保存されます。

## ねこツール

「3分のタイマーをセットして」のように、タイマー、リマインダー、テキストのコピー、Webページを開くことを頼めます。モデルが操作を提案すると、ねこが先に確認し、吹き出しをクリックすると実行されます。タイマーとリマインダーはOpenNekoの起動中に動作します。AI設定の **ねこツール** でオフにできます。

## 選択したテキスト

どのアプリでもテキストを選択して **サービス → openNeko: 説明する / 翻訳する / 要約する** を選ぶと（右クリック → サービスでも可）、ねこが現在のAI接続で吹き出しに答えます。送ったテキストだけを使います。インストール直後にメニューが出ない場合は、一度ログアウトして入り直してください。

## 音声入力

チャット欄の🎤ボタンを押している間に話し、離すと止まります。音声はこのMac内だけで認識され（macOSの端末内音声認識）、チャット欄に文字として入るので送信前に直せます。この言語を端末内で認識できないMacでは、サーバーに送らず音声入力はオフのままです。初回はマイクと音声認識の許可を求めます。

## タスクを任せる

チャット吹き出しに `/task やること` と入力してプロジェクトフォルダを選ぶと、ねこがローカルのClaude Code CLIにそのフォルダ内だけで作業を任せます。フォルダ内のファイルの読み取り・編集は許可され、それ以外の操作（シェルコマンド、ネットワーク）は承認リクエストとして戻ってきます。吹き出しをクリックして、このタスクに限り許可または拒否できます。ホーム・ルート・システムフォルダは拒否します。すべての手順は `~/Library/Application Support/openNeko/agent-activity.jsonl` に記録され、`/tasklog` で開けます。`/task stop` で中止します。

## ルーティン

設定 → AI → ルーティンで、平日の朝のブリーフィングや一日の締めなど、決まった時間の仕事をねこに任せられます（OpenNeko起動中に動作）。フォルダなしのルーティンは現在のAI接続で吹き出しに答え、フォルダを選んだルーティンはそのフォルダ内でClaude Codeを読み取り専用で実行します（例：昨日のコミット要約）。それ以外の操作は先に確認します。ルーティンは1日1回だけ実行され、Macのスリープ中に逃したものは2時間以内に復帰すれば実行されます。

## スキル

同梱スキルとユーザースキルは、`SKILL.md`として保存されるプロンプト指示です。スキル内のスクリプトは実行されません。

- 同梱スキル: `App/Resources/skills/builtin/`
- ユーザースキル: `~/.openneko/skills/<id>/SKILL.md`

設定ウィンドウ、メニューバーのスキルメニュー、チャット入力のスラッシュコマンド一覧からスキルを実行できます。

## カスタムスキン

スキン設定画面は2つのカスタムスキン経路をサポートします。

- 猫の写真からリクエストファイルを作成: 写真、メタデータ、現在のmanifest、生成プロンプトを含む`.openneko-skin-request`パッケージを保存します。
- 完成済みの`.openneko-skin`、`.zip`、またはスキンフォルダをインポート

完成済みスキンには`manifest.json`、`openneko-skin.json`、manifestのファイル名と一致する透過PNGフレームが含まれます。インポートされたスキンは次の場所へインストールされます。

```text
~/Library/Application Support/openNeko/skins/<id>/
```

## 状態ブリッジ

OpenNekoはデフォルトで`127.0.0.1:48800`を待ち受けます。

```bash
curl -X POST http://127.0.0.1:48800/state \
  -H 'Content-Type: application/json' \
  -d '{"state":"coding","source":"agent","message":"Building"}'
```

デバッグエンドポイント:

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

別のローカルポートを使う場合:

```bash
OPENNEKO_PORT=48801 /path/to/OpenNeko.app/Contents/MacOS/OpenNeko
```

### エージェント通知

Claude CodeやCodexが作業を終えたときや承認が必要なときに、ねこが知らせます。
設定 > 一般 > エージェント通知からスニペットをコピーしてください。

- Claude Code (`~/.claude/settings.json`): `Notification` フックが `waiting` を、
  `Stop` フックが `done` を送ります。
- Codex (`~/.codex/config.toml` の先頭): `notify` コマンドが `done` を送ります。

ブリッジは `waiting`、`needs_input`、`attention`(ねこが確認を求め、10分間表示)
と `done`、`finished`、`complete`(`success` として表示)も受け付けます。
OpenNekoがこれらのファイルを自動で編集することはありません。

## パッケージ

ローカルリリースチェック:

```bash
scripts/release-preflight.sh local
scripts/release-preflight.sh distribution
scripts/release-preflight.sh notarized
```

ZIPとDMGパッケージを作成:

```bash
scripts/package-macos.sh
```

成果物:

- `dist/OpenNeko-macOS-Release.zip`
- `dist/OpenNeko-macOS-Release.dmg`

パッケージ検証:

```bash
scripts/verify-macos-package.sh
```

`distribution`と`notarized`チェックには、署名マシン上のDeveloper ID Application証明書とApple公証資格情報が必要です。

## Electronからの移行

ネイティブアプリは、以前のElectron `settings.json`を次の場所から読みます。

```text
~/Library/Application Support/openNeko/
```

選択したスキン、AI provider preset/base URL/model、オンボーディング状態、ログイン時起動設定、言語、サウンド、Web検索、ユーザープロフィール、近所設定、peer IDを保持します。

Electron `safeStorage`のAPIキー暗号文はインポートされません。AI設定画面でAPIキーを再保存すると、macOS Keychainに保存されます。

## ライセンス

OpenNekoはMIT Licenseで公開されています。
