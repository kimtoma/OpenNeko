public enum CatStateMenu {
    public static let previewStates: [CatState] = [
        .thinking,
        .coding,
        .typing,
        .success,
        .error,
        .walk,
        .jump,
        .yawn,
        .lunch,
        .nap,
        .idle,
    ]

    public static func title(for state: CatState, languageCode: String? = nil) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            englishTitle(for: state)
        case "ja":
            japaneseTitle(for: state)
        case "zh":
            chineseTitle(for: state)
        default:
            koreanTitle(for: state)
        }
    }

    public static func catVisibilityTitle(isVisible: Bool, languageCode: String? = nil) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en":
            isVisible ? "Hide Cat" : "Show Cat"
        case "ja":
            isVisible ? "ねこを隠す" : "ねこを表示"
        case "zh":
            isVisible ? "隐藏猫咪" : "显示猫咪"
        default:
            isVisible ? "고양이 숨기기" : "고양이 보이기"
        }
    }

    private static func koreanTitle(for state: CatState) -> String {
        switch state {
        case .idle: "기본 상태"
        case .hover: "관심"
        case .click: "클릭"
        case .coding: "코딩"
        case .typing: "타이핑"
        case .thinking: "생각 중"
        case .lunch: "점심"
        case .yawn: "하품"
        case .nap: "낮잠"
        case .success: "성공"
        case .error: "오류"
        case .dragging: "드래그"
        case .walk: "걷기"
        case .jump: "점프"
        }
    }

    private static func englishTitle(for state: CatState) -> String {
        switch state {
        case .idle: "Normal"
        case .hover: "Curious"
        case .click: "Click"
        case .coding: "Coding"
        case .typing: "Typing"
        case .thinking: "Thinking"
        case .lunch: "Lunch"
        case .yawn: "Yawn"
        case .nap: "Nap"
        case .success: "Success"
        case .error: "Error"
        case .dragging: "Dragging"
        case .walk: "Walk"
        case .jump: "Jump"
        }
    }

    private static func japaneseTitle(for state: CatState) -> String {
        switch state {
        case .idle: "通常"
        case .hover: "注目"
        case .click: "クリック"
        case .coding: "コーディング"
        case .typing: "タイピング"
        case .thinking: "考え中"
        case .lunch: "ランチ"
        case .yawn: "あくび"
        case .nap: "昼寝"
        case .success: "成功"
        case .error: "エラー"
        case .dragging: "ドラッグ"
        case .walk: "歩く"
        case .jump: "ジャンプ"
        }
    }

    private static func chineseTitle(for state: CatState) -> String {
        switch state {
        case .idle: "普通"
        case .hover: "关注"
        case .click: "点击"
        case .coding: "编码"
        case .typing: "输入"
        case .thinking: "思考中"
        case .lunch: "午餐"
        case .yawn: "打哈欠"
        case .nap: "午睡"
        case .success: "成功"
        case .error: "错误"
        case .dragging: "拖动"
        case .walk: "走路"
        case .jump: "跳跃"
        }
    }
}
