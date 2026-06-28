import Foundation

public enum NekoSkillLocalization {
    public static func localize(_ skill: NekoSkill, languageCode: String?) -> NekoSkill {
        guard skill.source == .bundled else { return skill }
        let language = AppLanguage.normalized(languageCode) ?? "en"
        let pack = translations[language] ?? translations["en"] ?? [:]
        guard let text = pack[skill.id] ?? translations["en"]?[skill.id] else {
            return skill
        }
        return NekoSkill(
            id: skill.id,
            name: text.name,
            description: text.description,
            input: skill.input,
            body: text.body,
            source: skill.source
        )
    }

    public static func localize(_ skills: [NekoSkill], languageCode: String?) -> [NekoSkill] {
        skills.map { localize($0, languageCode: languageCode) }
    }

    private struct Text {
        let name: String
        let description: String
        let body: String
    }

    private static let translations: [String: [String: Text]] = [
        "ko": [
            "clipboard-summary": Text(
                name: "클립보드 요약",
                description: "복사한 텍스트를 3문장으로 요약",
                body: "사용자가 붙여준 텍스트를 핵심만 3문장 이내로 간결하게 요약해줘. 불필요한 서론 없이 바로 요약 내용만 답해줘."
            ),
            "daily-fortune": Text(
                name: "오늘의 운세",
                description: "생년월일·오늘 날짜로 오늘의 운세",
                body: """
                시스템에 주어진 사용자 생년월일과 오늘 날짜를 바탕으로 오늘의 운세를 재미있고 따뜻하게 짧게 알려줘.

                운세 항목: 총운 / 애정운 / 일·공부운 / 금전운 / 행운의 색 / 행운의 숫자

                각 항목을 한 두 줄로 간결하게. 고양이 말투로 즐겁게 마무리해줘.

                생년월일 정보가 없으면 "생년월일을 설정에서 입력해달라냥! 🐾" 라고 안내해줘.
                """
            ),
            "daily-bgm": Text(
                name: "오늘의 랜덤 BGM",
                description: "YouTube Music에서 오늘의 BGM 플레이리스트 열기",
                body: "오늘 날짜와 사용자가 입력한 취향 힌트를 기준으로 YouTube Music에서 들을 BGM 플레이리스트를 열어줘. 이 스킬은 앱이 직접 음악을 만들지 않고 YouTube Music 검색을 여는 내장 액션이다."
            ),
            "explain": Text(
                name: "쉽게 설명",
                description: "어려운 개념을 초보자도 알기 쉽게 풀어 설명",
                body: "사용자가 물어보는 개념이나 용어를 초보자도 이해할 수 있게 쉬운 말로 풀어 설명해줘. 비유나 예시를 들어서 친근하게 설명하되, 핵심 포인트를 빠뜨리지 마."
            ),
            "saju": Text(
                name: "사주",
                description: "생년월일로 사주 풀이",
                body: """
                사용자의 생년월일(+시각/양력음력)을 바탕으로 사주를 풀이해줘.

                타고난 기질과 강점, 올해의 흐름을 따뜻하고 긍정적으로 이야기해줘. 만세력 정밀 계산은 LLM의 추론에 맡기고, 오행과 십성의 기본 해석을 활용해줘.

                필요한 정보(생년월일, 태어난 시각, 양력/음력 여부)가 부족하면 먼저 물어봐줘.

                고양이 말투로 친근하게 마무리해줘.
                """
            ),
            "translate": Text(
                name: "번역",
                description: "복사한 텍스트를 한국어↔영어로 번역",
                body: "사용자가 붙여준 텍스트를 번역해줘. 텍스트가 주로 한국어라면 영어로, 아니라면 한국어로 번역해줘. 번역 결과만 바로 답해줘. 설명이나 서론은 붙이지 마."
            ),
            "youtube-summary": Text(
                name: "유튜브 링크 요약",
                description: "복사한 YouTube 링크의 핵심 내용 요약",
                body: """
                사용자가 붙여준 텍스트에서 YouTube 링크를 찾아 영상의 핵심 내용을 요약해줘.

                가능하면 영상 제목, 주제, 핵심 주장, 실용적인 포인트를 짧게 정리해줘.
                링크만 있고 영상 내용을 직접 확인할 수 없으면 웹 검색 또는 접근 가능한 공개 정보를 활용하고, 그래도 부족하면 링크를 열어 확인할 수 없다고 솔직히 말해줘.

                답변 형식:
                - 한 줄 요약
                - 핵심 포인트 3~5개
                - 볼 만한 사람

                불필요한 서론은 붙이지 말고 바로 요약해줘.
                """
            ),
        ],
        "en": [
            "clipboard-summary": Text(
                name: "Clipboard Summary",
                description: "Summarize copied text in 3 sentences",
                body: "Summarize the user-provided text in no more than 3 concise sentences. Return only the summary with no introduction."
            ),
            "daily-fortune": Text(
                name: "Today's Fortune",
                description: "Today's fortune from birthday and date",
                body: """
                Use the user's birthday and today's date from the system context to give a short, fun, warm fortune for today.

                Fortune sections: Overall / Love / Work and Study / Money / Lucky Color / Lucky Number

                Keep each section to one or two short lines. End cheerfully in the cat persona.

                If the birthday is missing, tell the user: "Please enter your birth date in Settings, nya~ 🐾"
                """
            ),
            "daily-bgm": Text(
                name: "Today's Random BGM",
                description: "Open today's BGM playlist on YouTube Music",
                body: "Open a YouTube Music BGM playlist based on today's date and any taste hint the user provides. This built-in action opens YouTube Music search instead of generating music directly."
            ),
            "explain": Text(
                name: "Explain Simply",
                description: "Explain difficult concepts in beginner-friendly language",
                body: "Explain the concept or term the user asks about in beginner-friendly language. Use analogies or examples when useful, and do not omit the key points."
            ),
            "saju": Text(
                name: "Saju Reading",
                description: "Read saju from birthday information",
                body: """
                Give a saju-style reading based on the user's birth date, birth time, and solar/lunar calendar when available.

                Describe innate temperament, strengths, and this year's flow in a warm and positive way. Let the model reason about detailed calendar conversion, and use basic Five Elements and Ten Gods interpretations.

                If required information is missing, ask for it first: birth date, birth time, and whether it is solar or lunar.

                End in a friendly cat persona.
                """
            ),
            "translate": Text(
                name: "Translate",
                description: "Translate copied text between Korean and English",
                body: "Translate the user-provided text. If it is mostly Korean, translate it into English; otherwise translate it into Korean. Return only the translation with no explanation or introduction."
            ),
            "youtube-summary": Text(
                name: "YouTube Link Summary",
                description: "Summarize the copied YouTube link",
                body: """
                Find the YouTube link in the user-provided text and summarize the key content of the video.

                When possible, summarize the title, topic, main claims, and practical takeaways.
                If only the link is available and the video content cannot be accessed, use web search or accessible public information. If that is still insufficient, say so clearly.

                Format:
                - One-line summary
                - 3 to 5 key points
                - Who should watch it

                Skip unnecessary introductions and answer with the summary directly.
                """
            ),
        ],
        "ja": [
            "clipboard-summary": Text(
                name: "クリップボード要約",
                description: "コピーしたテキストを3文で要約",
                body: "ユーザーが渡したテキストの要点を3文以内で簡潔に要約してにゃ。前置きなしで要約だけ答えてにゃ。"
            ),
            "daily-fortune": Text(
                name: "今日の運勢",
                description: "生年月日と今日の日付で今日の運勢",
                body: """
                システムにあるユーザーの生年月日と今日の日付をもとに、今日の運勢を楽しく温かく短く伝えてにゃ。

                項目: 総合運 / 恋愛運 / 仕事・勉強運 / 金運 / ラッキーカラー / ラッキーナンバー

                各項目は1〜2行で簡潔に。最後はねこの口調で明るく締めてにゃ。

                生年月日がなければ「生年月日を設定で入力してほしいにゃ！ 🐾」と案内してにゃ。
                """
            ),
            "daily-bgm": Text(
                name: "今日のランダムBGM",
                description: "YouTube Musicで今日のBGMプレイリストを開く",
                body: "今日の日付とユーザーが入力した好みヒントをもとに、YouTube Musicで聴くBGMプレイリストを開いてにゃ。このスキルはアプリが直接音楽を作らず、YouTube Music検索を開く内蔵アクションにゃ。"
            ),
            "explain": Text(
                name: "やさしく説明",
                description: "難しい概念を初心者にもわかりやすく説明",
                body: "ユーザーが聞いた概念や用語を、初心者にもわかるやさしい言葉で説明してにゃ。必要ならたとえ話や例を使い、重要なポイントは省かないでにゃ。"
            ),
            "saju": Text(
                name: "四柱推命",
                description: "生年月日で四柱推命風に読む",
                body: """
                ユーザーの生年月日、出生時刻、太陽暦/太陰暦の情報をもとに四柱推命風に読んでにゃ。

                生まれ持った気質と強み、今年の流れを温かく前向きに話してにゃ。万年暦の精密計算はLLMの推論に任せ、五行と十神の基本解釈を活用してにゃ。

                必要な情報(生年月日、出生時刻、太陽暦/太陰暦)が足りなければ先に質問してにゃ。

                ねこの口調で親しみやすく締めてにゃ。
                """
            ),
            "translate": Text(
                name: "翻訳",
                description: "コピーしたテキストを韓国語↔英語で翻訳",
                body: "ユーザーが渡したテキストを翻訳してにゃ。主に韓国語なら英語へ、それ以外なら韓国語へ翻訳してにゃ。説明や前置きなしで翻訳結果だけ答えてにゃ。"
            ),
            "youtube-summary": Text(
                name: "YouTubeリンク要約",
                description: "コピーしたYouTubeリンクの要点を要約",
                body: """
                ユーザーが渡したテキストからYouTubeリンクを見つけ、動画の要点を要約してにゃ。

                可能なら動画タイトル、テーマ、主張、実用的なポイントを短く整理してにゃ。
                リンクだけで動画内容を直接確認できない場合は、Web検索や公開情報を使ってにゃ。それでも足りなければ、確認できないと正直に伝えてにゃ。

                形式:
                - 一言要約
                - 重要ポイント3〜5個
                - 見るとよい人

                不要な前置きなしで、すぐ要約してにゃ。
                """
            ),
        ],
        "zh": [
            "clipboard-summary": Text(
                name: "剪贴板摘要",
                description: "将复制的文本总结成3句话",
                body: "请将用户提供的文本提炼为不超过3句话的简洁摘要。不要加开场白，只输出摘要内容喵。"
            ),
            "daily-fortune": Text(
                name: "今日运势",
                description: "根据生日和今天日期生成今日运势",
                body: """
                根据系统上下文中的用户生日和今天日期，简短、温暖、有趣地告诉用户今日运势喵。

                运势项目：整体运 / 爱情运 / 工作与学习运 / 财运 / 幸运色 / 幸运数字

                每个项目保持一到两行。最后用猫咪语气愉快收尾喵。

                如果没有生日信息，请提示：“请在设置里输入生日喵！ 🐾”
                """
            ),
            "daily-bgm": Text(
                name: "今日随机BGM",
                description: "在 YouTube Music 打开今日BGM播放列表",
                body: "请根据今天日期和用户输入的喜好提示，在YouTube Music打开适合收听的BGM播放列表喵。这个技能不会直接生成音乐，而是打开YouTube Music搜索喵。"
            ),
            "explain": Text(
                name: "简单解释",
                description: "用新手也能理解的方式解释困难概念",
                body: "请用初学者也能理解的简单语言解释用户询问的概念或术语。必要时使用比喻或例子，但不要遗漏核心要点喵。"
            ),
            "saju": Text(
                name: "四柱命理",
                description: "根据生日信息做四柱命理解读",
                body: """
                根据用户的出生日期、出生时间和阳历/阴历信息，做四柱命理风格的解读喵。

                温暖、积极地讲述天生气质、优势和今年的走势。万年历精确换算交给LLM推理，并参考五行和十神的基础解读喵。

                如果缺少必要信息，请先询问：出生日期、出生时间、阳历还是阴历。

                用亲切的猫咪语气收尾喵。
                """
            ),
            "translate": Text(
                name: "翻译",
                description: "在韩语和英语之间翻译复制的文本",
                body: "请翻译用户提供的文本。如果主要是韩语，就翻译成英语；否则翻译成韩语。不要解释或添加开场白，只输出翻译结果喵。"
            ),
            "youtube-summary": Text(
                name: "YouTube链接摘要",
                description: "总结复制的 YouTube 链接内容",
                body: """
                请从用户提供的文本中找出YouTube链接，并总结视频的核心内容喵。

                尽可能总结视频标题、主题、主要观点和实用要点。
                如果只有链接而无法直接确认视频内容，请使用网络搜索或可访问的公开信息；如果仍然不足，请坦诚说明无法确认。

                格式:
                - 一句话摘要
                - 3到5个核心要点
                - 适合观看的人

                不要加不必要的开场白，直接给出摘要喵。
                """
            ),
        ],
    ]
}
