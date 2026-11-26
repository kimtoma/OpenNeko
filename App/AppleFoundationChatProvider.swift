import Foundation
import OpenNekoKit
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationChatError: Error {
    case unavailable(OnDeviceModelAvailability)
    case empty

    func userMessage(languageCode: String) -> String {
        switch self {
        case let .unavailable(availability):
            return availability.readiness(languageCode: languageCode).detail
        case .empty:
            return NekoBubbleCopy.genericChatError(languageCode: languageCode)
        }
    }
}

/// Chat through Apple's on-device Foundation Models (macOS 26+). The app
/// still runs on macOS 14: everything here is gated by `canImport` and
/// `#available`, and reports `unsupportedOS` otherwise.
enum AppleFoundationChatProvider {
    static func availability() -> OnDeviceModelAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case let .unavailable(reason):
                switch reason {
                case .deviceNotEligible:
                    return .deviceNotEligible
                case .appleIntelligenceNotEnabled:
                    return .appleIntelligenceNotEnabled
                case .modelNotReady:
                    return .modelNotReady
                @unknown default:
                    return .unknown
                }
            }
        }
        #endif
        return .unsupportedOS
    }

    static func chat(history: [ChatMessage], system: String, languageCode: String) async throws -> String {
        let status = availability()
        guard status == .available else {
            throw AppleFoundationChatError.unavailable(status)
        }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let prompt = ChatPromptBuilder.formatPrompt(history, languageCode: languageCode)
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw AppleFoundationChatError.empty }
            return text
        }
        #endif
        throw AppleFoundationChatError.unavailable(.unsupportedOS)
    }
}
