import Foundation

/// en/ko/ja/zh copy for MCP connectors.
public enum ConnectorCopy {
    public enum Key: CaseIterable, Sendable {
        case sectionTitle
        case sectionDetail
        case importClaudeDesktop
        case importFile
        case remove
        case empty
        case importConfirmTitle
        case importConfirmDetail
        case importButton
        case cancel
        case nothingFound
        case starting
        case failed
    }

    public static func text(_ key: Key, languageCode: String?) -> String {
        switch key {
        case .sectionTitle:
            pick(languageCode, ko: "커넥터 (MCP)", en: "Connectors (MCP)", ja: "コネクタ (MCP)", zh: "连接器 (MCP)")
        case .sectionDetail:
            pick(languageCode, ko: "다른 앱의 MCP 서버를 가져와 대화에서 쓴다냥. 실행할 때마다 먼저 묻는다냥", en: "Use MCP servers from your other apps in chat. I ask before every call", ja: "他のアプリのMCPサーバーを会話で使うにゃ。呼ぶたびに先に聞くにゃ", zh: "在聊天中使用其他应用的 MCP 服务器。每次调用前都会先问你喵")
        case .importClaudeDesktop:
            pick(languageCode, ko: "Claude 데스크톱에서 가져오기", en: "Import from Claude Desktop", ja: "Claudeデスクトップから読み込む", zh: "从 Claude 桌面版导入")
        case .importFile:
            pick(languageCode, ko: "JSON 파일에서 가져오기…", en: "Import from JSON file…", ja: "JSONファイルから読み込む…", zh: "从 JSON 文件导入…")
        case .remove:
            pick(languageCode, ko: "삭제", en: "Remove", ja: "削除", zh: "移除")
        case .empty:
            pick(languageCode, ko: "아직 커넥터가 없다냥", en: "No connectors yet", ja: "まだコネクタがないにゃ", zh: "还没有连接器喵")
        case .importConfirmTitle:
            pick(languageCode, ko: "이 MCP 서버들을 가져올까요?", en: "Import these MCP servers?", ja: "これらのMCPサーバーを読み込みますか？", zh: "导入这些 MCP 服务器吗？")
        case .importConfirmDetail:
            pick(languageCode, ko: "켜면 아래 명령이 이 맥에서 실행돼요. 원본 설정 파일은 바꾸지 않고, 환경 변수 값은 키체인에 저장해요.", en: "When on, these commands run on this Mac. The source file is not changed; env values go to the Keychain.", ja: "オンにすると以下のコマンドがこのMacで実行されます。元の設定ファイルは変更せず、環境変数の値はキーチェーンに保存します。", zh: "开启后，以下命令会在这台 Mac 上运行。不会修改源配置文件，环境变量的值保存在钥匙串中。")
        case .importButton:
            pick(languageCode, ko: "가져오기", en: "Import", ja: "読み込む", zh: "导入")
        case .cancel:
            pick(languageCode, ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消")
        case .nothingFound:
            pick(languageCode, ko: "가져올 로컬 MCP 서버가 없다냥", en: "No local MCP servers to import", ja: "読み込めるローカルMCPサーバーがないにゃ", zh: "没有可导入的本地 MCP 服务器喵")
        case .starting:
            pick(languageCode, ko: "연결 중", en: "Connecting", ja: "接続中", zh: "连接中")
        case .failed:
            pick(languageCode, ko: "연결 실패", en: "Couldn't connect", ja: "接続失敗", zh: "连接失败")
        }
    }

    public static func toolCount(_ count: Int, languageCode: String?) -> String {
        pick(languageCode, ko: "도구 \(count)개", en: "\(count) tools", ja: "ツール\(count)個", zh: "\(count) 个工具")
    }

    public static func skipped(remote: Int, languageCode: String?) -> String? {
        guard remote > 0 else { return nil }
        return pick(languageCode, ko: "원격(URL) 서버 \(remote)개는 아직 지원하지 않아 건너뛰었어요.", en: "Skipped \(remote) remote (URL) servers, not supported yet.", ja: "リモート(URL)サーバー\(remote)個はまだ未対応のためスキップしました。", zh: "已跳过 \(remote) 个远程 (URL) 服务器，暂不支持。")
    }

    public static func callFailed(server: String, languageCode: String?) -> String {
        pick(languageCode, ko: "\(server) 도구 실행에 실패했다냥", en: "The \(server) tool failed, nya", ja: "\(server)のツールが失敗したにゃ", zh: "\(server) 的工具运行失败喵")
    }

    private static func pick(_ languageCode: String?, ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
