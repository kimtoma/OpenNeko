import Foundation

/// Runtime availability of Apple's on-device Foundation Models, as reported
/// by the App layer (the framework itself is only touched in `App/`).
public enum OnDeviceModelAvailability: String, Equatable, Sendable {
    case available
    case unsupportedOS
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown

    public func readiness(languageCode: String?) -> AIProviderReadiness {
        let l = AppLanguage.normalized(languageCode) ?? "ko"
        switch self {
        case .available:
            return AIProviderReadiness(
                severity: .ready,
                title: localized(l, ko: "온디바이스 모델 준비됨", en: "On-device model ready", ja: "オンデバイスモデル準備完了", zh: "设备端模型已就绪"),
                detail: localized(l, ko: "다운로드 없이 이 Mac에서 바로 대답해요.", en: "Replies on this Mac with no download.", ja: "ダウンロードなしでこのMacが返答します。", zh: "无需下载，直接在这台 Mac 上回复。"),
                systemImage: "checkmark.circle.fill"
            )
        case .unsupportedOS:
            return needsAction(
                l,
                ko: "macOS 26 이상에서만 쓸 수 있어요.", en: "Requires macOS 26 or later.",
                ja: "macOS 26以降が必要です。", zh: "需要 macOS 26 或更高版本。"
            )
        case .deviceNotEligible:
            return needsAction(
                l,
                ko: "이 Mac은 Apple Intelligence를 지원하지 않아요.", en: "This Mac doesn't support Apple Intelligence.",
                ja: "このMacはApple Intelligenceに対応していません。", zh: "这台 Mac 不支持 Apple Intelligence。"
            )
        case .appleIntelligenceNotEnabled:
            return needsAction(
                l,
                ko: "시스템 설정에서 Apple Intelligence를 켜 주세요.", en: "Turn on Apple Intelligence in System Settings.",
                ja: "システム設定でApple Intelligenceをオンにしてください。", zh: "请在系统设置中开启 Apple Intelligence。"
            )
        case .modelNotReady:
            return AIProviderReadiness(
                severity: .warning,
                title: localized(l, ko: "모델 준비 중", en: "Model getting ready", ja: "モデル準備中", zh: "模型准备中"),
                detail: localized(l, ko: "macOS가 모델을 내려받는 중이에요. 잠시 뒤 다시 시도하세요.", en: "macOS is still downloading the model. Try again shortly.", ja: "macOSがモデルをダウンロード中です。しばらくしてから試してください。", zh: "macOS 仍在下载模型，请稍后再试。"),
                systemImage: "hourglass"
            )
        case .unknown:
            return needsAction(
                l,
                ko: "온디바이스 모델 상태를 확인하지 못했어요.", en: "Couldn't check the on-device model.",
                ja: "オンデバイスモデルの状態を確認できませんでした。", zh: "无法检查设备端模型状态。"
            )
        }
    }

    private func needsAction(_ l: String, ko: String, en: String, ja: String, zh: String) -> AIProviderReadiness {
        AIProviderReadiness(
            severity: .needsAction,
            title: localized(l, ko: "온디바이스 모델 사용 불가", en: "On-device model unavailable", ja: "オンデバイスモデル利用不可", zh: "设备端模型不可用"),
            detail: localized(l, ko: ko, en: en, ja: ja, zh: zh),
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private func localized(_ language: String, ko: String, en: String, ja: String, zh: String) -> String {
        switch language {
        case "en": return en
        case "ja": return ja
        case "zh": return zh
        default: return ko
        }
    }
}
