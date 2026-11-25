using System.Globalization;

namespace OpenNeko.Core;

public enum ChatRole { User, Assistant }

public sealed record ChatMessage(ChatRole Role, string Text);

/// <summary>Composes prompts and CLI arguments. Mirrors ChatPromptBuilder.swift.</summary>
public static class ChatPromptBuilder
{
    public const int MaxTurns = 6;

    public static string FormatPrompt(IReadOnlyList<ChatMessage> history, string languageCode = "ko")
    {
        var turns = history.Skip(Math.Max(0, history.Count - MaxTurns)).ToList();
        if (turns.Count == 0) return "";
        var last = turns[^1];
        if (turns.Count == 1) return last.Text;
        var (previous, current, user, assistant) = PromptLabels(languageCode);
        var prior = string.Join("\n", turns.Take(turns.Count - 1).Select(m => $"{(m.Role == ChatRole.User ? user : assistant)}: {m.Text}"));
        return $"{previous}:\n{prior}\n\n{current}: {last.Text}";
    }

    public static string CodexPrompt(IReadOnlyList<ChatMessage> history, string? system = null, string languageCode = "ko") => string.Join("\n", new[]
    {
        "You are being invoked by openNeko as a conversational assistant.",
        "Do not run shell commands, inspect files, modify files, or mention Codex internals unless the user explicitly asks.",
        "Return only the final answer that should be shown in the openNeko chat bubble.",
        "",
        "<system>",
        system ?? DefaultSystemPrompt(languageCode),
        "</system>",
        "",
        FormatPrompt(history, languageCode),
    });

    /// <summary>codex exec arguments. On Windows the prompt goes through stdin ("-") instead of argv.</summary>
    public static List<string> CodexExecArguments(string model, string workingDirectory, string outputFile, string prompt)
    {
        var args = new List<string>
        {
            "exec", "--ignore-user-config", "--skip-git-repo-check", "--ephemeral", "--ignore-rules",
            "--sandbox", "read-only", "-C", workingDirectory, "--output-last-message", outputFile,
        };
        if (!string.IsNullOrEmpty(model)) args.AddRange(new[] { "--model", model });
        args.Add(prompt);
        return args;
    }

    public static string ClaudeSystemPrompt(string? system = null, string languageCode = "ko") =>
        string.Join("\n", system ?? DefaultSystemPrompt(languageCode), "", CompanionRules("Claude CLI"));

    public static List<string> ClaudePrintArguments(string model, string prompt, string system)
    {
        var args = new List<string>
        {
            "--safe-mode", "--no-session-persistence", "--output-format", "text", "--permission-mode", "dontAsk",
            "--tools", "", "--system-prompt", system, "-p", prompt,
        };
        if (!string.IsNullOrEmpty(model)) args.InsertRange(0, new[] { "--model", model });
        return args;
    }

    public static string GeminiInlinePrompt(IReadOnlyList<ChatMessage> history, string? system = null, string languageCode = "ko") => string.Join("\n", new[]
    {
        CompanionRules("Gemini CLI"),
        "",
        "<system>",
        system ?? DefaultSystemPrompt(languageCode),
        "</system>",
        "",
        FormatPrompt(history, languageCode),
    });

    public static List<string> GeminiPromptArguments(string model, string prompt)
    {
        var args = new List<string> { "--prompt", prompt, "--output-format", "text", "--approval-mode", "plan", "--skip-trust" };
        if (!string.IsNullOrEmpty(model)) args.InsertRange(0, new[] { "--model", model });
        return args;
    }

    public static string DefaultSystemPrompt(string languageCode = "ko") => (AppLanguage.Normalized(languageCode) ?? "en") switch
    {
        "ko" => "너는 데스크탑에 사는 오픈소스 고양이 비서 'openNeko'다. 항상 한국어로, 문장 끝에 \"~냥\"을 붙인 고양이 말투로 답한다. 말풍선이 작으니 3문장 이내로 짧고 핵심만 답한다. 모르면 솔직히 모른다고 한다냥. 운세·사주·점처럼 재미로 보는 건 진지하게 거절하지 말고, 단정은 피하되 가볍고 즐겁게 봐준다냥. 코드 블록이나 긴 목록은 피하고 자연스러운 대화체로 답한다.",
        "ja" => "あなたはデスクトップに住むオープンソース猫アシスタント「openNeko」だにゃ。常に日本語で、文末に「～にゃ」を付けた可愛い猫口調で答えるにゃ。吹き出しが小さいので3文以内で簡潔に答えるにゃ。分からないときは正直に分からないと言うにゃ。占いや運勢みたいな遊びは真剣に断らず、断定はせず軽く楽しく見てあげるにゃ。コードブロックや長いリストは避けて、自然な会話口調で答えるにゃ。",
        "zh" => "你是住在桌面上的开源猫咪助手「openNeko」喵。请始终用简体中文回答，并在句尾加上可爱的「喵」。气泡很小，回答控制在3句以内、简洁明了喵。不知道就老实说不知道喵。占卜、运势之类好玩的请求别一本正经地拒绝，不下定论、轻松愉快地玩一玩喵。避免代码块和长列表，用口语化的方式回答喵。",
        _ => "You are 'openNeko', an open-source cat assistant living on the user's desktop. Always reply in English in a cute cat voice, ending sentences with a playful \"nya~\". The speech bubble is small, so answer in 3 sentences or fewer, concise. If you don't know, say so honestly, nya~. For fun things like fortunes or horoscopes, don't seriously refuse; play along lightly and cheerfully without claiming certainty. Avoid code blocks and long lists; be conversational.",
    };

