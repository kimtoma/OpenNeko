public enum SettingsCopyKey: String, CaseIterable, Sendable {
    case startSubtitle
    case generalSubtitle
    case neighborsSubtitle
    case profileSubtitle
    case aiSubtitle
    case skillsSubtitle
    case permissionsSubtitle
    case skinsSubtitle
    case bridgeSubtitle
    case aboutSubtitle
    case typing
    case skin
    case skills
    case agent
    case neighbor
    case profile
    case bridge
    case advancedSettings
    case advancedSettingsDetail
    case advancedConnection
    case advancedConnectionDetail
    case advancedSkills
    case advancedSkillsDetail
    case advancedNeighborInfo
    case advancedNeighborInfoDetail
    case aiTest
    case soundEffects
    case soundEffectsOn
    case soundEffectsOff
    case language
    case catName
    case catNamePrompt
    case agentDetection
    case agentDetectionDetail
    case webSearch
    case webSearchOn
    case webSearchOff
    case neighborDiscovery
    case neighborDiscoveryOn
    case neighborDiscoveryOff
    case displayName
    case discoveredNeighbors
    case peerID
    case peerIDPending
    case sendWave
    case promptContext
    case promptContextDetail
    case name
    case birthDate
    case birthTime
    case calendar
    case solar
    case lunar
    case preset
    case detectedProviders
    case detectedProvidersEmpty
    case refreshDetection
    case useProvider
    case currentProvider
    case recommended
    case model
    case autoSelect
    case environmentVariables
    case apiKey
    case saved
    case replaceAPIKey
    case enterAPIKey
    case saveAPIKey
    case deleteAPIKey
    case skillsFolder
    case openFolder
    case aiSettings
    case noSkills
    case noSkillsDetail
    case permissionPrivacyDetail
    case state
    case debug
    case exampleCommand
    case version
    case defaultSkin
    case noProfile
    case setupTypingPermission
    case setupAIConnection
    case setupReady
    case setupTypingPermissionDetail
    case setupReadyDetail
    case permissionSetup
    case onboardingTitle
    case onboardingSubtitle
    case onboardingWelcomeTitle
    case onboardingWelcomeBody
    case onboardingSkinTitle
    case onboardingSkinBody
    case onboardingNameTitle
    case onboardingNameBody
    case onboardingPermissionTitle
    case onboardingPermissionBody
    case onboardingLaunchTitle
    case onboardingLaunchBody
    case onboardingAITitle
    case onboardingAIBody
    case onboardingDoneTitle
    case onboardingDoneBody
    case onboardingFeatureDesktopTitle
    case onboardingFeatureDesktopBody
    case onboardingFeatureChatTitle
    case onboardingFeatureChatBody
    case onboardingFeatureSkillsTitle
    case onboardingFeatureSkillsBody
    case onboardingNekoGuideTitle
    case onboardingNekoGuideBody
    case onboardingStart
    case onboardingNext
    case onboardingBack
    case onboardingSkip
    case onboardingFinish
    case onboardingRestart
    case onboardingClick
    case onboardingDrag
    case onboardingMenu
    case connectionTest
    case connectionTestHelp
    case finishRequiredSettings
    case test
    case user
    case runSkill
    case activateSkill
    case skillDisabled
    case copied
    case copyCommand
    case agentOn
    case agentOff
    case neighborOff
    case neighborSearching
}

