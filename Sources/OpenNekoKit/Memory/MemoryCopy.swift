import Foundation

/// Copy for memory bubbles and the Memory Notes window (en/ko/ja/zh).
public enum MemoryCopy {
    public enum Key: CaseIterable, Sendable {
        case menuTitle
        case windowTitle
        case enabledToggle
        case enabledHelp
        case cloudScopeLabel
        case cloudScopeHelp
        case save
        case revert
        case openInFinder
        case openButton
        case saved
        case remembered
        case undone
        case cloudAllowed
    }

    public static func text(_ key: Key, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch key {
        case .menuTitle:
            return localized(l, ko: "기억 노트", en: "Memory Notes", ja: "記憶ノート", zh: "记忆笔记")
        case .windowTitle:
            return localized(l, ko: "기억 노트", en: "Memory Notes", ja: "記憶ノート", zh: "记忆笔记")
        case .enabledToggle:
            return localized(l, ko: "고양이가 기억하기", en: "Let the cat remember", ja: "ねこに覚えてもらう", zh: "让猫咪记住")
        case .enabledHelp:
            return localized(l, ko: "대화에서 기억할 만한 걸 제안하고, 지난 대화를 찾아 참고해요. 모두 이 Mac의 파일에만 저장돼요.", en: "The cat suggests things worth keeping and looks up past chats. Everything stays in files on this Mac.", ja: "会話から覚えておくことを提案し、過去の会話を参考にするにゃ。すべてこのMacのファイルにだけ保存されるにゃ。", zh: "猫咪会提议值得记住的事，并参考过去的对话。所有内容只保存在这台 Mac 的文件里。")
        case .cloudScopeLabel:
            return localized(l, ko: "클라우드 AI에 보낼 기억", en: "Memory sent to cloud AI", ja: "クラウドAIに送る記憶", zh: "发送给云端 AI 的记忆")
        case .cloudScopeHelp:
            return localized(l, ko: "로컬 모델(Ollama, Apple)은 항상 전부 써요.", en: "Local models (Ollama, Apple) always use all of it.", ja: "ローカルモデル(Ollama、Apple)は常にすべて使うにゃ。", zh: "本地模型（Ollama、Apple）始终使用全部。")
        case .save:
            return localized(l, ko: "저장", en: "Save", ja: "保存", zh: "保存")
        case .revert:
            return localized(l, ko: "되돌리기", en: "Revert", ja: "元に戻す", zh: "还原")
        case .openInFinder:
            return localized(l, ko: "Finder에서 열기", en: "Show in Finder", ja: "Finderで表示", zh: "在访达中显示")
        case .openButton:
            return localized(l, ko: "열기", en: "Open", ja: "開く", zh: "打开")
        case .saved:
            return localized(l, ko: "저장했어요", en: "Saved", ja: "保存したにゃ", zh: "已保存")
        case .remembered:
            return localized(l, ko: "기억해둘게냥 📝", en: "I'll remember that, nya 📝", ja: "覚えておくにゃ 📝", zh: "我记住了喵 📝")
        case .undone:
            return localized(l, ko: "지웠다냥", en: "Forgot it, nya", ja: "消したにゃ", zh: "删掉了喵")
        case .cloudAllowed:
            return localized(l, ko: "이제 기억도 같이 보낼게냥", en: "I'll bring my memory along now, nya", ja: "これから記憶も一緒に送るにゃ", zh: "以后会带上记忆喵")
        }
    }

    public static func tabTitle(_ file: MemoryFile, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch file {
        case .soul: return localized(l, ko: "성격", en: "Soul", ja: "性格", zh: "性格")
        case .user: return localized(l, ko: "나에 대해", en: "About me", ja: "わたしについて", zh: "关于我")
        case .memory: return localized(l, ko: "요즘", en: "Lately", ja: "最近", zh: "最近")
        }
    }