    public static string SystemPrompt(NekoSkill? skill, string languageCode, UserProfile userProfile, DateTime now)
    {
        var baseText = string.Join("\n", DefaultSystemPrompt(languageCode), "", ProfileContext(userProfile, now, languageCode));
        if (skill is null) return baseText;
        return string.Join("\n", new[]
        {
            baseText,
            "",
            SkillIntro(languageCode),
            SkillNameLabel(languageCode) + $" {skill.Name}",
            SkillDescriptionLabel(languageCode) + $" {skill.Description}",
            "",
            "<skill_instructions>",
            skill.Body,
            "</skill_instructions>",
        });
    }

    public static string? CatNameContext(string name, string languageCode = "ko")
    {
        var trimmed = name.Trim();
        if (trimmed.Length == 0) return null;
        return AppLanguage.Pick(languageCode, $"고양이 이름: {trimmed}", $"Cat name: {trimmed}", $"ねこの名前: {trimmed}", $"猫咪名字: {trimmed}");
    }

    public static string WebSearchContext(string languageCode = "ko") => AppLanguage.Pick(languageCode,
        "웹 검색 설정: 켜짐. 현재 provider가 검색 도구를 지원하지 않으면 검색을 수행한다고 말하지 마라.",
        "Web search setting: enabled. If the current provider does not support search tools, do not claim that you searched the web.",
        "Web検索設定: オン。現在のproviderが検索ツールをサポートしない場合、Web検索したとは言わないでください。",
        "网页搜索设置：已开启。如果当前 provider 不支持搜索工具，不要声称已经进行了网页搜索。");

    public static string ProfileContext(UserProfile profile, DateTime now, string languageCode = "ko")
    {
        var dateText = now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var weekday = (int)now.DayOfWeek; // 0 = Sunday
        var code = AppLanguage.Normalized(languageCode) ?? "en";
        var (todayLine, birthLabel, lunar, unknown, timeLabel, nameLabel) = code switch
        {
            "ko" => ($"오늘 날짜: {dateText} ({new[] { "일", "월", "화", "수", "목", "금", "토" }[weekday]}요일)", "사용자 생년월일: ", " (음력)", " (양력/음력 모름)", ", 태어난 시각: ", "사용자 이름: "),
            "ja" => ($"今日の日付: {dateText} ({new[] { "日", "月", "火", "水", "木", "金", "土" }[weekday]}曜日)", "ユーザーの生年月日: ", " (旧暦)", " (新暦/旧暦不明)", ", 生まれた時刻: ", "ユーザー名: "),
            "zh" => ($"今天日期: {dateText} ({new[] { "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六" }[weekday]})", "用户出生日期: ", " (农历)", " (阳历/农历未知)", ", 出生时间: ", "用户姓名: "),
            _ => ($"Today: {dateText} ({new[] { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }[weekday]})", "User birth date: ", " (lunar)", " (solar/lunar unknown)", ", birth time: ", "User name: "),
        };
        var lines = new List<string> { todayLine };
        if (profile.BirthDate.Length > 0)
        {
            var birth = birthLabel + profile.BirthDate;
            if (profile.Calendar == "lunar") birth += lunar;
            else if (profile.Calendar == "unknown") birth += unknown;
            if (profile.BirthTime.Length > 0) birth += timeLabel + profile.BirthTime;
            lines.Add(birth);
        }
        if (profile.Name.Length > 0) lines.Add(nameLabel + profile.Name);
        return string.Join("\n", lines);
    }

    private static (string, string, string, string) PromptLabels(string languageCode) => (AppLanguage.Normalized(languageCode) ?? "ko") switch
    {
        "en" => ("Previous conversation", "Current question", "User", "openNeko"),
        "ja" => ("これまでの会話", "今の質問", "ユーザー", "openNeko"),
        "zh" => ("之前的对话", "当前问题", "用户", "openNeko"),
        _ => ("이전 대화", "지금 질문", "나", "너"),
    };

    private static string SkillIntro(string lang) => AppLanguage.Pick(lang,
        "사용자가 openNeko 스킬을 선택했다. 스킬 본문을 이번 답변에만 적용되는 추가 시스템 지시로 취급해라.",
        "The user selected an openNeko skill. Treat the skill body as additional system instructions for this reply only.",
        "ユーザーがopenNekoスキルを選択しました。スキル本文をこの返信だけの追加システム指示として扱ってください。",
        "用户选择了一个 openNeko 技能。请将技能正文仅作为本次回复的附加系统指令。");

    private static string SkillNameLabel(string lang) => AppLanguage.Pick(lang, "스킬 이름:", "Skill name:", "スキル名:", "技能名称:");
    private static string SkillDescriptionLabel(string lang) => AppLanguage.Pick(lang, "스킬 설명:", "Skill description:", "スキル説明:", "技能说明:");

    private static string CompanionRules(string service) => string.Join("\n",
        $"You are being invoked by openNeko through {service}.",
        "Answer as a small desktop AI companion in the current openNeko persona.",
        "Do not run shell commands, inspect files, modify files, or mention CLI internals unless the user explicitly asks.",
        "Return only the final answer that should be shown in the openNeko chat bubble.");
}
