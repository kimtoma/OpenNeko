import Foundation

public enum LocalModelSetupCopyKey: String, CaseIterable, Sendable {
    case entryTitle
    case entryDetail
    case entryButton
    case windowTitle
    case checking
    case needsOllama
    case openOllamaDownload
    case waitingForOllama
    case chooseModel
    case recommended
    case lighter
    case smarter
    case koreanTested
    case consent
    case startDownload
    case downloading
    case warmingUp
    case done
    case failed
    case retry
    case close
    case notAppleSilicon
}

/// Copy for the local model setup wizard (en/ko/ja/zh).
public enum LocalModelSetupCopy {
    public static func text(_ key: LocalModelSetupCopyKey, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch key {
        case .entryTitle:
            return localized(language, ko: "로컬 모델 설치", en: "Local model setup", ja: "ローカルモデルの設定", zh: "设置本地模型")
        case .entryDetail:
            return localized(language, ko: "구독 없이 이 Mac에서 바로 대답해요", en: "Replies on this Mac, no subscription", ja: "サブスクなしでこのMacが返答します", zh: "无需订阅，在这台 Mac 上回复")
        case .entryButton:
            return localized(language, ko: "설치 도우미", en: "Set up", ja: "設定する", zh: "开始设置")
        case .windowTitle:
            return localized(language, ko: "로컬 모델 설치 도우미", en: "Local Model Setup", ja: "ローカルモデル設定", zh: "本地模型设置")
        case .checking:
            return localized(language, ko: "이 Mac을 살펴보는 중...", en: "Checking this Mac...", ja: "このMacを確認中...", zh: "正在检查这台 Mac...")
        case .needsOllama:
            return localized(language, ko: "Ollama가 필요해요. 설치하면 자동으로 이어갈게요.", en: "Ollama is needed. Install it and setup continues on its own.", ja: "Ollamaが必要です。インストールすると自動で続きます。", zh: "需要 Ollama。安装后会自动继续。")
        case .openOllamaDownload:
            return localized(language, ko: "Ollama 받기", en: "Get Ollama", ja: "Ollamaを入手", zh: "获取 Ollama")
        case .waitingForOllama:
            return localized(language, ko: "Ollama 실행을 기다리는 중...", en: "Waiting for Ollama to start...", ja: "Ollamaの起動を待っています...", zh: "正在等待 Ollama 启动...")
        case .chooseModel:
            return localized(language, ko: "이 Mac에 맞는 모델", en: "Models that fit this Mac", ja: "このMacに合うモデル", zh: "适合这台 Mac 的模型")
        case .recommended:
            return localized(language, ko: "추천", en: "Recommended", ja: "おすすめ", zh: "推荐")
        case .lighter:
            return localized(language, ko: "가볍게", en: "Lighter", ja: "軽め", zh: "更轻")
        case .smarter:
            return localized(language, ko: "더 똑똑하게", en: "Smarter", ja: "より賢く", zh: "更聪明")
        case .koreanTested:
            return localized(language, ko: "한국어 검증", en: "Korean tested", ja: "韓国語で検証済み", zh: "已测韩语")
        case .consent:
            return localized(language, ko: "Ollama가 ollama.com에서 모델을 받아 이 Mac에만 저장해요.", en: "Ollama downloads the model from ollama.com and keeps it on this Mac.", ja: "Ollamaがollama.comからモデルを取得し、このMacだけに保存します。", zh: "Ollama 会从 ollama.com 下载模型，并只保存在这台 Mac 上。")
        case .startDownload:
            return localized(language, ko: "다운로드 시작", en: "Download", ja: "ダウンロード", zh: "开始下载")
        case .downloading:
            return localized(language, ko: "받는 중", en: "Downloading", ja: "ダウンロード中", zh: "正在下载")
        case .warmingUp:
            return localized(language, ko: "모델을 깨우는 중...", en: "Warming up the model...", ja: "モデルを起動中...", zh: "正在唤醒模型...")
        case .done:
            return localized(language, ko: "준비 완료! 이제 이 Mac에서 대답한다냥", en: "All set! Replies now run on this Mac, nya", ja: "準備完了！このMacで返事するにゃ", zh: "准备好了！现在在这台 Mac 上回复喵")
        case .failed:
            return localized(language, ko: "설치하지 못했어요", en: "Setup didn't finish", ja: "設定できませんでした", zh: "设置未完成")
        case .retry:
            return localized(language, ko: "다시 시도", en: "Try again", ja: "もう一度", zh: "重试")
        case .close:
            return localized(language, ko: "닫기", en: "Close", ja: "閉じる", zh: "关闭")
        case .notAppleSilicon:
            return localized(language, ko: "Apple Silicon Mac에서만 지원해요", en: "Requires an Apple Silicon Mac", ja: "Apple Silicon搭載Macのみ対応です", zh: "仅支持 Apple 芯片的 Mac")
        }
    }

    public static func hardwareSummary(_ hardware: HardwareProfile, languageCode: String?) -> String {
        let memory = hardware.memoryGB
        let disk = Int(hardware.freeDiskGB.rounded(.down))
        return localized(
            AppLanguage.normalized(languageCode) ?? "ko",
            ko: "메모리 \(memory)GB · 여유 공간 \(disk)GB",
            en: "\(memory) GB memory · \(disk) GB free",
            ja: "メモリ \(memory)GB · 空き容量 \(disk)GB",
            zh: "内存 \(memory)GB · 可用空间 \(disk)GB"
        )
    }

    public static func downloadSize(_ model: LocalModelEntry, languageCode: String?) -> String {
        let size = String(format: "%.1f", model.downloadGB)
        return localized(
            AppLanguage.normalized(languageCode) ?? "ko",
            ko: "\(size)GB 다운로드",
            en: "\(size) GB download",
            ja: "\(size)GBのダウンロード",
            zh: "下载 \(size)GB"
        )
    }

    public static func unsupported(_ reason: LocalModelUnsupportedReason, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch reason {
        case .notAppleSilicon:
            return text(.notAppleSilicon, languageCode: language)
        case let .notEnoughMemory(minimumGB):
            return localized(language, ko: "메모리가 최소 \(minimumGB)GB 필요해요", en: "Needs at least \(minimumGB) GB of memory", ja: "メモリが最低\(minimumGB)GB必要です", zh: "至少需要 \(minimumGB)GB 内存")
        case let .notEnoughDisk(neededGB):
            let needed = Int(neededGB.rounded(.up))
            return localized(language, ko: "여유 공간이 최소 \(needed)GB 필요해요", en: "Needs at least \(needed) GB of free space", ja: "空き容量が最低\(needed)GB必要です", zh: "至少需要 \(needed)GB 可用空间")
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
