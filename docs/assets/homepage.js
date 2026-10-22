(() => {
  'use strict';

  const supportedLanguages = ['en', 'ko', 'ja', 'zh'];
  const languageSelect = document.getElementById('language-select');
  const textNodes = Array.from(document.querySelectorAll('[data-i18n]'));
  const attributeNodes = Array.from(document.querySelectorAll('[data-i18n-attr]'));
  // Keep the readable English page as the source of default copy.
  const english = Object.fromEntries(textNodes.map((node) => [node.dataset.i18n, node.textContent]));
  attributeNodes.forEach((node) => {
    node.dataset.i18nAttr.split(',').forEach((pair) => {
      const [attribute, key] = pair.split(':');
      english[key] = node.getAttribute(attribute);
    });
  });
  Object.assign(english, {
    title: document.title,
    description: document.querySelector('meta[name="description"]').content,
    heroLead: 'A pixel cat. A little AI.\nA happier desktop.',
    noteMessage: 'Make room\nfor a little\nwonder.',
    speechIdle: "You do your thing.\nI'll be right here.",
    speechTyping: "You type. I type.\nWe're a pretty good team.",
    speechCoding: 'Big ideas in progress.\nMoral support: ready.',
    speechSuccess: 'Look at you go!\nThat deserves a little dance.',
    resumeMotion: 'Resume animation',
    reducedMotion: 'Animation is off to match your reduced motion preference',
    skinNote: '{skin}. Excellent taste, human.',
    copied: 'Copied!',
    copySuccess: 'Command copied to clipboard.',
    copyFallback: 'Command selected. Press Command+C or Control+C to copy.',
  });

  const translations = {
    en: english,
    ko: {
      title: 'OpenNeko — Mac 위의 작은 작업 친구',
      description: '작업에 반응하고 좋아하는 AI와 연결되는 작은 픽셀 고양이. OpenNeko는 macOS를 위한 오픈소스 네이티브 데스크탑 친구입니다.',
      skip: '본문 바로가기', navAria: '주요 메뉴', brandAria: 'OpenNeko 홈',
      navFeatures: '네코 만나기', navProviders: 'AI 연결', navInstall: '다운로드', language: '언어',
      heroEyebrow: '당신의 Mac에 찾아온 작은 친구',
      heroTitleA: '새로운 친구,', heroTitleB: '네코입니다.',
      heroLead: '작은 픽셀 고양이. 가벼운 AI 대화.\n조금 더 즐거운 데스크탑.',
      heroDescription: '멋진 무언가를 만드는 동안, 곁을 지켜줄 작은 친구를 만나보세요. Mac에서 태어난 호기심 많은 고양이, OpenNeko입니다.',
      downloadMac: 'Mac용 다운로드', heroExplore: '네코 알아보기', freeOpenSource: '무료 · 오픈소스',
      demoAria: '직접 조작하는 OpenNeko 데스크탑 미리보기', demoTitle: '네코의 데스크탑', preview: '미리보기',
      today: '오늘의 작은 메모', noteMessage: '작은 설렘,\n오늘도\n남겨두기.', goodIdeas: '좋은 아이디어',
      speechIdle: '할 일은 편하게 해요.\n저는 곁에 있을게요.',
      speechTyping: '집사도 타닥. 나도 타닥.\n우리 꽤 좋은 팀이다냥.',
      speechCoding: '멋진 생각을 만드는 중!\n응원은 내가 맡겠다냥.',
      speechSuccess: '정말 잘했다냥!\n춤 한번 춰야겠다냥.',
      petNeko: '네코 쓰다듬기', typingLabel: '여기에 입력해 네코의 반응 보기', typingPlaceholder: '살짝 입력해 보세요. 네코가 반응해요.',
      activityAria: '네코의 활동 선택', stateIdle: '쉬는 중', stateTyping: '타이핑', stateCoding: '코딩', stateSuccess: '기쁨',
      pauseMotion: '애니메이션 일시 정지', resumeMotion: '애니메이션 재생', reducedMotion: '시스템의 동작 줄이기 설정에 따라 애니메이션이 꺼져 있습니다',
      demoCaption: '글자를 입력하거나 네코를 쓰다듬어 보세요.',
      atAGlance: '한눈에 보기', specNative: 'macOS를 위한 앱', specAI: '원하는 AI와 연결', specPrivacy: '키 내용 없이 입력 활동만', specOpen: '열린 코드, 끝없는 호기심',
      featuresEyebrow: '작은 고양이가 만드는 연결', featuresTitleA: '늘 곁에서.', featuresTitleB: '자연스럽게.',
      featuresIntro: '데스크탑 한쪽에 조용히 머물면서, 작은 발로 제법 똑똑한 일들을 해냅니다.', allFeatures: '모든 기능 살펴보기',
      typingTitle: '당신의 리듬을 따라서', typingBody: '타이핑을 시작하면 네코도 함께 타닥타닥. 입력한 글자는 읽지 않고, 키를 누르는 활동에만 반응합니다.',
      chatTitle: '좋은 친구, 간단한 답변', chatBody: '고양이를 클릭하면 작은 AI 말풍선이 열립니다. 궁금한 것을 묻거나, 스킬과 슬래시 명령을 실행해 보세요.',
      agentTitle: '작업을 보여주는 작은 창', agentBody: 'Codex, Claude, Gemini, Cursor 같은 로컬 코딩 에이전트에 반응합니다. 로컬 상태 브리지로 나만의 도구도 연결할 수 있어요.',
      skinsEyebrow: '나를 닮은 작은 취향', skinsTitleA: '같은 작은 마음.', skinsTitleB: '다른 털옷.',
      skinsBody: '기본 스킨을 고르거나 나만의 스킨을 가져오세요. 같은 로컬 네트워크에 있는 고양이가 놀러 올 수도 있어요.', customSkins: '내 고양이로 꾸미기',
      skinAria: '고양이 스킨 미리보기', skinClassic: '클래식', skinBlack: '미드나잇', skinOrange: '마멀레이드', skinCalico: '삼색이', skinPink: '크림',
      skinNote: '{skin}. 집사 취향, 마음에 든다냥.',
      providersEyebrow: '좋아하는 AI를 데려오세요', providersTitleA: '나의 AI.', providersTitleB: '나의 선택.',
      providersIntro: '익숙한 친구에게, 나에게 맞는 연결을. 네코의 설정에서 원하는 방식을 골라주세요.',
      loginTitle: '쓰던 로그인 그대로', loginBody: 'Codex, Claude CLI, Gemini CLI의 로컬 로그인 세션을 사용합니다. 별도 API 키를 입력하지 않아도 돼요.',
      localTitle: '내 컴퓨터에서 편안하게', localBody: 'Ollama나 로컬 OpenAI 호환 서버에 연결하세요. LM Studio, llama.cpp, vLLM 등을 사용할 수 있습니다.', localDetail: '내 환경에 맞는 로컬 모델',
      apiTitle: '나만의 경로로 연결', apiBody: 'Gemini·Claude API 키를 추가하거나, OpenAI 호환 엔드포인트와 모델을 직접 설정하세요.', apiDetail: '저장한 API 키는 macOS 키체인에 보관',
      privacyTitle: '호기심은 가득하게. 내 공간은 소중하게.',
      privacyBody: '타이핑 반응은 입력한 글자를 읽지 않습니다. 대화는 선택한 AI 제공자에게 전달되고, 상태 브리지는 내 Mac에서 로컬로 연결됩니다.',
      installEyebrow: '하루에 더하는 아주 작은 변화', installTitleA: '한 친구를 위한', installTitleB: '자리를 내주세요.',
      installBody: '앱을 내려받아 Applications 폴더에 옮기고, 새로운 작은 친구를 만나보세요.', releaseNotes: '릴리스 노트', downloadZip: 'ZIP으로 다운로드',
      comingHome: '집사 따라 집에 가는 길.',
      sourceTitle: '직접 빌드하고 싶으신가요?', sourceBody: 'Xcode, XcodeGen, Git이 필요합니다. 저장소를 복제하고 프로젝트를 생성한 뒤 네이티브 앱을 실행하세요.',
      copy: '복사', copied: '복사됨!', copySuccess: '명령을 클립보드에 복사했습니다.', copyFallback: '명령을 선택했습니다. Command+C 또는 Control+C로 복사하세요.',
      communityTitle: '작은 고양이. 열린 세상.', communityBody: 'Swift로 만들고, MIT 라이선스로 나눕니다. 스킨 하나, 아이디어 하나, 작은 호기심도 좋아요. 당신의 자리도 여기 있어요.',
      communityLink: 'GitHub에서 만나기', madeBy: '작은 프로젝트를 만든', documentation: '사용 안내', feedback: '의견 보내기',
    },
    ja: {
      title: 'OpenNeko — Macに、小さな仲間を',
      description: '作業に反応し、お気に入りのAIにつながる小さなピクセル猫。OpenNekoはmacOSのためのオープンソースのネイティブデスクトップアプリです。',
      skip: '本文へ移動', navAria: 'メインナビゲーション', brandAria: 'OpenNeko ホーム',
      navFeatures: 'ネコを知る', navProviders: 'AI接続', navInstall: 'ダウンロード', language: '言語',
      heroEyebrow: 'あなたのMacに、小さな仲間を',
      heroTitleA: '新しい相棒、', heroTitleB: 'ネコです。',
      heroLead: 'ピクセル猫。ちょっとしたAI。\nデスクトップに、楽しさを。',
      heroDescription: 'あなたが素敵なものを作る間、そっとそばにいる小さな仲間。Mac生まれで好奇心いっぱいのOpenNekoです。',
      downloadMac: 'Mac版をダウンロード', heroExplore: 'ネコを知る', freeOpenSource: '無料・オープンソース',
      demoAria: '操作できるOpenNekoデスクトッププレビュー', demoTitle: 'ネコのデスクトップ', preview: 'プレビュー',
      today: '今日の小さなメモ', noteMessage: '小さな\nときめきの\n居場所を。', goodIdeas: 'いいアイデア',
      speechIdle: 'あなたはあなたのペースで。\nここにいるにゃ。',
      speechTyping: 'あなたもカタカタ。私もカタカタ。\nいいチームだにゃ。',
      speechCoding: '素敵なアイデアを作業中。\n応援は任せるにゃ。',
      speechSuccess: 'よくできたにゃ！\nちょっと踊りたい気分。',
      petNeko: 'ネコをなでる', typingLabel: '入力してネコの反応を見る', typingPlaceholder: '少し入力してみて。ネコが反応します。',
      activityAria: 'ネコの動作を選ぶ', stateIdle: 'のんびり', stateTyping: '入力中', stateCoding: 'コーディング', stateSuccess: 'うれしい',
      pauseMotion: 'アニメーションを停止', resumeMotion: 'アニメーションを再開', reducedMotion: '視差効果を減らす設定によりアニメーションは停止しています',
      demoCaption: '入力したり、ネコをなでたりしてみてね。',
      atAGlance: 'アプリの概要', specNative: 'macOSのために', specAI: '好きなAIを選択', specPrivacy: '入力内容は読みません', specOpen: 'コードも好奇心もオープンに',
      featuresEyebrow: '小さな猫がつなぐもの', featuresTitleA: 'いつもそばに。', featuresTitleB: '自然なリズムで。',
      featuresIntro: 'デスクトップに静かに寄り添いながら、小さな足でちょっと賢いお手伝いをします。', allFeatures: 'すべての機能を見る',
      typingTitle: 'あなたのリズムに合わせて', typingBody: 'あなたが入力すると、ネコも一緒にカタカタ。書いた言葉を読まず、キーを押す動作だけに反応します。',
      chatTitle: 'いい仲間、すばやい答え', chatBody: '猫をクリックすると小さなAIチャットが開きます。質問したり、スキルやスラッシュコマンドを使ったりできます。',
      agentTitle: '作業を映す小さな窓', agentBody: 'Codex、Claude、Gemini、Cursorなどのローカルエージェントに反応。ローカル状態ブリッジで自分のツールも接続できます。',
      skinsEyebrow: 'あなたらしい猫に', skinsTitleA: '同じ小さな心。', skinsTitleB: '違う毛並み。',
      skinsBody: '同梱スキンを選んだり、自分のスキンを読み込んだり。同じローカルネットワークの猫が遊びに来ることもあります。', customSkins: '自分らしく着せ替える',
      skinAria: '猫のスキンをプレビュー', skinClassic: 'クラシック', skinBlack: 'ミッドナイト', skinOrange: 'マーマレード', skinCalico: '三毛', skinPink: 'クリーム',
      skinNote: '{skin}。いいセンスだにゃ。',
      providersEyebrow: 'お気に入りのAIと一緒に', providersTitleA: 'あなたのAI。', providersTitleB: 'あなたの選択。',
      providersIntro: 'いつもの仲間に、自分に合う接続を。ネコの設定から好きな方法を選べます。',
      loginTitle: 'いつものログインで', loginBody: 'Codex、Claude CLI、Gemini CLIのローカルログインセッションを利用。追加のAPIキー入力は不要です。',
      localTitle: '自分のMacで、心地よく', localBody: 'OllamaやローカルのOpenAI互換サーバーに接続。LM Studio、llama.cpp、vLLMなどに対応します。', localDetail: '自分に合うローカルモデルを',
      apiTitle: '自分の方法でつなぐ', apiBody: 'Gemini・ClaudeのAPIキーを追加したり、OpenAI互換エンドポイントとモデルを設定したりできます。', apiDetail: '保存したAPIキーはmacOSキーチェーンへ',
      privacyTitle: '好奇心はたっぷり。プライバシーは大切に。',
      privacyBody: '入力反応で文字の内容を読むことはありません。チャットは選択したAIプロバイダーへ送信され、状態ブリッジはMac上でローカルに接続します。',
      installEyebrow: '毎日に、ほんの少しの変化を', installTitleA: 'もうひとり分の', installTitleB: '場所をあけて。',
      installBody: 'アプリをダウンロードし、Applicationsフォルダへ移動。新しい小さな仲間に会いましょう。', releaseNotes: 'リリースノート', downloadZip: 'ZIPをダウンロード',
      comingHome: '一緒におうちへ。',
      sourceTitle: '自分でビルドしたいですか？', sourceBody: 'Xcode、XcodeGen、Gitが必要です。リポジトリをクローンし、プロジェクトを生成してネイティブアプリを起動します。',
      copy: 'コピー', copied: 'コピー済み', copySuccess: 'コマンドをクリップボードにコピーしました。', copyFallback: 'コマンドを選択しました。Command+CまたはControl+Cでコピーしてください。',
      communityTitle: '小さな猫。開かれた世界。', communityBody: 'Swiftで作り、MITライセンスで共有。スキン、アイデア、小さな好奇心を持ち寄って。あなたの場所もここにあります。',
      communityLink: 'GitHubで会いましょう', madeBy: '小さなプロジェクト by', documentation: 'ドキュメント', feedback: 'フィードバック',
    },
    zh: {
      title: 'OpenNeko — 给你的Mac添一位小伙伴',
      description: '一只会响应工作、连接你喜爱的AI的像素猫。OpenNeko是专为macOS打造的开源原生桌面伙伴。',
      skip: '跳转到正文', navAria: '主导航', brandAria: 'OpenNeko首页',
      navFeatures: '认识小猫', navProviders: 'AI连接', navInstall: '下载应用', language: '语言',
      heroEyebrow: '给你的Mac添一位小伙伴',
      heroTitleA: '你的新伙伴，', heroTitleB: '小猫来了。',
      heroLead: '一只像素猫。一点AI。\n一个更快乐的桌面。',
      heroDescription: '当你创造美好的事物时，让一位小伙伴静静陪在身边。为Mac而生，天生好奇，这就是OpenNeko。',
      downloadMac: '下载Mac版', heroExplore: '认识小猫', freeOpenSource: '免费 · 开源',
      demoAria: '可交互的OpenNeko桌面预览', demoTitle: '小猫的桌面', preview: '预览',
      today: '给自己的一张便签', noteMessage: '留点空间，\n让小惊喜\n悄悄进来。', goodIdeas: '好点子',
      speechIdle: '你慢慢忙。\n我就在这里陪你。',
      speechTyping: '你敲敲键盘，我也敲敲。\n我们真是好搭档喵。',
      speechCoding: '好点子正在实现中。\n加油的事交给我喵。',
      speechSuccess: '做得真棒喵！\n值得跳一支小舞。',
      petNeko: '摸摸小猫', typingLabel: '在这里输入，看看小猫的反应', typingPlaceholder: '输入几个字，看看会发生什么。',
      activityAria: '选择小猫的活动', stateIdle: '休息', stateTyping: '打字', stateCoding: '编程', stateSuccess: '开心',
      pauseMotion: '暂停动画', resumeMotion: '播放动画', reducedMotion: '已根据系统的减少动态效果偏好关闭动画',
      demoCaption: '试着打打字，或轻轻摸摸小猫。',
      atAGlance: '应用概览', specNative: '专为macOS打造', specAI: '选择喜欢的AI', specPrivacy: '只感知活动，不读取文字', specOpen: '代码开放，好奇心满满',
      featuresEyebrow: '小猫，真实的陪伴', featuresTitleA: '在你身旁。', featuresTitleB: '跟随你的节奏。',
      featuresIntro: '安静地待在桌面一角，也会用小小的爪子，做几件聪明的事。', allFeatures: '探索所有功能',
      typingTitle: '跟着你的节奏', typingBody: '你打字时，小猫也一起敲键盘。它只响应按键活动，不会读取你写下的文字。',
      chatTitle: '好伙伴，也有好答案', chatBody: '点击小猫，打开小巧的AI聊天气泡。问个问题，运行技能，或使用方便的斜杠命令。',
      agentTitle: '一扇看见工作的小窗', agentBody: '响应Codex、Claude、Gemini、Cursor等本地编程Agent。也可以通过本地状态桥接，连接自己的工具。',
      skinsEyebrow: '一只属于你的猫', skinsTitleA: '同一颗小小的心。', skinsTitleB: '不同的毛色。',
      skinsBody: '选择内置外观，或导入自定义皮肤。同一局域网里的小猫，还可以到你的桌面串门。', customSkins: '打造你的小猫',
      skinAria: '预览小猫皮肤', skinClassic: '经典', skinBlack: '午夜', skinOrange: '橘子酱', skinCalico: '三花', skinPink: '奶油',
      skinNote: '{skin}。铲屎官，你品味不错喵。',
      providersEyebrow: '带上你最喜欢的AI', providersTitleA: '你的AI。', providersTitleB: '你的选择。',
      providersIntro: '熟悉的小伙伴，搭配适合你的连接方式。在小猫的设置里，选一个喜欢的就好。',
      loginTitle: '用你已有的登录', loginBody: '使用Codex、Claude CLI或Gemini CLI的本地登录会话。无需另外输入API密钥。',
      localTitle: '在自己的电脑里自在运行', localBody: '连接Ollama或本地OpenAI兼容服务器，包括LM Studio、llama.cpp和vLLM。', localDetail: '按你的方式使用本地模型',
      apiTitle: '走自己的连接路线', apiBody: '添加Gemini或Claude API密钥，也可以自定义OpenAI兼容端点和模型。', apiDetail: '保存的API密钥存放在macOS钥匙串中',
      privacyTitle: '好奇心满满，也尊重你的空间。',
      privacyBody: '打字反应不会读取输入的文字。聊天发送到你选择的AI提供商，状态桥接只在你的Mac本地连接。',
      installEyebrow: '给每天添一点小小的快乐', installTitleA: '留一点位置，', installTitleB: '给一位新朋友。',
      installBody: '下载应用，移到Applications文件夹，然后认识你的新伙伴。', releaseNotes: '发行说明', downloadZip: '也可以下载ZIP',
      comingHome: '跟你一起回家。',
      sourceTitle: '想自己动手构建吗？', sourceBody: '你需要Xcode、XcodeGen和Git。克隆仓库，生成项目，然后运行原生应用。',
      copy: '复制', copied: '已复制！', copySuccess: '命令已复制到剪贴板。', copyFallback: '已选中命令。按Command+C或Control+C复制。',
      communityTitle: '小小的猫，开放的世界。', communityBody: '用Swift构建，以MIT许可证分享。带来一款皮肤、一个点子，或一点好奇心。这里也有你的位置。',
      communityLink: '在GitHub上见', madeBy: '一个小项目，来自', documentation: '使用文档', feedback: '打个招呼',
    },
  };

  function normalizeLanguage(value) {
    const language = String(value || '').toLowerCase().split(/[-_]/)[0];
    return supportedLanguages.includes(language) ? language : null;
  }

  function preferredLanguage() {
    let saved;
    try { saved = localStorage.getItem('openneko-language'); } catch { /* Storage is optional. */ }
    const query = new URLSearchParams(location.search).get('lang');
    const candidates = [query, saved, ...(navigator.languages || [navigator.language])];
    return candidates.map(normalizeLanguage).find(Boolean) || 'en';
  }

  let currentLanguage = preferredLanguage();
  let currentState = 'idle';
  let currentSkin = 'black';
  let paused = false;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const motionButton = document.getElementById('motion-toggle');
  const speech = document.getElementById('demo-speech');
  const stateButtons = Array.from(document.querySelectorAll('[data-state]'));
  const skinButtons = Array.from(document.querySelectorAll('[data-skin]'));
  const stateKeys = { idle: 'speechIdle', typing: 'speechTyping', coding: 'speechCoding', success: 'speechSuccess' };
  const skinKeys = { classic: 'skinClassic', black: 'skinBlack', orange: 'skinOrange', calico: 'skinCalico', pink: 'skinPink' };

  function t(key) {
    return translations[currentLanguage][key] ?? english[key] ?? '';
  }

  function updateMotionControl() {
    const label = reducedMotion.matches ? t('reducedMotion') : t(paused ? 'resumeMotion' : 'pauseMotion');
    motionButton.setAttribute('aria-pressed', String(paused || reducedMotion.matches));
    motionButton.setAttribute('aria-label', label);
    motionButton.title = label;
    motionButton.disabled = reducedMotion.matches;
  }

  function updateSkinNote() {
    document.getElementById('skin-note').textContent = t('skinNote').replace('{skin}', t(skinKeys[currentSkin]));
  }

  function applyLanguage(language) {
    currentLanguage = normalizeLanguage(language) || 'en';
    document.documentElement.lang = currentLanguage;
    document.title = t('title');
    document.querySelector('meta[name="description"]').content = t('description');
    document.querySelector('meta[property="og:title"]').content = t('title');
    document.querySelector('meta[property="og:description"]').content = t('description');
    document.querySelector('meta[name="twitter:title"]').content = t('title');
    document.querySelector('meta[name="twitter:description"]').content = t('description');
    textNodes.forEach((node) => { node.textContent = t(node.dataset.i18n); });
    attributeNodes.forEach((node) => {
      node.dataset.i18nAttr.split(',').forEach((pair) => {
        const [attribute, key] = pair.split(':');
        node.setAttribute(attribute, t(key));
      });
    });
    languageSelect.value = currentLanguage;
    speech.textContent = t(stateKeys[currentState]);
    updateSkinNote();
    updateMotionControl();
    document.getElementById('copy-status').textContent = '';
  }

  languageSelect.addEventListener('change', () => {
    applyLanguage(languageSelect.value);
    try { localStorage.setItem('openneko-language', currentLanguage); } catch { /* Storage is optional. */ }
    try {
      const url = new URL(location.href);
      url.searchParams.set('lang', currentLanguage);
      history.replaceState(null, '', url);
    } catch { /* Language still works in restricted file previews. */ }
  });

  // Cache decoded image elements once per state. Frames are shown/hidden,
  // never fetched or assigned a new src on an animation tick.
  const frameContainer = document.getElementById('cat-frames');
  const initialCat = document.getElementById('initial-cat');
  const frameCache = new Map();
  const intervals = { idle: 300, typing: 150, coding: 170, success: 180 };
  let frames = [initialCat];
  let frameIndex = 0;
  let animationTimer = null;
  let typingTimer = null;
  let frameRequest = 0;
  let sceneVisible = false;

  function stopAnimation() {
    if (animationTimer !== null) clearTimeout(animationTimer);
    animationTimer = null;
  }

  function canAnimate() {
    return sceneVisible && !document.hidden && !paused && !reducedMotion.matches && frames.length > 1;
  }

  function scheduleFrame() {
    stopAnimation();
    if (!canAnimate()) return;
    animationTimer = setTimeout(() => {
      animationTimer = null;
      if (!canAnimate()) return;
      frames[frameIndex].hidden = true;
      frameIndex = (frameIndex + 1) % frames.length;
      frames[frameIndex].hidden = false;
      scheduleFrame();
    }, intervals[currentState]);
  }

  function loadFrames(skin, state) {
    const cacheKey = skin + '/' + state;
    if (frameCache.has(cacheKey)) return frameCache.get(cacheKey);
    const spritePath = 'assets/sprites/' + (skin === 'classic' ? '' : skin + '/');
    const promise = Promise.all(Array.from({ length: 4 }, async (_, index) => {
      const isInitial = skin === 'black' && state === 'idle' && index === 0;
      const img = isInitial ? initialCat : new Image(184, 184);
      if (!isInitial) {
        img.alt = '';
        img.hidden = true;
        img.decoding = 'async';
        img.src = spritePath + state + '_' + index + '.png';
        frameContainer.appendChild(img);
      }
      try {
        if (img.decode) await img.decode();
        else if (!img.complete) await new Promise((resolve, reject) => {
          img.addEventListener('load', resolve, { once: true });
          img.addEventListener('error', reject, { once: true });
        });
        return img.naturalWidth ? img : null;
      } catch { return null; }
    })).then((loaded) => loaded.filter(Boolean));
    frameCache.set(cacheKey, promise);
    return promise;
  }

  async function displayState() {
    stopAnimation();
    const request = ++frameRequest;
    if (!sceneVisible || document.hidden) return;
    const skin = currentSkin;
    const state = currentState;
    const nextFrames = await loadFrames(skin, state);
    if (request !== frameRequest || skin !== currentSkin || state !== currentState || !sceneVisible || document.hidden || !nextFrames.length) return;
    frames.forEach((img) => { img.hidden = true; });
    frames = nextFrames;
    frameIndex = 0;
    frames[0].hidden = false;
    scheduleFrame();
  }

  function setState(state) {
    if (!Object.hasOwn(stateKeys, state)) return;
    if (typingTimer !== null) clearTimeout(typingTimer);
    typingTimer = null;
    currentState = state;
    stateButtons.forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.state === state)));
    speech.textContent = t(stateKeys[state]);
    void displayState();
  }

  stateButtons.forEach((button) => button.addEventListener('click', () => setState(button.dataset.state)));
  document.getElementById('pet-neko').addEventListener('click', () => setState('success'));
  document.getElementById('typing-demo').addEventListener('input', () => {
    // React to input activity without inspecting, storing, or sending its value.
    if (currentState !== 'typing') setState('typing');
    if (typingTimer !== null) clearTimeout(typingTimer);
    typingTimer = setTimeout(() => {
      typingTimer = null;
      setState('idle');
    }, 1500);
  });

  motionButton.addEventListener('click', () => {
    paused = !paused;
    updateMotionControl();
    scheduleFrame();
  });
  reducedMotion.addEventListener('change', () => {
    updateMotionControl();
    scheduleFrame();
  });

  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(([entry]) => {
      sceneVisible = entry.isIntersecting;
      if (sceneVisible) void displayState();
      else { ++frameRequest; stopAnimation(); }
    }, { threshold: 0.05 });
    observer.observe(document.getElementById('desktop-demo'));
  } else {
    // Keep a useful static preview in older browsers without a visibility API.
    sceneVisible = false;
  }

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      ++frameRequest;
      stopAnimation();
      if (typingTimer !== null) {
        clearTimeout(typingTimer);
        typingTimer = null;
        setState('idle');
      }
    } else if (sceneVisible) void displayState();
  });
  window.addEventListener('pagehide', () => { ++frameRequest; stopAnimation(); });
  window.addEventListener('pageshow', () => { if (sceneVisible) void displayState(); });

  skinButtons.forEach((button) => {
    button.addEventListener('click', () => {
      currentSkin = button.dataset.skin;
      skinButtons.forEach((choice) => choice.setAttribute('aria-pressed', String(choice === button)));
      updateSkinNote();
      void displayState();
    });
  });

  const copyButton = document.getElementById('copy-command');
  let copyResetTimer = null;
  copyButton.addEventListener('click', async () => {
    const command = document.getElementById('install-command');
    const status = document.getElementById('copy-status');
    if (copyResetTimer !== null) clearTimeout(copyResetTimer);
    try {
      if (!navigator.clipboard || !window.isSecureContext) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(command.textContent.trim());
      copyButton.textContent = t('copied');
      status.textContent = t('copySuccess');
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(command);
      selection.removeAllRanges();
      selection.addRange(range);
      status.textContent = t('copyFallback');
    }
    copyResetTimer = setTimeout(() => {
      copyButton.textContent = t('copy');
      copyResetTimer = null;
    }, 2200);
  });

  applyLanguage(currentLanguage);
})();
