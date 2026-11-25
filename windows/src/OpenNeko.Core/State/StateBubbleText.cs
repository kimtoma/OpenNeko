namespace OpenNeko.Core;

/// <summary>Mirrors StateBubbleText.swift.</summary>
public static class StateBubbleText
{
    public const int MaxDisplayLength = 48;

    public static string WakeText(string? languageCode = null) =>
        AppLanguage.Pick(languageCode, "...깼다냥!", "...I'm awake, nya!", "...起きたにゃ!", "...我醒了喵!");

    public static string? Text(StateBridgeEvent evt, string? languageCode = null)
    {
        if (!string.IsNullOrEmpty(evt.Message)) return TextUtil.Prefix(evt.Message, MaxDisplayLength);
        string P(string ko, string en, string ja, string zh) => AppLanguage.Pick(languageCode, ko, en, ja, zh);
        return evt.State switch
        {
            CatState.Coding => P("코딩 중이다냥", "Coding, nya~", "コーディング中にゃ", "编码中喵"),
            CatState.Thinking => P("생각 중이다냥", "Thinking, nya~", "考え中にゃ", "思考中喵"),
            CatState.Typing => P("타닥타닥 일하는 중이다냥", "Tap tap, working, nya~", "カタカタ作業中にゃ", "噼啪工作中喵"),
            CatState.Success => P("작업 완료다냥!", "Done, nya!", "完了にゃ!", "完成喵!"),
            CatState.Error => P("에러가 났다냥...", "Something went wrong, nya...", "問題が起きたにゃ...", "出了点问题喵..."),
            CatState.Lunch => P("점심 시간이다냥!", "Lunch time, nya!", "ランチ時間にゃ!", "午餐时间喵!"),
            CatState.Nap => P("쿨쿨 낮잠 자는 중이다냥", "Taking a tiny nap, nya...", "少し休憩中にゃ...", "短暂休息中喵..."),
            CatState.Walk => P("산책하는 중이다냥", "Taking a stroll, nya~", "お散歩中にゃ", "散步中喵"),
            CatState.Jump => P("폴짝 뛰었다냥!", "Hop, nya!", "ぴょんにゃ!", "跳一下喵!"),
            CatState.Yawn => P("하품 나온다냥...", "Yaaawn, nya...", "ふわぁ、にゃ...", "哈欠喵..."),
            _ => null,
        };
    }
}

/// <summary>Unicode-safe string helpers matching Swift's grapheme-based prefix/suffix.</summary>
public static class TextUtil
{
    public static string Prefix(string value, int count)
    {
        var info = new System.Globalization.StringInfo(value);
        return info.LengthInTextElements <= count ? value : info.SubstringByTextElements(0, count);
    }

    public static string Suffix(string value, int count)
    {
        var info = new System.Globalization.StringInfo(value);
        var length = info.LengthInTextElements;
        return length <= count ? value : info.SubstringByTextElements(length - count, count);
    }
}
