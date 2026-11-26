import Foundation

/// en/ko/ja/zh copy for routines (settings row, routines window, bubbles).
public enum RoutineCopy {
    public enum Key: CaseIterable, Sendable {
        case entryTitle
        case entryDetail
        case entryButton
        case windowTitle
        case empty
        case add
        case blank
        case name
        case time
        case prompt
        case folder
        case folderNone
        case chooseFolder
        case clearFolder
        case folderHint
        case runNow
        case delete
        case save
        case close
        case saved
        case limitReached
        case everyday
        case weekdays
        case weekends
        case needsPrompt
        case taskBusy
    }

    public static func text(_ key: Key, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch key {
        case .entryTitle:
            return pick(l, ko: "루틴", en: "Routines", ja: "ルーティン", zh: "例程")
        case .entryDetail:
            return pick(l, ko: "정한 시간에 고양이가 알아서 브리핑하거나 폴더 작업을 돌려요. OpenNeko가 켜져 있을 때 동작해요.", en: "The cat runs a briefing or a folder task at set times while OpenNeko is running.", ja: "決めた時間にねこがブリーフィングやフォルダ作業を実行します。OpenNeko起動中に動作します。", zh: "猫咪会在设定时间自动做简报或运行文件夹任务。OpenNeko 运行时生效。")
        case .entryButton:
            return pick(l, ko: "관리", en: "Manage", ja: "管理", zh: "管理")
        case .windowTitle:
            return pick(l, ko: "루틴", en: "Routines", ja: "ルーティン", zh: "例程")
        case .empty:
            return pick(l, ko: "아직 루틴이 없어요. 아래에서 추가해 보세요.", en: "No routines yet. Add one below.", ja: "まだルーティンがありません。下から追加してください。", zh: "还没有例程。在下方添加一个吧。")
        case .add:
            return pick(l, ko: "추가", en: "Add", ja: "追加", zh: "添加")
        case .blank:
            return pick(l, ko: "빈 루틴", en: "Blank routine", ja: "空のルーティン", zh: "空白例程")
        case .name:
            return pick(l, ko: "이름", en: "Name", ja: "名前", zh: "名称")
        case .time:
            return pick(l, ko: "시간", en: "Time", ja: "時刻", zh: "时间")
        case .prompt:
            return pick(l, ko: "고양이에게 할 말", en: "What to ask", ja: "ねこへのお願い", zh: "要说的话")
        case .folder:
            return pick(l, ko: "폴더", en: "Folder", ja: "フォルダ", zh: "文件夹")
        case .folderNone:
            return pick(l, ko: "없음 (채팅으로 답해요)", en: "None (answers in chat)", ja: "なし（チャットで回答）", zh: "无（在聊天中回答）")
        case .chooseFolder:
            return pick(l, ko: "폴더 선택", en: "Choose Folder", ja: "フォルダを選択", zh: "选择文件夹")
        case .clearFolder:
            return pick(l, ko: "지우기", en: "Clear", ja: "クリア", zh: "清除")
        case .folderHint:
            return pick(l, ko: "폴더를 고르면 Claude Code가 그 폴더에서 읽기 전용으로 실행해요. 그 밖의 동작은 먼저 물어봐요.", en: "With a folder, Claude Code runs read-only inside it. Anything else asks you first.", ja: "フォルダを選ぶとClaude Codeがその中で読み取り専用で動きます。それ以外は先に確認します。", zh: "选了文件夹后，Claude Code 会在其中以只读方式运行。其他操作会先询问你。")
        case .runNow:
            return pick(l, ko: "지금 실행", en: "Run Now", ja: "今すぐ実行", zh: "立即运行")
        case .delete:
            return pick(l, ko: "삭제", en: "Delete", ja: "削除", zh: "删除")
        case .save:
            return pick(l, ko: "저장", en: "Save", ja: "保存", zh: "保存")
        case .close:
            return pick(l, ko: "닫기", en: "Close", ja: "閉じる", zh: "关闭")
        case .saved:
            return pick(l, ko: "저장했어요", en: "Saved", ja: "保存しました", zh: "已保存")
        case .limitReached:
            return pick(l, ko: "루틴은 최대 \(RoutineScheduler.maxRoutines)개까지예요", en: "Up to \(RoutineScheduler.maxRoutines) routines", ja: "ルーティンは最大\(RoutineScheduler.maxRoutines)個です", zh: "最多 \(RoutineScheduler.maxRoutines) 个例程")
        case .everyday:
            return pick(l, ko: "매일", en: "Every day", ja: "毎日", zh: "每天")
        case .weekdays:
            return pick(l, ko: "평일", en: "Weekdays", ja: "平日", zh: "工作日")
        case .weekends:
            return pick(l, ko: "주말", en: "Weekends", ja: "週末", zh: "周末")
        case .needsPrompt:
            return pick(l, ko: "할 말을 적어야 실행돼요", en: "Add what to ask before it can run", ja: "お願いを書くと実行できます", zh: "填写要说的话后才能运行")
        case .taskBusy:
            return pick(l, ko: "다른 작업 중이라 이번 루틴은 건너뛰었다냥", en: "Busy with another task, so I skipped this routine, nya", ja: "別の作業中なのでこのルーティンは飛ばしたにゃ", zh: "正在做别的任务，这次例程跳过了喵")
        }
    }

    public static func days(_ days: RoutineDays, languageCode: String?) -> String {
        switch days {
        case .everyday: text(.everyday, languageCode: languageCode)
        case .weekdays: text(.weekdays, languageCode: languageCode)
        case .weekends: text(.weekends, languageCode: languageCode)
        }
    }

    public static func templateTitle(_ template: RoutineTemplate, languageCode: String?) -> String {
        template.routine(id: "", languageCode: languageCode).title
    }

    /// Bubble shown when a routine starts.
    public static func starting(_ routine: Routine, languageCode: String?) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        let title = routine.title.isEmpty ? text(.entryTitle, languageCode: l) : routine.title
        return pick(l, ko: "⏰ \(title) 시간이다냥", en: "⏰ Time for \(title), nya", ja: "⏰ \(title)の時間にゃ", zh: "⏰ \(title)时间到了喵")
    }

    /// "Next: Fri 08:30"
    public static func nextRun(_ date: Date?, languageCode: String?, calendar: Calendar) -> String {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        guard let date else {
            return pick(l, ko: "꺼짐", en: "Off", ja: "オフ", zh: "已关闭")
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: localeIdentifier(l))
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEEjmm")
        let when = formatter.string(from: date)
        return pick(l, ko: "다음: \(when)", en: "Next: \(when)", ja: "次回: \(when)", zh: "下次：\(when)")
    }

    static func localeIdentifier(_ language: String) -> String {
        switch language {
        case "en": "en_US"
        case "ja": "ja_JP"
        case "zh": "zh_CN"
        default: "ko_KR"
        }
    }

    static func pick(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
