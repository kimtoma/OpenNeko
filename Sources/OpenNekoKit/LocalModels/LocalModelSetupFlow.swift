import Foundation

/// Steps of the local model setup wizard. The App layer performs the side
/// effects (probing Ollama, pulling, warming up) and feeds results back in as
/// `LocalModelSetupEvent`s; this reducer decides what the wizard shows.
public enum LocalModelSetupStep: Equatable, Sendable {
    case checking
    case unsupported(LocalModelUnsupportedReason)
    case needsOllama
    case waitingForOllama
    case ready
    case downloading(fraction: Double)
    case warmingUp
    case done
    case failed(String)

    /// Whether the wizard should keep polling for a running Ollama server.
    public var pollsForOllama: Bool {
        switch self {
        case .needsOllama, .waitingForOllama: true
        default: false
        }
    }
}

public enum LocalModelSetupEvent: Equatable, Sendable {
    case unsupported(LocalModelUnsupportedReason)
    /// Result of probing Ollama: `running` means the HTTP API answered,
    /// `appInstalled` means Ollama.app exists but may not be running yet.
    case ollamaProbed(running: Bool, appInstalled: Bool)
    case openedOllamaDownload
    case startDownload
    case modelAlreadyInstalled
    case pullProgress(OllamaPullTracker)
    case pullFailed(String)
    case warmUpFinished(succeeded: Bool, message: String?)
    case retry
}

public enum LocalModelSetupFlow {
    public static func reduce(_ step: LocalModelSetupStep, _ event: LocalModelSetupEvent) -> LocalModelSetupStep {
        switch event {
        case let .unsupported(reason):
            return .unsupported(reason)

        case let .ollamaProbed(running, appInstalled):
            switch step {
            case .checking, .needsOllama, .waitingForOllama:
                if running {
                    return .ready
                }
                if appInstalled {
                    return .waitingForOllama
                }
                return step == .waitingForOllama ? .waitingForOllama : .needsOllama
            default:
                return step
            }

        case .openedOllamaDownload:
            return step == .needsOllama ? .waitingForOllama : step

        case .startDownload:
            switch step {
            case .ready, .failed:
                return .downloading(fraction: 0)
            default:
                return step
            }

        case .modelAlreadyInstalled:
            switch step {
            case .ready, .downloading, .failed:
                return .warmingUp
            default:
                return step
            }

        case let .pullProgress(tracker):
            guard case .downloading = step else {
                return step
            }
            switch tracker.phase {
            case .succeeded:
                return .warmingUp
            case let .failed(message):
                return .failed(message)
            default:
                return .downloading(fraction: tracker.fractionCompleted)
            }

        case let .pullFailed(message):
            if case .downloading = step {
                return .failed(message)
            }
            return step

        case let .warmUpFinished(succeeded, message):
            guard step == .warmingUp else {
                return step
            }
            return succeeded ? .done : .failed(message ?? "")

        case .retry:
            if case .failed = step {
                return .checking
            }
            return step
        }
    }

    /// The provider config the wizard applies once the model is ready:
    /// the existing Ollama preset with the chosen model.
    public static func providerConfig(modelID: String) -> AIProviderConfig {
        AIProviderPreset.config(
            for: "ollama",
            overrides: AIProviderConfig(presetID: "ollama", type: .openAICompatible, model: modelID)
        )
    }

    /// Whether `modelID` already appears in Ollama's `/api/tags` list.
    /// Ollama reports untagged pulls as `name:latest`.
    public static func isInstalled(_ modelID: String, installedModels: [String]) -> Bool {
        let wanted = normalizedModelName(modelID)
        return installedModels.contains { normalizedModelName($0) == wanted }
    }

    static func normalizedModelName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains(":") ? trimmed : trimmed + ":latest"
    }
}
