namespace OpenNeko.Core;

/// <summary>Speech bubble copy (en/ko/ja/zh). Mirrors NekoBubbleCopy.swift; strings kept identical.</summary>
public static class NekoBubbleCopy
{
    private static string L(string? lang, string ko, string en, string ja, string zh) => AppLanguage.Pick(lang, ko, en, ja, zh);

    public static string Stretch(string? lang) => L(lang, "스트레칭 시간이다냥! 기지개 쭉 펴라냥", "Stretch time, nya! Loosen up a little.", "ストレッチ時間にゃ! ぐーっと伸びるにゃ", "伸展时间喵! 起来舒展一下喵");
    public static string Lunch(string? lang) => L(lang, "점심 시간이다냥! 맛있는 거 먹고 오라냥", "Lunch time, nya! Go eat something nice.", "ランチ時間にゃ! おいしいもの食べてくるにゃ", "午餐时间喵! 去吃点好吃的喵");
    public static string LeaveWork(string? lang) => L(lang, "오늘 할 만큼 했다냥. 이제 쉬러 가라냥", "You did enough today, nya. Time to rest.", "今日は十分がんばったにゃ。休むにゃ", "今天已经很努力了喵。去休息吧喵");
    public static string SetupReady(string? lang) => L(lang, "준비 끝이다냥! 잘 부탁한다냥", "Ready, nya! Let's work together.", "準備できたにゃ! よろしくにゃ", "准备好了喵! 请多关照喵");
    public static string AgentWorking(string label, string? lang) => L(lang, $"{label} 작업 중이다냥", $"{label} is working, nya~", $"{label} が作業中にゃ", $"{label} 正在工作喵");
    public static string SkillMissing(string? lang) => L(lang, "그 스킬은 못 찾았다냥", "I could not find that skill, nya.", "そのスキルは見つからないにゃ", "找不到那个技能喵");
    public static string SkillDisabled(string? lang) => L(lang, "꺼진 스킬이다냥", "That skill is disabled, nya.", "そのスキルはオフにゃ", "那个技能已关闭喵");
    public static string ClipboardEmpty(string? lang) => L(lang, "클립보드가 비어 있다냥", "The clipboard is empty, nya.", "クリップボードが空にゃ", "剪贴板是空的喵");
    public static string SkillActivated(string name, string? lang) => L(lang, $"{name} 모드다냥", $"{name} mode is on, nya~", $"{name} モードにしたにゃ", $"{name} 模式已开启喵");
    public static string SkillPlaceholder(string name, string? lang) => L(lang, $"{name}로 물어보라냥...", $"Ask with {name}, nya...", $"{name} で聞くにゃ...", $"用 {name} 问我喵...");
    public static string ChatPlaceholder(string? lang) => L(lang, "무엇을 물어볼까냥?", "What shall I ask, nya?", "何を聞くにゃ?", "想问什么喵?");
    public static string BgmSearching(string? lang) => L(lang, "오늘의 BGM 찾는 중이다냥", "Finding today's BGM, nya~", "今日のBGMを探してるにゃ", "正在找今天的BGM喵");
    public static string BgmOpened(string title, string query, string? lang) => L(lang, $"오늘의 BGM을 열었다냥:\n{title}\n{query}", $"Opened today's BGM, nya:\n{title}\n{query}", $"今日のBGMを開いたにゃ:\n{title}\n{query}", $"已打开今天的BGM喵:\n{title}\n{query}");
    public static string BgmOpenFailed(string? lang) => L(lang, "YouTube Music을 열지 못했다냥", "I could not open YouTube Music, nya.", "YouTube Musicを開けなかったにゃ", "没能打开 YouTube Music 喵");

    public static string SlashHelp(string suffix, string? lang) =>
        L(lang, "사용 가능한 명령이다냥:", "Available commands, nya:", "使えるコマンドにゃ:", "可用命令喵:") + "\n/help /reset /skin /lang /sound" + suffix;