public enum SettingsCopy {
    public static func text(_ key: SettingsCopyKey, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch key {
        case .startSubtitle:
            return localized(language, ko: "현재 openNeko 상태", en: "Current openNeko status", ja: "openNekoの現在の状態", zh: "当前 openNeko 状态")
        case .generalSubtitle:
            return localized(language, ko: "앱 실행과 기본 동작", en: "Launch and default behavior", ja: "起動と基本動作", zh: "启动和基本行为")
        case .neighborsSubtitle:
            return localized(language, ko: "같은 로컬 네트워크의 이웃 고양이와 인사", en: "Say hi to neighbor cats on your local network", ja: "同じローカルネットワークの近くのねこに挨拶", zh: "向同一局域网的邻居猫打招呼")
        case .profileSubtitle:
            return localized(language, ko: "사주와 오늘의 운세 답변에 참고할 내 정보", en: "Your details for fortune and daily reading replies", ja: "四柱推命と今日の運勢の返答に使う自分の情報", zh: "用于八字和今日运势回复的个人信息")
        case .aiSubtitle:
            return localized(language, ko: "고양이가 대답할 연결 방식", en: "Connection used for cat replies", ja: "ねこの返答に使う接続", zh: "猫咪回复使用的连接")
        case .skillsSubtitle:
            return localized(language, ko: "자주 쓰는 요청을 고양이에게 바로 맡깁니다", en: "Run frequent requests through the cat", ja: "よく使う依頼をねこに任せます", zh: "把常用请求直接交给猫咪")
        case .permissionsSubtitle:
            return localized(language, ko: "키 내용은 읽지 않고 입력 이벤트만 사용합니다", en: "Uses input events without reading key contents", ja: "キー内容は読まず入力イベントだけ使います", zh: "只使用输入事件，不读取按键内容")
        case .skinsSubtitle:
            return localized(language, ko: "스킨과 소리를 고른다냥", en: "Choose the cat's look and sounds, nya", ja: "見た目と音を選ぶにゃ", zh: "选择猫咪外观和声音喵")
        case .bridgeSubtitle:
            return localized(language, ko: "로컬 도구가 고양이 상태를 바꾸는 HTTP 포트", en: "HTTP port for local tools to update cat state", ja: "ローカルツールが状態を変えるHTTPポート", zh: "本地工具更新猫咪状态的 HTTP 端口")
        case .aboutSubtitle:
            return localized(language, ko: "Native macOS preview", en: "Native macOS preview", ja: "Native macOSプレビュー", zh: "Native macOS 预览")
        case .typing:
            return localized(language, ko: "타이핑", en: "Typing", ja: "入力", zh: "输入")
        case .skin:
            return localized(language, ko: "스킨", en: "Skin", ja: "スキン", zh: "皮肤")
        case .skills:
            return localized(language, ko: "스킬", en: "Skills", ja: "スキル", zh: "技能")
        case .agent:
            return localized(language, ko: "에이전트", en: "Agent", ja: "エージェント", zh: "智能体")
        case .neighbor:
            return localized(language, ko: "이웃 고양이", en: "Neighbor Cats", ja: "近くのねこ", zh: "邻居猫")
        case .profile:
            return localized(language, ko: "내 프로필", en: "My Profile", ja: "自分のプロフィール", zh: "我的资料")
        case .bridge:
            return localized(language, ko: "브리지", en: "Bridge", ja: "ブリッジ", zh: "桥接")
        case .advancedSettings:
            return localized(language, ko: "고급 설정", en: "Advanced Settings", ja: "詳細設定", zh: "高级设置")
        case .advancedSettingsDetail:
            return localized(language, ko: "권한, 에이전트 감지, 로컬 브리지는 필요할 때만 조정합니다.", en: "Adjust permissions, agent detection, and local bridge only when needed.", ja: "権限、エージェント検出、ローカルブリッジは必要なときだけ調整します。", zh: "仅在需要时调整权限、智能体检测和本地桥接。")
        case .advancedConnection:
            return localized(language, ko: "고급 연결", en: "Advanced Connection", ja: "詳細接続", zh: "高级连接")
        case .advancedConnectionDetail:
            return localized(language, ko: "Base URL, 모델, 환경 변수는 직접 provider를 조정할 때 사용합니다.", en: "Use Base URL, model, and environment variables when tuning a provider manually.", ja: "Base URL、モデル、環境変数はプロバイダーを手動調整するときに使います。", zh: "手动调整 provider 时使用 Base URL、模型和环境变量。")
        case .advancedSkills:
            return localized(language, ko: "고급 스킬 관리", en: "Advanced Skill Management", ja: "詳細スキル管理", zh: "高级技能管理")
        case .advancedSkillsDetail:
            return localized(language, ko: "직접 만든 SKILL.md를 추가할 때만 폴더를 엽니다.", en: "Open the folder only when adding custom SKILL.md files.", ja: "自作のSKILL.mdを追加するときだけフォルダを開きます。", zh: "仅在添加自定义 SKILL.md 文件时打开文件夹。")
        case .advancedNeighborInfo:
            return localized(language, ko: "고급 이웃 정보", en: "Advanced Neighbor Info", ja: "近くのねこの詳細情報", zh: "高级邻居信息")
        case .advancedNeighborInfoDetail:
            return localized(language, ko: "문제 해결이 필요할 때만 피어 ID를 확인합니다.", en: "Check the peer ID only when troubleshooting.", ja: "問題解決が必要なときだけピアIDを確認します。", zh: "仅在排查问题时查看 Peer ID。")
        case .aiTest:
            return localized(language, ko: "AI 테스트", en: "Test AI", ja: "AIをテスト", zh: "测试 AI")
        case .soundEffects:
            return localized(language, ko: "효과음", en: "Sound Effects", ja: "効果音", zh: "音效")
        case .soundEffectsOn:
            return localized(language, ko: "클릭, 드래그, 성공/오류 소리를 재생합니다.", en: "Play click, drag, success, and error sounds.", ja: "クリック、ドラッグ、成功/エラー音を再生します。", zh: "播放点击、拖动、成功和错误音效。")
        case .soundEffectsOff:
            return localized(language, ko: "고양이 효과음을 끕니다.", en: "Cat sound effects are off.", ja: "ねこの効果音はオフです。", zh: "猫咪音效已关闭。")
        case .language:
            return localized(language, ko: "언어", en: "Language", ja: "言語", zh: "语言")
        case .catName:
            return localized(language, ko: "고양이 이름", en: "Cat Name", ja: "ねこの名前", zh: "猫咪名字")
        case .catNamePrompt:
            return localized(language, ko: "예: 나비", en: "e.g. Nabi", ja: "例: ナビ", zh: "例如：Nabi")
        case .agentDetection:
            return localized(language, ko: "AI 에이전트 자동 감지", en: "Detect AI Agents", ja: "AIエージェントを自動検出", zh: "自动检测 AI 智能体")
        case .agentDetectionDetail:
            return localized(language, ko: "Cursor, Codex, Claude, Gemini 등이 바쁘면 고양이가 작업 상태로 바뀝니다.", en: "When Cursor, Codex, Claude, or Gemini is busy, the cat switches to work mode.", ja: "Cursor、Codex、Claude、Geminiなどが忙しいとき作業状態に変わります。", zh: "Cursor、Codex、Claude 或 Gemini 忙碌时，猫咪会进入工作状态。")
        case .webSearch:
            return localized(language, ko: "웹 검색", en: "Web Search", ja: "Web検索", zh: "网页搜索")
        case .webSearchOn:
            return localized(language, ko: "검색 지원 provider에 전달할 준비가 되어 있습니다.", en: "Ready to pass search support to compatible providers.", ja: "対応プロバイダーに検索補助を渡せます。", zh: "已准备好传递给支持搜索的 provider。")
        case .webSearchOff:
            return localized(language, ko: "검색 보조 기능을 사용하지 않습니다.", en: "Search assistance is off.", ja: "検索補助は使いません。", zh: "不使用搜索辅助。")
        case .neighborDiscovery:
            return localized(language, ko: "이웃 고양이 찾기", en: "Find Neighbor Cats", ja: "近くのねこを探す", zh: "寻找邻居猫")
        case .neighborDiscoveryOn:
            return localized(language, ko: "Bonjour로 같은 네트워크의 openNeko를 찾습니다.", en: "Find openNeko peers on the same network with Bonjour.", ja: "Bonjourで同じネットワークのopenNekoを探します。", zh: "通过 Bonjour 查找同一网络中的 openNeko。")
        case .neighborDiscoveryOff:
            return localized(language, ko: "로컬 네트워크 검색을 끕니다.", en: "Local network discovery is off.", ja: "ローカルネットワーク検索はオフです。", zh: "本地网络发现已关闭。")
        case .displayName:
            return localized(language, ko: "표시 이름", en: "Display Name", ja: "表示名", zh: "显示名称")
        case .discoveredNeighbors:
            return localized(language, ko: "발견된 이웃 고양이", en: "Discovered Neighbor Cats", ja: "見つかったねこ", zh: "已发现的邻居猫")
        case .peerID:
            return localized(language, ko: "피어 ID", en: "Peer ID", ja: "ピアID", zh: "Peer ID")
        case .peerIDPending:
            return localized(language, ko: "첫 실행 시 자동 생성됩니다.", en: "Generated automatically on first launch.", ja: "初回起動時に自動生成されます。", zh: "首次启动时自动生成。")
        case .sendWave:
            return localized(language, ko: "인사 보내기", en: "Send Wave", ja: "挨拶を送る", zh: "发送问候")
        case .promptContext:
            return localized(language, ko: "사주와 운세 참고 정보", en: "Fortune Context", ja: "運勢の参考情報", zh: "运势参考信息")
        case .promptContextDetail:
            return localized(language, ko: "이름, 생년월일, 태어난 시각을 입력하면 사주와 오늘의 운세를 답할 때 참고합니다.", en: "Name, birth date, and birth time help answer fortune and daily reading questions.", ja: "名前、生年月日、生まれた時刻は四柱推命と今日の運勢の返答に使われます。", zh: "姓名、出生日期和出生时间会用于八字与今日运势回复。")
        case .name:
            return localized(language, ko: "이름", en: "Name", ja: "名前", zh: "姓名")
        case .birthDate:
            return localized(language, ko: "생년월일", en: "Birth Date", ja: "生年月日", zh: "出生日期")
        case .birthTime:
            return localized(language, ko: "태어난 시각", en: "Birth Time", ja: "出生時刻", zh: "出生时间")
        case .calendar:
            return localized(language, ko: "달력", en: "Calendar", ja: "暦", zh: "历法")
        case .solar:
            return localized(language, ko: "양력", en: "Solar", ja: "新暦", zh: "阳历")
        case .lunar:
            return localized(language, ko: "음력", en: "Lunar", ja: "旧暦", zh: "农历")
        case .preset:
            return localized(language, ko: "프리셋", en: "Preset", ja: "プリセット", zh: "预设")
        case .detectedProviders:
            return localized(language, ko: "감지된 연결", en: "Detected Connections", ja: "検出された接続", zh: "已检测连接")
        case .detectedProvidersEmpty:
            return localized(language, ko: "지금 바로 쓸 수 있는 연결을 찾지 못했습니다.", en: "No ready connection was detected.", ja: "すぐ使える接続は見つかりませんでした。", zh: "未检测到可直接使用的连接。")
        case .refreshDetection:
            return localized(language, ko: "다시 감지", en: "Refresh Detection", ja: "再検出", zh: "重新检测")
        case .useProvider:
            return localized(language, ko: "사용", en: "Use", ja: "使用", zh: "使用")
        case .currentProvider:
            return localized(language, ko: "현재 사용 중", en: "Current", ja: "使用中", zh: "当前")
        case .recommended:
            return localized(language, ko: "추천", en: "Recommended", ja: "おすすめ", zh: "推荐")
        case .model:
            return localized(language, ko: "모델", en: "Model", ja: "モデル", zh: "模型")
        case .autoSelect:
            return localized(language, ko: "자동 선택", en: "Auto select", ja: "自動選択", zh: "自动选择")
        case .environmentVariables:
            return localized(language, ko: "환경 변수", en: "Environment Variables", ja: "環境変数", zh: "环境变量")
        case .apiKey:
            return localized(language, ko: "API 키", en: "API Key", ja: "APIキー", zh: "API Key")
        case .saved:
            return localized(language, ko: "저장됨", en: "Saved", ja: "保存済み", zh: "已保存")
        case .replaceAPIKey:
            return localized(language, ko: "새 키로 교체", en: "Replace with new key", ja: "新しいキーに置き換え", zh: "替换为新密钥")
        case .enterAPIKey:
            return localized(language, ko: "API 키 입력", en: "Enter API key", ja: "APIキーを入力", zh: "输入 API Key")
        case .saveAPIKey:
            return localized(language, ko: "API 키 저장", en: "Save API key", ja: "APIキーを保存", zh: "保存 API Key")
        case .deleteAPIKey:
            return localized(language, ko: "API 키 삭제", en: "Delete API key", ja: "APIキーを削除", zh: "删除 API Key")
        case .skillsFolder:
            return localized(language, ko: "스킬 폴더", en: "Skills Folder", ja: "スキルフォルダ", zh: "技能文件夹")
        case .openFolder:
            return localized(language, ko: "폴더 열기", en: "Open Folder", ja: "フォルダを開く", zh: "打开文件夹")
        case .aiSettings:
            return localized(language, ko: "AI 설정", en: "AI Settings", ja: "AI設定", zh: "AI 设置")
        case .noSkills:
            return localized(language, ko: "사용 가능한 스킬 없음", en: "No Skills Available", ja: "利用できるスキルなし", zh: "没有可用技能")
        case .noSkillsDetail:
            return localized(language, ko: "사용자 스킬 폴더에 SKILL.md를 추가하면 여기에 표시됩니다.", en: "Add SKILL.md files to the user skills folder to show them here.", ja: "ユーザースキルフォルダにSKILL.mdを追加すると表示されます。", zh: "向用户技能文件夹添加 SKILL.md 后会显示在这里。")
        case .permissionPrivacyDetail:
            return localized(language, ko: "손쉬운 사용과 입력 모니터링을 허용해도 keyDown 발생 사실만 사용합니다.", en: "Even with Accessibility and Input Monitoring allowed, only the fact that keyDown occurred is used.", ja: "アクセシビリティと入力監視を許可しても、keyDownの発生だけを使います。", zh: "即使允许辅助功能和输入监控，也只使用 keyDown 发生这一事实。")
        case .state:
            return localized(language, ko: "상태", en: "States", ja: "状態", zh: "状态")
        case .debug:
            return localized(language, ko: "디버그", en: "Debug", ja: "デバッグ", zh: "调试")
        case .exampleCommand:
            return localized(language, ko: "예시 명령", en: "Example Command", ja: "コマンド例", zh: "示例命令")
        case .version:
            return localized(language, ko: "버전", en: "Version", ja: "バージョン", zh: "版本")
        case .defaultSkin:
            return localized(language, ko: "white", en: "white", ja: "white", zh: "white")
        case .noProfile:
            return localized(language, ko: "기본 정보 없음", en: "No profile yet", ja: "プロフィール未設定", zh: "尚无资料")
        case .setupTypingPermission:
            return localized(language, ko: "타이핑 권한 필요", en: "Typing Permission Needed", ja: "入力監視の権限が必要", zh: "需要输入权限")
        case .setupAIConnection:
            return localized(language, ko: "AI 연결 필요", en: "AI Connection Needed", ja: "AI接続が必要", zh: "需要 AI 连接")
        case .setupReady:
            return localized(language, ko: "준비됨", en: "Ready", ja: "準備完了", zh: "已就绪")
        case .setupTypingPermissionDetail:
            return localized(language, ko: "두 권한을 허용하면 입력 중 반응합니다.", en: "Allow both permissions so the cat can react while you type.", ja: "2つの権限を許可すると入力中に反応します。", zh: "允许两项权限后猫咪可在输入时做出反应。")
        case .setupReadyDetail:
            return localized(language, ko: "데스크톱에서 바로 사용할 수 있습니다.", en: "Ready to use on your desktop.", ja: "デスクトップですぐ使えます。", zh: "可直接在桌面使用。")
        case .permissionSetup:
            return localized(language, ko: "권한 설정", en: "Set Permission", ja: "権限設定", zh: "设置权限")
        case .onboardingTitle:
            return localized(language, ko: "첫 시작 도우미다냥", en: "First Setup, nya", ja: "初期設定にゃ", zh: "初始设置喵")
        case .onboardingSubtitle:
            return localized(language, ko: "몇 번만 누르면 바로 쓸 수 있다냥", en: "A few clicks and openNeko is ready, nya", ja: "少し選ぶだけですぐ使えるにゃ", zh: "点几下就能开始用喵")
        case .onboardingWelcomeTitle:
            return localized(language, ko: "오픈네꼬로 할 수 있는 일", en: "What openNeko can do", ja: "openNekoでできること", zh: "openNeko 能做什么")
        case .onboardingWelcomeBody:
            return localized(language, ko: "먼저 중요한 기능 3개만 보고, 그다음 필요한 설정을 하나씩 맞춘다냥.", en: "Start with three core features, then set up only what you need, nya.", ja: "まず大事な機能を3つ見てから、必要な設定だけ進めるにゃ。", zh: "先看 3 个核心功能，然后一步步完成必要设置喵。")
        case .onboardingSkinTitle:
            return localized(language, ko: "마음에 드는 털색을 고르자냥", en: "Choose a coat color, nya", ja: "好きな毛色を選ぶにゃ", zh: "选个喜欢的毛色喵")
        case .onboardingSkinBody:
            return localized(language, ko: "움직이는 모습을 보고 제일 귀여운 아이를 누르면 된다냥.", en: "Pick the one that looks best on your desktop, nya.", ja: "動く姿を見て好きな子を選ぶにゃ。", zh: "看看会动的样子，点喜欢的那只喵。")
        case .onboardingNameTitle:
            return localized(language, ko: "이름을 불러주라냥", en: "Name the cat, nya", ja: "名前をつけてにゃ", zh: "给猫咪取名喵")
        case .onboardingNameBody:
            return localized(language, ko: "이 이름으로 말풍선과 이웃 인사에 나타난다냥.", en: "This name appears in bubbles and neighbor greetings, nya.", ja: "この名前が吹き出しと挨拶に出るにゃ。", zh: "这个名字会显示在气泡和问候里喵。")
        case .onboardingPermissionTitle:
            return localized(language, ko: "타이핑 반응을 허락해달라냥", en: "Allow typing reactions, nya", ja: "入力反応を許可してにゃ", zh: "允许输入反应喵")
        case .onboardingPermissionBody:
            return localized(language, ko: "무슨 글자를 치는지는 보지 않고, 키가 눌렸다는 신호만 쓴다냥.", en: "Only key presses are used; typed text is not read, nya.", ja: "入力内容は読まず、キーが押された合図だけ使うにゃ。", zh: "不会读取你打的字，只使用按键发生的信号喵。")
        case .onboardingLaunchTitle:
            return localized(language, ko: "네코 안내와 자동 실행", en: "Neko Guide and Launch at Login", ja: "ねこ案内とログイン時起動", zh: "猫咪提示与登录启动")
        case .onboardingLaunchBody:
            return localized(language, ko: "메뉴바에서 다시 설정할 수 있고, 켜두면 맥을 켤 때 같이 나타난다냥.", en: "Use the menu bar to revisit settings, and launch automatically at login, nya.", ja: "メニューバーから設定を開けて、ログイン時にも起動できるにゃ。", zh: "可从菜单栏重新设置，也能登录时自动启动喵。")
        case .onboardingAITitle:
            return localized(language, ko: "대화할 머리를 연결할까냥", en: "Connect chat, nya?", ja: "会話の接続をするにゃ?", zh: "连接聊天能力喵?")
        case .onboardingAIBody:
            return localized(language, ko: "이미 로그인된 Codex나 준비된 연결이 있으면 내가 찾아준다냥.", en: "I can use a detected login or ready provider, nya.", ja: "ログイン済みや準備済みの接続を探すにゃ。", zh: "会寻找已登录或可用的连接喵。")
        case .onboardingDoneTitle:
            return localized(language, ko: "준비 끝났다냥", en: "Ready, nya", ja: "準備完了にゃ", zh: "准备好了喵")
        case .onboardingDoneBody:
            return localized(language, ko: "이제 고양이를 눌러 대화하고, 메뉴바에서 언제든 다시 고칠 수 있다냥.", en: "Click the cat to chat and change settings anytime, nya.", ja: "ねこをクリックして話して、いつでも設定できるにゃ。", zh: "点击猫咪聊天，也可随时改设置喵。")
        case .onboardingFeatureDesktopTitle:
            return localized(language, ko: "책상 위에서 같이 논다냥", en: "Lives on your desktop", ja: "デスクトップで一緒にいるにゃ", zh: "陪在桌面上喵")
        case .onboardingFeatureDesktopBody:
            return localized(language, ko: "Dock 위를 걷고, 드래그하면 버둥대고, 타이핑하면 반응한다냥.", en: "Walks on the Dock, reacts to typing, and wriggles when dragged, nya.", ja: "Dockの上を歩き、入力やドラッグに反応するにゃ。", zh: "会在 Dock 上走动，也会对输入和拖动反应喵。")
        case .onboardingFeatureChatTitle:
            return localized(language, ko: "고양이와 바로 대화한다냥", en: "Chat with the cat", ja: "ねことすぐ話せるにゃ", zh: "马上和猫咪聊天喵")
        case .onboardingFeatureChatBody:
            return localized(language, ko: "고양이를 누르면 질문할 수 있고, 답변은 클릭해서 복사한다냥.", en: "Click the cat to ask questions, then click replies to copy them, nya.", ja: "ねこをクリックして質問し、返答をクリックしてコピーできるにゃ。", zh: "点击猫咪提问，点击回复即可复制喵。")
        case .onboardingFeatureSkillsTitle:
            return localized(language, ko: "자주 쓰는 일을 맡긴다냥", en: "Run handy skills", ja: "よく使う作業を任せるにゃ", zh: "把常用事情交给它喵")
        case .onboardingFeatureSkillsBody:
            return localized(language, ko: "슬래시 스킬과 메뉴바로 반복 요청을 빠르게 실행한다냥.", en: "Use slash skills and the menu bar for repeated requests, nya.", ja: "スラッシュスキルとメニューバーでよく使う依頼をすぐ実行するにゃ。", zh: "用斜杠技能和菜单栏快速执行常用请求喵。")
        case .onboardingNekoGuideTitle:
            return localized(language, ko: "네코 안내", en: "Neko Guide", ja: "ねこ案内", zh: "猫咪提示")
        case .onboardingNekoGuideBody:
            return localized(language, ko: "처음엔 메뉴바의 openNeko 아이콘만 기억하면 된다냥. 설정은 언제든 다시 열 수 있다냥.", en: "Remember the openNeko menu bar icon. You can reopen settings anytime, nya.", ja: "まずはメニューバーのopenNekoアイコンだけ覚えればいいにゃ。設定はいつでも開けるにゃ。", zh: "先记住菜单栏里的 openNeko 图标，随时都能重新打开设置喵。")
        case .onboardingStart:
            return localized(language, ko: "따라가기 시작냥", en: "Start, nya", ja: "始めるにゃ", zh: "开始喵")
        case .onboardingNext:
            return localized(language, ko: "다음으로 가자냥", en: "Next, nya", ja: "次へにゃ", zh: "下一步喵")
        case .onboardingBack:
            return localized(language, ko: "뒤로냥", en: "Back", ja: "戻るにゃ", zh: "返回喵")
        case .onboardingSkip:
            return localized(language, ko: "나중에 할게냥", en: "Do later, nya", ja: "後でやるにゃ", zh: "以后再做喵")
        case .onboardingFinish:
            return localized(language, ko: "끝났다냥", en: "Finish, nya", ja: "完了にゃ", zh: "完成喵")
        case .onboardingRestart:
            return localized(language, ko: "첫 시작 도우미 다시 열기", en: "Open First Setup Again", ja: "初期設定をもう一度開く", zh: "重新打开初始设置")
        case .onboardingClick:
            return localized(language, ko: "고양이를 누르면 대화한다냥", en: "Click the cat to chat", ja: "ねこをクリックして話すにゃ", zh: "点击猫咪聊天喵")
        case .onboardingDrag:
            return localized(language, ko: "끌어서 자리를 옮긴다냥", en: "Drag to move it", ja: "ドラッグで移動するにゃ", zh: "拖动可移动喵")
        case .onboardingMenu:
            return localized(language, ko: "메뉴바에서 다시 설정한다냥", en: "Change settings from the menu bar", ja: "メニューバーから設定するにゃ", zh: "从菜单栏修改设置喵")
        case .connectionTest:
            return localized(language, ko: "연결 테스트", en: "Connection Test", ja: "接続テスト", zh: "连接测试")
        case .connectionTestHelp:
            return localized(language, ko: "AI 연결 테스트", en: "Test AI connection", ja: "AI接続をテスト", zh: "测试 AI 连接")
        case .finishRequiredSettings:
            return localized(language, ko: "먼저 필요한 설정을 완료하세요", en: "Complete the required settings first", ja: "先に必要な設定を完了してください", zh: "请先完成必要设置")
        case .test:
            return localized(language, ko: "테스트", en: "Test", ja: "テスト", zh: "测试")
        case .user:
            return localized(language, ko: "사용자", en: "User", ja: "ユーザー", zh: "用户")
        case .runSkill:
            return localized(language, ko: "스킬 실행", en: "Run skill", ja: "スキルを実行", zh: "运行技能")
        case .activateSkill:
            return localized(language, ko: "스킬 활성화", en: "Activate skill", ja: "スキルを有効化", zh: "启用技能")
        case .skillDisabled:
            return localized(language, ko: "스킬이 꺼져 있습니다", en: "Skill is disabled", ja: "スキルはオフです", zh: "技能已关闭")
        case .copied:
            return localized(language, ko: "복사됨", en: "Copied", ja: "コピー済み", zh: "已复制")
        case .copyCommand:
            return localized(language, ko: "명령 복사", en: "Copy command", ja: "コマンドをコピー", zh: "复制命令")
        case .agentOn:
            return localized(language, ko: "자동 감지 켜짐", en: "Auto detect on", ja: "自動検出オン", zh: "自动检测开启")
        case .agentOff:
            return localized(language, ko: "자동 감지 꺼짐", en: "Auto detect off", ja: "自動検出オフ", zh: "自动检测关闭")
        case .neighborOff:
            return localized(language, ko: "꺼짐", en: "Off", ja: "オフ", zh: "关闭")
        case .neighborSearching:
            return localized(language, ko: "이웃을 찾는 중", en: "Finding neighbors", ja: "近くのねこを検索中", zh: "正在寻找邻居")
        }
    }

    public static func systemDefaultLanguage(resolvedName: String, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "System Default (\(resolvedName))"
        case "ja": return "システム既定 (\(resolvedName))"
        case "zh": return "系统默认 (\(resolvedName))"
        default: return "시스템 기본 (\(resolvedName))"
        }
    }

    public static func enabledSkillsCount(enabled: Int, total: Int, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(enabled)/\(total) enabled"
        case "ja": return "\(enabled)/\(total) 有効"
        case "zh": return "\(enabled)/\(total) 已启用"
        default: return "\(enabled)/\(total)개 활성"
        }
    }

    public static func neighborStatus(enabled: Bool, peerCount: Int, languageCode: String?) -> String {
        if !enabled {
            return text(.neighborOff, languageCode: languageCode)
        }
        if peerCount == 0 {
            return text(.neighborSearching, languageCode: languageCode)
        }
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(peerCount) found"
        case "ja": return "\(peerCount)件発見"
        case "zh": return "发现 \(peerCount) 个"
        default: return "\(peerCount)명 발견"
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
