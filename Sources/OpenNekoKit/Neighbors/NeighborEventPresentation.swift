import Foundation

public enum NeighborEventPresentation {
    public static let guestVisitDuration: TimeInterval = 25
    public static let guestBubbleExtension: TimeInterval = 6

    public static func displayName(for peer: NeighborPeer, languageCode: String?) -> String {
        if isCodexPet(peer) {
            return codexPetDisplayName(languageCode: languageCode)
        }
        if !peer.name.isEmpty {
            return peer.name
        }
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "Neighbor Cat"
        case "ja": return "近くのねこ"
        case "zh": return "邻居猫"
        default: return "이웃 고양이"
        }
    }

    public static func presenceState(for presence: NeighborPresence) -> CatState {
        switch presence {
        case .idle:
            return .idle
        case .coding:
            return .coding
        case .typing:
            return .typing
        case .away:
            return .nap
        }
    }

    public static func greeting(key: Int, languageCode: String?) -> String {
        let greetings = greetings(languageCode: languageCode)
        guard !greetings.isEmpty else { return "Hi!" }
        return greetings[abs(key) % greetings.count]
    }

    public static func mainBubbleText(for event: NeighborEvent, languageCode: String?) -> String? {
        switch event {
        case .joined(let peer):
            return joinedText(name: displayName(for: peer, languageCode: languageCode), languageCode: languageCode)
        case .left(let peer):
            return leftText(name: displayName(for: peer, languageCode: languageCode), languageCode: languageCode)
        case .presence:
            return nil
        case .wave(let peer):
            return waveText(name: displayName(for: peer, languageCode: languageCode), languageCode: languageCode)
        case .greeting(let peer, _):
            return greetingReplyText(name: displayName(for: peer, languageCode: languageCode), languageCode: languageCode)
        }
    }

    public static func sentWaveText(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "Waved to neighbors"
        case "ja": return "近くのねこに挨拶しました"
        case "zh": return "已向邻居打招呼"
        default: return "이웃 고양이에게 인사했어요"
        }
    }

    public static func disabledText(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "Neighbors are off"
        case "ja": return "近くのねこはオフです"
        case "zh": return "邻居功能已关闭"
        default: return "이웃 고양이 기능이 꺼져 있어요"
        }
    }

    public static func isCodexPet(_ peer: NeighborPeer) -> Bool {
        let signature = [peer.id, peer.name, peer.skin]
            .joined(separator: " ")
            .lowercased()
        let hasCodex = signature.contains("codex")
        let hasPet = signature.contains("pet") || signature.contains("buddy") || signature.contains("mascot")
        return hasCodex && hasPet
    }

    public static func codexPetPunchText(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "Codex pet spotted! Nya-punch!"
        case "ja": return "Codexペット発見、にゃんパンチ!"
        case "zh": return "发现 Codex 宠物，喵喵拳!"
        default: return "Codex pet 발견, 냥냥펀치!"
        }
    }

    public static func codexPetOuchText(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "Ow, paws off!"
        case "ja": return "いたっ、肉球つよい!"
        case "zh": return "疼，肉球好强!"
        default: return "아야, 젤리 강하다!"
        }
    }

    private static func codexPetDisplayName(languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "ja": return "Codexペット"
        case "zh": return "Codex 宠物"
        default: return "Codex pet"
        }
    }

    private static func greetings(languageCode: String?) -> [String] {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en":
            return ["Hi!", "Nice to meet, nya~", "See you, nya~!", "Let's work together, nya~!"]
        case "ja":
            return ["やあ！", "はじめましてにゃ", "またねにゃ！", "一緒に働こうにゃ！"]
        case "zh":
            return ["嗨！", "很高兴见到你喵", "再见喵！", "一起工作喵！"]
        default:
            return ["안녕!", "반갑다냥!", "또 보자냥!", "같이 일하자냥!"]
        }
    }

    private static func joinedText(name: String, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(name) joined"
        case "ja": return "\(name)が来ました"
        case "zh": return "\(name)来了"
        default: return "\(name) 접속"
        }
    }

    private static func leftText(name: String, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(name) left"
        case "ja": return "\(name)が帰りました"
        case "zh": return "\(name)离开了"
        default: return "\(name) 떠남"
        }
    }

    private static func waveText(name: String, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(name) waved"
        case "ja": return "\(name)が挨拶しました"
        case "zh": return "\(name)打招呼了"
        default: return "\(name) 인사"
        }
    }

    private static func greetingReplyText(name: String, languageCode: String?) -> String {
        let language = AppLanguage.normalized(languageCode) ?? "ko"
        switch language {
        case "en": return "\(name) says hi back"
        case "ja": return "\(name)も挨拶しました"
        case "zh": return "\(name)也回应了"
        default: return "\(name)도 반가워해요"
        }
    }
}