    public static func tabHelp(_ file: MemoryFile, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch file {
        case .soul:
            return localized(l, ko: "고양이의 성격과 말투. 나만 고칠 수 있고, 비워두면 기본 성격을 써요.", en: "The cat's personality and voice. Only you edit it; leave it empty for the default.", ja: "ねこの性格と話し方。編集できるのはあなただけ。空なら標準の性格にゃ。", zh: "猫咪的性格和语气。只有你能修改；留空则使用默认性格。")
        case .user:
            return localized(l, ko: "나에 대한 사실. 고양이가 \"기억해도 돼?\" 하고 물은 뒤 내가 누르면 한 줄씩 늘어요.", en: "Facts about you. A line is added only after the cat asks and you click.", ja: "あなたについての事実。ねこが聞いて、あなたがクリックしたときだけ1行増えるにゃ。", zh: "关于你的事实。猫咪询问、你点击后才会新增一行。")
        case .memory:
            return localized(l, ko: "요즘 맥락. 고양이가 알아서 적고, 길어지면 오래된 줄은 archive 폴더로 옮겨요.", en: "Recent context. The cat writes it; old lines move to the archive folder when it grows.", ja: "最近の文脈。ねこが書き、長くなると古い行はarchiveフォルダへ移すにゃ。", zh: "最近的情况。猫咪自动记录，变长后旧的行会移到 archive 文件夹。")
        }
    }

    public static func scopeTitle(_ scope: MemoryCloudScope, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch scope {
        case .ask, .soulOnly:
            return localized(l, ko: "성격만", en: "Soul only", ja: "性格だけ", zh: "仅性格")
        case .all:
            return localized(l, ko: "전부", en: "Everything", ja: "すべて", zh: "全部")
        case .none:
            return localized(l, ko: "보내지 않기", en: "Nothing", ja: "送らない", zh: "不发送")
        }
    }

    /// Bubble asking to keep a lasting fact. Clicking it saves the line.
    public static func askToRemember(_ entry: String, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        let short = entry.count > 60 ? String(entry.prefix(60)) + "…" : entry
        return localized(l, ko: "📝 \"\(short)\" 기억해도 될까냥? 눌러서 허락", en: "📝 Remember \"\(short)\"? Click to allow", ja: "📝「\(short)」を覚えていいにゃ？クリックで許可", zh: "📝 记住“\(short)”吗？点击允许")
    }

    /// Bubble after the cat noted recent context. Clicking it undoes the note.
    public static func noted(_ entry: String, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        let short = entry.count > 60 ? String(entry.prefix(60)) + "…" : entry
        return localized(l, ko: "📝 메모해뒀다냥: \(short) (누르면 취소)", en: "📝 Noted: \(short) (click to undo)", ja: "📝 メモしたにゃ: \(short)(クリックで取り消し)", zh: "📝 记下了：\(short)（点击撤销）")
    }

    /// One-time bubble on the first cloud chat while the scope is undecided.
    public static func cloudAsk(languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        return localized(l, ko: "🧠 이 AI에도 내 기억 노트를 보낼까냥? 누르면 보낼게. 안 누르면 성격만 보내", en: "🧠 Share my memory notes with this AI too? Click to allow; otherwise only the soul is sent", ja: "🧠 このAIにも記憶ノートを送るにゃ？クリックで送るにゃ。押さなければ性格だけにゃ", zh: "🧠 也把记忆笔记发给这个 AI 吗？点击即发送；不点只发送性格")
    }

    /// The first line written to a new memory file.
    public static func fileHeader(_ file: MemoryFile, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch file {
        case .soul: return localized(l, ko: "# 성격", en: "# Soul", ja: "# 性格", zh: "# 性格")
        case .user: return localized(l, ko: "# 나에 대해", en: "# About me", ja: "# わたしについて", zh: "# 关于我")
        case .memory: return localized(l, ko: "# 요즘", en: "# Lately", ja: "# 最近", zh: "# 最近")
        }
    }

    private static func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": return en
        case "ja": return ja
        case "zh": return zh
        default: return ko
        }
    }
}