    public static string ChatReset(string? lang) => L(lang, "대화를 초기화했다냥", "Chat reset, nya.", "会話をリセットしたにゃ", "对话已重置喵");
    public static string SkinList(string ids, string? lang) => L(lang, $"스킨 목록이다냥: {ids}", $"Skins, nya: {ids}", $"スキンにゃ: {ids}", $"皮肤喵: {ids}");
    public static string SkinMissing(string? lang) => L(lang, "그 스킨은 못 찾았다냥", "I could not find that skin, nya.", "そのスキンは見つからないにゃ", "找不到那个皮肤喵");
    public static string SkinChanged(string label, string? lang) => L(lang, $"스킨을 {label}(으)로 바꿨다냥", $"Skin changed to {label}, nya!", $"スキンを {label} にしたにゃ", $"皮肤已切换为 {label} 喵");
    public static string CurrentLanguage(string name, string? lang) => L(lang, $"지금은 {name}로 말한다냥", $"Current language is {name}, nya.", $"今の言語は {name} にゃ", $"当前语言是 {name} 喵");
    public static string SystemLanguage(string? lang) => L(lang, "시스템 언어를 따라간다냥", "Following the system language, nya.", "システム言語に合わせるにゃ", "跟随系统语言喵");
    public static string SupportedLanguages(string? lang) => L(lang, "지원 언어는 ko, en, ja, zh 다냥", "Supported languages are ko, en, ja, zh, nya.", "対応言語は ko, en, ja, zh にゃ", "支持语言是 ko, en, ja, zh 喵");
    public static string SoundUsage(string? lang) => L(lang, "사용법은 /sound on 또는 /sound off 다냥", "Use /sound on or /sound off, nya.", "/sound on か /sound off を使うにゃ", "请用 /sound on 或 /sound off 喵");

    public static string SoundEnabled(bool enabled, string? lang) => enabled
        ? L(lang, "효과음 켰다냥", "Sound effects on, nya.", "効果音オンにゃ", "音效已开启喵")
        : L(lang, "효과음 껐다냥", "Sound effects off, nya.", "効果音オフにゃ", "音效已关闭喵");

    public static string UnknownCommand(string? lang) => L(lang, "모르는 명령이다냥... /help 를 쳐보라냥", "Unknown command, nya... Try /help.", "知らないコマンドにゃ... /help を試すにゃ", "未知命令喵... 试试 /help 喵");

    public static string Thinking(string? skillName, string? lang)
    {
        if (skillName is not null)
            return L(lang, $"{skillName} 생각 중이다냥", $"{skillName} is thinking, nya~", $"{skillName} で考え中にゃ", $"{skillName} 正在思考喵");
        return StateBubbleText.Text(new StateBridgeEvent(CatState.Thinking, "openNeko", null), lang)
            ?? L(lang, "생각 중이다냥", "Thinking, nya~", "考え中にゃ", "思考中喵");
    }

    public static string SkillRunning(string name, string? lang) => L(lang, $"{name} 실행 중이다냥", $"Running {name}, nya~", $"{name} 実行中にゃ", $"正在运行 {name} 喵");
    public static string GenericChatError(string? lang) => L(lang, "지금은 대답을 만들지 못했다냥...", "I cannot answer right now, nya...", "今は返事を作れないにゃ...", "现在没法生成回答喵...");
    public static string ReplyCopied(string? lang) => L(lang, "답변을 복사했다냥", "Reply copied, nya.", "返事をコピーしたにゃ", "回答已复制喵");
    public static string CopyReplyHelp(string? lang) => L(lang, "답변 복사", "Copy reply", "返事をコピー", "复制回答");

    public static string StyledChatReply(string reply, string? lang)
    {
        var trimmed = reply.Trim();
        if (trimmed.Length == 0) return trimmed;
        return (AppLanguage.Normalized(lang) ?? "ko") switch
        {
            "en" => AppendCatSuffixIfNeeded(trimmed, new[] { "nya" }, ", nya~"),
            "ja" => AppendCatSuffixIfNeeded(trimmed, new[] { "にゃ" }, "にゃ"),
            "zh" => AppendCatSuffixIfNeeded(trimmed, new[] { "喵" }, "喵"),
            _ => AppendCatSuffixIfNeeded(trimmed, new[] { "냥" }, "냥"),
        };
    }

    private static string AppendCatSuffixIfNeeded(string text, string[] markers, string suffix)
    {
        var lower = text.ToLowerInvariant();
        if (markers.Any(m => lower.Contains(m.ToLowerInvariant(), StringComparison.Ordinal))) return text;

        const string terminalPunctuation = ".!?…。！？~";
        var body = text;
        var punctuation = "";
        while (body.Length > 0 && terminalPunctuation.Contains(body[^1]))
        {
            punctuation = body[^1] + punctuation;
            body = body[..^1];
        }
        var trimmedBody = body.Trim();
        return trimmedBody.Length == 0 ? text : trimmedBody + suffix + punctuation;
    }
}
