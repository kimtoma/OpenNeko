namespace OpenNeko.Core;

/// <summary>Tray menu and Settings window copy for the Windows shell (en/ko/ja/zh).
/// Strings reuse the macOS wording from MenuBarController / SettingsCopy where they exist.</summary>
public enum WindowsCopyKey
{
    AlwaysOnTop, Sound, ChatHistory, Settings, Quit, Skills, NoSkills, PreviewState, Skin, Language, SystemLanguage,
    OpenChat, General, AIProvider, Profile, TabSkills, CatName, LaunchAtLogin, AgentDetection, WebSearch,
    Provider, BaseUrl, Model, ApiKey, SaveKey, ClearKey, KeySaved, KeyMissing, TestConnection, Testing, ConnectionOk,
    ProfileName, BirthDate, BirthTime, Calendar, Solar, Lunar, Unknown, Save, Close, OpenSkillsFolder, OpenSkinsFolder,
    KeyboardHookFailed, BridgePortBusy, ClearHistory, NoHistory, CliFound, CliMissing, AlreadyRunning,
}

public static class WindowsCopy
{
    public static string Get(WindowsCopyKey key, string? lang) => key switch
    {
        WindowsCopyKey.AlwaysOnTop => AppLanguage.Pick(lang, "항상 위에 표시", "Always on Top", "常に手前に表示", "始终置顶"),
        WindowsCopyKey.Sound => AppLanguage.Pick(lang, "효과음", "Sound Effects", "効果音", "音效"),
        WindowsCopyKey.ChatHistory => AppLanguage.Pick(lang, "대화 내역...", "Chat History...", "会話履歴...", "对话历史..."),
        WindowsCopyKey.Settings => AppLanguage.Pick(lang, "설정...", "Settings...", "設定...", "设置..."),
        WindowsCopyKey.Quit => AppLanguage.Pick(lang, "종료", "Quit", "終了", "退出"),
        WindowsCopyKey.Skills => AppLanguage.Pick(lang, "스킬", "Skills", "スキル", "技能"),
        WindowsCopyKey.NoSkills => AppLanguage.Pick(lang, "활성 스킬 없음", "No Active Skills", "有効なスキルなし", "没有启用的技能"),
        WindowsCopyKey.PreviewState => AppLanguage.Pick(lang, "상태 미리보기", "Preview State", "状態プレビュー", "预览状态"),
        WindowsCopyKey.Skin => AppLanguage.Pick(lang, "스킨", "Skin", "スキン", "皮肤"),
        WindowsCopyKey.Language => AppLanguage.Pick(lang, "언어", "Language", "言語", "语言"),
        WindowsCopyKey.SystemLanguage => AppLanguage.Pick(lang, "시스템 기본", "System Default", "システム標準", "系统默认"),
        WindowsCopyKey.OpenChat => AppLanguage.Pick(lang, "대화하기", "Chat", "話しかける", "聊天"),
        WindowsCopyKey.General => AppLanguage.Pick(lang, "일반", "General", "一般", "通用"),
        WindowsCopyKey.AIProvider => AppLanguage.Pick(lang, "AI 연결", "AI Connection", "AI接続", "AI 连接"),
        WindowsCopyKey.Profile => AppLanguage.Pick(lang, "프로필", "Profile", "プロフィール", "个人资料"),
        WindowsCopyKey.TabSkills => AppLanguage.Pick(lang, "스킬", "Skills", "スキル", "技能"),
        WindowsCopyKey.CatName => AppLanguage.Pick(lang, "고양이 이름", "Cat Name", "ねこの名前", "猫咪名字"),
        WindowsCopyKey.LaunchAtLogin => AppLanguage.Pick(lang, "로그인 시 실행", "Launch at Login", "ログイン時に起動", "登录时启动"),
        WindowsCopyKey.AgentDetection => AppLanguage.Pick(lang, "AI 에이전트 작업 감지", "Detect AI Agent Activity", "AIエージェントの作業を検知", "检测 AI 代理活动"),
        WindowsCopyKey.WebSearch => AppLanguage.Pick(lang, "웹 검색 허용", "Allow Web Search", "Web検索を許可", "允许网页搜索"),
        WindowsCopyKey.Provider => AppLanguage.Pick(lang, "연결 방식", "Provider", "接続方式", "连接方式"),
        WindowsCopyKey.BaseUrl => "Base URL",
        WindowsCopyKey.Model => AppLanguage.Pick(lang, "모델", "Model", "モデル", "模型"),
        WindowsCopyKey.ApiKey => AppLanguage.Pick(lang, "API 키", "API Key", "APIキー", "API Key"),
        WindowsCopyKey.SaveKey => AppLanguage.Pick(lang, "키 저장", "Save Key", "キーを保存", "保存 Key"),
        WindowsCopyKey.ClearKey => AppLanguage.Pick(lang, "키 삭제", "Clear Key", "キーを削除", "删除 Key"),
        WindowsCopyKey.KeySaved => AppLanguage.Pick(lang, "Windows 자격 증명 관리자에 저장됨", "Saved in Windows Credential Manager", "Windows資格情報マネージャーに保存済み", "已保存到 Windows 凭据管理器"),
        WindowsCopyKey.KeyMissing => AppLanguage.Pick(lang, "저장된 키 없음", "No key saved", "保存されたキーなし", "没有已保存的 Key"),
        WindowsCopyKey.TestConnection => AppLanguage.Pick(lang, "연결 테스트", "Test Connection", "接続テスト", "测试连接"),
        WindowsCopyKey.Testing => AppLanguage.Pick(lang, "테스트 중...", "Testing...", "テスト中...", "测试中..."),
        WindowsCopyKey.ConnectionOk => AppLanguage.Pick(lang, "연결 성공", "Connected", "接続成功", "连接成功"),
        WindowsCopyKey.ProfileName => AppLanguage.Pick(lang, "이름", "Name", "名前", "姓名"),
        WindowsCopyKey.BirthDate => AppLanguage.Pick(lang, "생년월일 (YYYY-MM-DD)", "Birth Date (YYYY-MM-DD)", "生年月日 (YYYY-MM-DD)", "出生日期 (YYYY-MM-DD)"),
        WindowsCopyKey.BirthTime => AppLanguage.Pick(lang, "태어난 시각 (HH:MM)", "Birth Time (HH:MM)", "生まれた時刻 (HH:MM)", "出生时间 (HH:MM)"),
        WindowsCopyKey.Calendar => AppLanguage.Pick(lang, "달력", "Calendar", "暦", "历法"),
        WindowsCopyKey.Solar => AppLanguage.Pick(lang, "양력", "Solar", "新暦", "阳历"),
        WindowsCopyKey.Lunar => AppLanguage.Pick(lang, "음력", "Lunar", "旧暦", "农历"),
        WindowsCopyKey.Unknown => AppLanguage.Pick(lang, "모름", "Unknown", "不明", "未知"),
        WindowsCopyKey.Save => AppLanguage.Pick(lang, "저장", "Save", "保存", "保存"),
        WindowsCopyKey.Close => AppLanguage.Pick(lang, "닫기", "Close", "閉じる", "关闭"),
        WindowsCopyKey.OpenSkillsFolder => AppLanguage.Pick(lang, "스킬 폴더 열기", "Open Skills Folder", "スキルフォルダを開く", "打开技能文件夹"),
        WindowsCopyKey.OpenSkinsFolder => AppLanguage.Pick(lang, "스킨 폴더 열기", "Open Skins Folder", "スキンフォルダを開く", "打开皮肤文件夹"),
        WindowsCopyKey.KeyboardHookFailed => AppLanguage.Pick(lang, "타이핑 감지를 시작하지 못했다냥", "Typing detection could not start, nya.", "タイピング検知を開始できないにゃ", "无法启动输入检测喵"),
        WindowsCopyKey.BridgePortBusy => AppLanguage.Pick(lang, "상태 브릿지 포트가 사용 중이다냥", "The state bridge port is busy, nya.", "状態ブリッジのポートが使用中にゃ", "状态桥端口被占用喵"),
        WindowsCopyKey.ClearHistory => AppLanguage.Pick(lang, "내역 지우기", "Clear History", "履歴を消去", "清除历史"),
        WindowsCopyKey.NoHistory => AppLanguage.Pick(lang, "아직 대화가 없다냥", "No chats yet, nya.", "まだ会話がないにゃ", "还没有对话喵"),
        WindowsCopyKey.CliFound => AppLanguage.Pick(lang, "CLI 찾음", "CLI found", "CLIあり", "已找到 CLI"),
        WindowsCopyKey.CliMissing => AppLanguage.Pick(lang, "CLI를 찾지 못함 (PATH 확인)", "CLI not found (check PATH)", "CLIが見つかりません (PATHを確認)", "未找到 CLI（请检查 PATH）"),
        WindowsCopyKey.AlreadyRunning => AppLanguage.Pick(lang, "OpenNeko가 이미 실행 중이다냥", "OpenNeko is already running, nya.", "OpenNekoはもう起動中にゃ", "OpenNeko 已经在运行喵"),
        _ => key.ToString(),
    };
}
