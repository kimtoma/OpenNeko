namespace OpenNeko.Core;

/// <summary>Mirrors CatStateMenu.swift.</summary>
public static class CatStateMenu
{
    public static readonly CatState[] PreviewStates =
    {
        CatState.Thinking, CatState.Coding, CatState.Typing, CatState.Success, CatState.Error,
        CatState.Walk, CatState.Jump, CatState.Yawn, CatState.Lunch, CatState.Nap, CatState.Idle,
    };

    public static string CatVisibilityTitle(bool isVisible, string? lang) => isVisible
        ? AppLanguage.Pick(lang, "고양이 숨기기", "Hide Cat", "ねこを隠す", "隐藏猫咪")
        : AppLanguage.Pick(lang, "고양이 보이기", "Show Cat", "ねこを表示", "显示猫咪");

    public static string Title(CatState state, string? lang) => state switch
    {
        CatState.Idle => AppLanguage.Pick(lang, "기본 상태", "Normal", "通常", "普通"),
        CatState.Hover => AppLanguage.Pick(lang, "관심", "Curious", "注目", "关注"),
        CatState.Click => AppLanguage.Pick(lang, "클릭", "Click", "クリック", "点击"),
        CatState.Coding => AppLanguage.Pick(lang, "코딩", "Coding", "コーディング", "编码"),
        CatState.Typing => AppLanguage.Pick(lang, "타이핑", "Typing", "タイピング", "输入"),
        CatState.Thinking => AppLanguage.Pick(lang, "생각 중", "Thinking", "考え中", "思考中"),
        CatState.Lunch => AppLanguage.Pick(lang, "점심", "Lunch", "ランチ", "午餐"),
        CatState.Yawn => AppLanguage.Pick(lang, "하품", "Yawn", "あくび", "打哈欠"),
        CatState.Nap => AppLanguage.Pick(lang, "낮잠", "Nap", "昼寝", "午睡"),
        CatState.Success => AppLanguage.Pick(lang, "성공", "Success", "成功", "成功"),
        CatState.Error => AppLanguage.Pick(lang, "오류", "Error", "エラー", "错误"),
        CatState.Dragging => AppLanguage.Pick(lang, "드래그", "Dragging", "ドラッグ", "拖动"),
        CatState.Walk => AppLanguage.Pick(lang, "걷기", "Walk", "歩く", "走路"),
        CatState.Jump => AppLanguage.Pick(lang, "점프", "Jump", "ジャンプ", "跳跃"),
        _ => state.RawValue(),
    };
}
