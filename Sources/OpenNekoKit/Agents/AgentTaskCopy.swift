import Foundation

public enum AgentTaskCopyKey: String, CaseIterable, Sendable {
    case slashDescription
    case usage
    case pickFolderMessage
    case pickFolderButton
    case started
    case busy
    case claudeMissing
    case approvalBubble
    case approvalTitle
    case approvalMessage
    case irreversibleWarning
    case approve
    case deny
    case approved
    case denied
    case finished
    case failed
    case logDescription
}

/// Copy for `/task` delegation (en/ko/ja/zh). Bubble lines stay short.
public enum AgentTaskCopy {
    public static func text(_ key: AgentTaskCopyKey, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch key {
        case .slashDescription:
            return localized(l, ko: "폴더 안 작업을 Claude Code에 맡기기", en: "Hand a folder task to Claude Code", ja: "フォルダ内の作業をClaude Codeに任せる", zh: "把文件夹内的任务交给 Claude Code")
        case .usage:
            return localized(l, ko: "/task 할 일 — 폴더를 고르면 그 안에서만 작업한다냥", en: "/task what to do — pick a folder and I work only there, nya", ja: "/task やること — 選んだフォルダの中だけで作業するにゃ", zh: "/task 要做的事 — 选个文件夹，只在里面干活喵")
        case .pickFolderMessage:
            return localized(l, ko: "Claude Code가 작업할 폴더를 고르세요. 이 폴더 밖은 건드리지 않아요.", en: "Choose the folder Claude Code may work in. Nothing outside it is touched.", ja: "Claude Codeが作業するフォルダを選んでください。外側には触れません。", zh: "选择 Claude Code 可以工作的文件夹。不会碰文件夹以外的内容。")
        case .pickFolderButton:
            return localized(l, ko: "이 폴더에서 작업", en: "Work here", ja: "このフォルダで作業", zh: "在此处工作")
        case .started:
            return localized(l, ko: "작업 시작! 끝나면 알려준다냥", en: "On it! I'll tell you when it's done, nya", ja: "作業開始！終わったら知らせるにゃ", zh: "开始干活！做完告诉你喵")
        case .busy:
            return localized(l, ko: "이미 다른 작업 중이다냥", en: "Already on another task, nya", ja: "もう別の作業中にゃ", zh: "已经在做别的任务了喵")
        case .claudeMissing:
            return localized(l, ko: "Claude Code(claude)가 설치돼 있어야 한다냥", en: "Claude Code (claude) needs to be installed, nya", ja: "Claude Code(claude)のインストールが必要にゃ", zh: "需要先安装 Claude Code (claude) 喵")
        case .approvalBubble:
            return localized(l, ko: "허락이 필요하다냥! 눌러서 확인해줘", en: "Need your OK, nya! Click to review", ja: "許可がほしいにゃ！クリックで確認", zh: "需要你批准喵！点一下查看")
        case .approvalTitle:
            return localized(l, ko: "Claude Code가 허락을 구해요", en: "Claude Code is asking permission", ja: "Claude Codeが許可を求めています", zh: "Claude Code 请求许可")
        case .approvalMessage:
            return localized(l, ko: "이번 작업에서만 아래 동작을 허락할까요?", en: "Allow these actions for this task only?", ja: "この作業に限り、次の操作を許可しますか？", zh: "仅在本次任务中允许以下操作吗？")
        case .irreversibleWarning:
            return localized(l, ko: "⚠️ 되돌리기 어려운 동작(삭제·전송·외부 접속)이 포함돼 있어요.", en: "⚠️ Includes actions that are hard to undo (delete, send, network).", ja: "⚠️ 元に戻しにくい操作（削除・送信・外部接続）を含みます。", zh: "⚠️ 包含难以撤销的操作（删除、发送、联网）。")
        case .approve:
            return localized(l, ko: "허락", en: "Allow", ja: "許可", zh: "允许")
        case .deny:
            return localized(l, ko: "거절", en: "Deny", ja: "拒否", zh: "拒绝")
        case .approved:
            return localized(l, ko: "허락받았다냥, 이어서 할게", en: "Got it, continuing, nya", ja: "許可もらったにゃ、続けるにゃ", zh: "收到批准，继续喵")
        case .denied:
            return localized(l, ko: "알겠다냥, 여기서 멈출게", en: "Okay, stopping here, nya", ja: "わかったにゃ、ここで止めるにゃ", zh: "好的，就停在这里喵")
        case .finished:
            return localized(l, ko: "작업 끝! ", en: "Done! ", ja: "完了！", zh: "完成！")
        case .failed:
            return localized(l, ko: "작업이 실패했다냥: ", en: "Task failed, nya: ", ja: "作業が失敗したにゃ: ", zh: "任务失败了喵: ")
        case .logDescription:
            return localized(l, ko: "에이전트 활동 기록 열기", en: "Open agent activity log", ja: "エージェント活動ログを開く", zh: "打开智能体活动日志")
        }
    }

    public static func folderRejected(_ reason: AgentTaskFolderRejection, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch reason {
        case .notAbsolute, .filesystemRoot, .systemLocation:
            return localized(l, ko: "그 폴더는 안 된다냥. 프로젝트 폴더를 골라줘", en: "Not that folder, nya. Pick a project folder.", ja: "そのフォルダはダメにゃ。プロジェクトフォルダを選んでにゃ", zh: "那个文件夹不行喵，选个项目文件夹吧")
        case .homeDirectory:
            return localized(l, ko: "홈 폴더 전체는 안 된다냥. 하위 폴더를 골라줘", en: "Not your whole home folder, nya. Pick a subfolder.", ja: "ホーム全体はダメにゃ。サブフォルダを選んでにゃ", zh: "不能用整个主目录喵，选个子文件夹吧")
        }
    }

    /// Short result line for the bubble: prefix + first part of the summary.
    public static func resultBubble(_ phase: AgentTaskPhase, languageCode: String?, limit: Int = 90) -> String? {
        switch phase {
        case let .finished(summary):
            return text(.finished, languageCode: languageCode) + clipped(summary, limit: limit)
        case let .failed(message):
            return text(.failed, languageCode: languageCode) + clipped(message, limit: limit)
        case .denied:
            return text(.denied, languageCode: languageCode)
        case .awaitingApproval:
            return text(.approvalBubble, languageCode: languageCode)
        case .running:
            return nil
        }
    }

    static func clipped(_ text: String, limit: Int) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard oneLine.count > limit else { return oneLine }
        return String(oneLine.prefix(limit)) + "…"
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
