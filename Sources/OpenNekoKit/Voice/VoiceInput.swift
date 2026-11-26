import Foundation

/// Permission state for the microphone or speech recognition, mapped from
/// the platform's authorization status by the app.
public enum VoicePermission: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

public enum VoiceInputFailure: Equatable, Sendable {
    case microphoneDenied
    case speechDenied
    /// The recognizer for this language cannot run on this Mac. Audio is
    /// never sent to a server, so voice input stays off instead.
    case onDeviceUnavailable
    case audioUnavailable
    case nothingHeard
}

public enum VoiceInputStep: Equatable, Sendable {
    case requestMicrophone
    case requestSpeechRecognition
    case start
    case fail(VoiceInputFailure)
}

/// Tap-to-talk dictation, like the ChatGPT, Claude and Gemini apps: tap the
/// mic to start, tap again (or just stop talking) to finish, Esc to cancel.
/// Speech is recognized on device only and lands in the chat field for
/// review; it is never sent anywhere until the person presses Send.
public enum VoiceInputPolicy {
    /// One dictation never records longer than this.
    public static let maxDuration: TimeInterval = 60
    /// After speech was heard, this much silence ends the dictation.
    public static let silenceTimeout: TimeInterval = 2.0
    /// With nothing heard at all, give up after this long.
    public static let noSpeechTimeout: TimeInterval = 8.0

    /// Whether listening should end on its own now. `lastChangeAt` is when
    /// the transcript last changed (nil while nothing has been heard).
    public static func shouldAutoStop(
        startedAt: TimeInterval,
        lastChangeAt: TimeInterval?,
        now: TimeInterval
    ) -> Bool {
        if now - startedAt >= maxDuration { return true }
        guard let lastChangeAt else { return now - startedAt >= noSpeechTimeout }
        return now - lastChangeAt >= silenceTimeout
    }
    public static let maxCharacters = 1_000

    public static func localeIdentifier(languageCode: String?) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": "en-US"
        case "ja": "ja-JP"
        case "zh": "zh-CN"
        default: "ko-KR"
        }
    }

    /// What to do when the mic button is pressed.
    public static func nextStep(
        microphone: VoicePermission,
        speech: VoicePermission,
        onDeviceSupported: Bool
    ) -> VoiceInputStep {
        switch microphone {
        case .denied: return .fail(.microphoneDenied)
        case .notDetermined: return .requestMicrophone
        case .granted: break
        }
        switch speech {
        case .denied: return .fail(.speechDenied)
        case .notDetermined: return .requestSpeechRecognition
        case .granted: break
        }
        return onDeviceSupported ? .start : .fail(.onDeviceUnavailable)
    }

    /// The chat field text while and after speaking: whatever was typed
    /// before the mic was tapped, then the transcript.
    public static func merged(base: String, transcript: String) -> String {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return base }
        let typed = base.trimmingCharacters(in: .whitespaces)
        let joined = typed.isEmpty ? spoken : typed + " " + spoken
        return String(joined.prefix(maxCharacters))
    }
}

/// en/ko/ja/zh copy for voice input.
public enum VoiceInputCopy {
    public static func listening(languageCode: String?) -> String {
        pick(languageCode, ko: "듣고 있다냥… 말을 멈추거나 다시 누르면 끝, Esc는 취소", en: "Listening… pause or tap again to finish, Esc to cancel", ja: "聞いてるにゃ… 話し終えるかもう一度押すと終了、Escで取消", zh: "正在听喵… 停顿或再点一次结束，Esc 取消")
    }

    public static func micHelp(languageCode: String?) -> String {
        pick(languageCode, ko: "눌러서 말하기 (이 맥 안에서만 인식)", en: "Tap to dictate (recognized on this Mac only)", ja: "押して話す（このMac内でのみ認識）", zh: "点击说话（仅在本机识别）")
    }

    public static func stopHelp(languageCode: String?) -> String {
        pick(languageCode, ko: "받아쓰기 끝내기", en: "Finish dictation", ja: "書き取りを終える", zh: "结束听写")
    }

    public static func failure(_ failure: VoiceInputFailure, languageCode: String?) -> String {
        switch failure {
        case .microphoneDenied:
            pick(languageCode, ko: "마이크 권한이 꺼져 있다냥. 시스템 설정 > 개인정보 보호에서 켜줘", en: "Microphone access is off. Turn it on in System Settings > Privacy", ja: "マイクの許可がオフにゃ。システム設定 > プライバシーでオンにして", zh: "麦克风权限已关闭。请在系统设置 > 隐私中开启")
        case .speechDenied:
            pick(languageCode, ko: "음성 인식 권한이 꺼져 있다냥. 시스템 설정 > 개인정보 보호에서 켜줘", en: "Speech recognition is off. Turn it on in System Settings > Privacy", ja: "音声認識の許可がオフにゃ。システム設定 > プライバシーでオンにして", zh: "语音识别权限已关闭。请在系统设置 > 隐私中开启")
        case .onDeviceUnavailable:
            pick(languageCode, ko: "이 맥에서는 이 언어를 기기 안에서 인식할 수 없다냥", en: "This Mac can't recognize this language on device", ja: "このMacではこの言語を端末内で認識できないにゃ", zh: "这台 Mac 无法在本机识别这种语言")
        case .audioUnavailable:
            pick(languageCode, ko: "마이크를 열 수 없다냥", en: "Couldn't open the microphone", ja: "マイクを開けないにゃ", zh: "无法打开麦克风")
        case .nothingHeard:
            pick(languageCode, ko: "아무것도 못 들었다냥", en: "I didn't catch anything", ja: "何も聞こえなかったにゃ", zh: "什么也没听到喵")
        }
    }

    private static func pick(_ languageCode: String?, ko: String, en: String, ja: String, zh: String) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
