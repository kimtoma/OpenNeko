import AppKit
import Darwin
import SwiftUI
import OpenNekoKit

/// Window for the free-mode wizard: checks this Mac, gets Ollama running,
/// pulls the recommended model, warms it up, then applies the Ollama preset.
/// Decisions live in OpenNekoKit (`LocalModelRecommender`,
/// `LocalModelSetupFlow`, `OllamaPullTracker`); this file only performs I/O.
final class LocalModelSetupController {
    private var window: NSWindow?
    private let model: LocalModelSetupModel

    init(languageCode: @escaping () -> String, applyProvider: @escaping (AIProviderConfig) -> Void) {
        model = LocalModelSetupModel(languageCode: languageCode, applyProvider: applyProvider)
    }

    func show() {
        if let window {
            model.restartIfIdle()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: LocalModelSetupView(model: model, close: { [weak self] in
            self?.window?.performClose(nil)
        }))
        let window = NSWindow(contentViewController: hosting)
        window.title = LocalModelSetupCopy.text(.windowTitle, languageCode: model.languageCode())
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 440, height: 400))
        window.center()
        self.window = window
        model.start()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class LocalModelSetupModel: ObservableObject {
    @Published private(set) var step: LocalModelSetupStep = .checking
    @Published private(set) var hardware: HardwareProfile?
    @Published private(set) var recommendation: LocalModelRecommendation?
    @Published var selectedModelID: String?

    let languageCode: () -> String
    private let applyProvider: (AIProviderConfig) -> Void
    private var task: Task<Void, Never>?
    private var installedModels: [String] = []

    private static let ollamaBase = URL(string: "http://127.0.0.1:11434")!
    private static let ollamaDownloadURL = URL(string: "https://ollama.com/download")!
    private static let ollamaBundleID = "com.electron.ollama"

    init(languageCode: @escaping () -> String, applyProvider: @escaping (AIProviderConfig) -> Void) {
        self.languageCode = languageCode
        self.applyProvider = applyProvider
    }

    var selectedModel: LocalModelEntry? {
        guard let recommendation else { return nil }
        let choices = recommendation.choices
        return choices.first { $0.id == selectedModelID } ?? choices.first
    }

    // MARK: - Actions

    func start() {
        task?.cancel()
        step = .checking
        task = Task { @MainActor [weak self] in
            await self?.checkMachineAndOllama()
        }
    }

    func restartIfIdle() {
        switch step {
        case .downloading, .warmingUp:
            return
        default:
            start()
        }
    }

    func openOllamaDownload() {
        NSWorkspace.shared.open(Self.ollamaDownloadURL)
        send(.openedOllamaDownload)
    }

    func download() {
        guard let model = selectedModel else { return }
        task?.cancel()
        task = Task { @MainActor [weak self] in
            await self?.install(model)
        }
    }

    func retry() {
        send(.retry)
        start()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func send(_ event: LocalModelSetupEvent) {
        step = LocalModelSetupFlow.reduce(step, event)
    }

    // MARK: - Steps

    @MainActor
    private func checkMachineAndOllama() async {
        let hardware = Self.currentHardware()
        self.hardware = hardware

        guard let catalog = Self.loadCatalog() else {
            step = .failed("local-models.json missing")
            return
        }
        let recommendation = LocalModelRecommender.recommend(catalog: catalog, hardware: hardware)
        self.recommendation = recommendation
        if case let .unsupported(reason) = recommendation {
            send(.unsupported(reason))
            return
        }
        if case let .recommended(primary, _, _) = recommendation, selectedModelID == nil {
            selectedModelID = primary.id
        }

        var launchedApp = false
        repeat {
            let models = await Self.fetchInstalledModels()
            let running = models != nil
            let appURL = Self.ollamaAppURL()
            installedModels = models ?? []
            send(.ollamaProbed(running: running, appInstalled: appURL != nil))

            if !running, let appURL, !launchedApp {
                launchedApp = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
            guard step.pollsForOllama else { break }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        } while !Task.isCancelled
    }

    @MainActor
    private func install(_ model: LocalModelEntry) async {
        if LocalModelSetupFlow.isInstalled(model.id, installedModels: installedModels) {
            send(.modelAlreadyInstalled)
        } else {
            send(.startDownload)
            await pull(model)
        }
        guard step == .warmingUp, !Task.isCancelled else { return }

        let warmUpError = await Self.warmUp(modelID: model.id)
        send(.warmUpFinished(succeeded: warmUpError == nil, message: warmUpError))
        if step == .done {
            applyProvider(LocalModelSetupFlow.providerConfig(modelID: model.id))
        }
    }

    @MainActor
    private func pull(_ model: LocalModelEntry) async {
        var request = URLRequest(url: Self.ollamaBase.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model.id, "stream": true])

        var tracker = OllamaPullTracker()
        var lastFraction = -1.0
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                send(.pullFailed("HTTP \(http.statusCode)"))
                return
            }
            for try await line in bytes.lines {
                if Task.isCancelled { return }
                tracker.consume(line: line)
                // Publish at most every 0.5% so SwiftUI is not flooded.
                if tracker.isFinished || tracker.fractionCompleted - lastFraction >= 0.005 {
                    lastFraction = tracker.fractionCompleted
                    send(.pullProgress(tracker))
                }
                if tracker.isFinished { break }
            }
            if !tracker.isFinished {
                send(.pullFailed("Download stopped early"))
            }
        } catch {
            if !Task.isCancelled {
                send(.pullFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - I/O helpers

    private static func currentHardware() -> HardwareProfile {
        var arm64: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let isAppleSilicon = sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0) == 0 && arm64 == 1

        let home = FileManager.default.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let freeDisk = values?.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) } ?? 0

        return HardwareProfile(
            memoryBytes: ProcessInfo.processInfo.physicalMemory,
            isAppleSilicon: isAppleSilicon,
            freeDiskBytes: freeDisk
        )
    }

    private static func loadCatalog() -> LocalModelCatalog? {
        guard
            let url = Bundle.main.url(forResource: "local-models", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return try? LocalModelCatalog.decode(from: data)
    }

    private static func ollamaAppURL() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ollamaBundleID) {
            return url
        }
        let candidates = [
            URL(fileURLWithPath: "/Applications/Ollama.app"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Ollama.app"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Installed model names, or nil when the Ollama API is not reachable.
    private static func fetchInstalledModels() async -> [String]? {
        var request = URLRequest(url: ollamaBase.appendingPathComponent("api/tags"))
        request.timeoutInterval = 1.5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            return AIProviderDetection.ollamaModels(from: data)
        } catch {
            return nil
        }
    }

    /// Loads the model into memory with an empty prompt. Returns an error
    /// message, or nil on success.
    private static func warmUp(modelID: String) async -> String? {
        var request = URLRequest(url: ollamaBase.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": modelID, "prompt": "", "stream": false])
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return "HTTP \(http.statusCode)"
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

private struct LocalModelSetupView: View {
    @ObservedObject var model: LocalModelSetupModel
    let close: () -> Void

    private var language: String { model.languageCode() }

    private func copy(_ key: LocalModelSetupCopyKey) -> String {
        LocalModelSetupCopy.text(key, languageCode: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy(.windowTitle))
                        .font(.title3.weight(.semibold))
                    if let hardware = model.hardware {
                        Text(LocalModelSetupCopy.hardwareSummary(hardware, languageCode: language))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 440, height: 400)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .checking:
            progressLine(copy(.checking))

        case let .unsupported(reason):
            Label(LocalModelSetupCopy.unsupported(reason, languageCode: language), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            closeButton

        case .needsOllama:
            Text(copy(.needsOllama))
            Button(copy(.openOllamaDownload), action: model.openOllamaDownload)
                .buttonStyle(.borderedProminent)

        case .waitingForOllama:
            progressLine(copy(.waitingForOllama))

        case .ready:
            modelPicker

        case let .failed(message):
            Label(copy(.failed), systemImage: "xmark.octagon")
                .foregroundStyle(.red)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Button(copy(.retry), action: model.retry)
                .buttonStyle(.borderedProminent)

        case let .downloading(fraction):
            VStack(alignment: .leading, spacing: 8) {
                Text("\(copy(.downloading)) · \(model.selectedModel?.displayName ?? "")")
                ProgressView(value: fraction)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

        case .warmingUp:
            progressLine(copy(.warmingUp))

        case .done:
            Label(copy(.done), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            closeButton
        }
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy(.chooseModel))
                .font(.headline)
            ForEach(model.recommendation?.choices ?? [], id: \.id) { entry in
                Button {
                    model.selectedModelID = entry.id
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: model.selectedModel?.id == entry.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(entry.displayName)
                                    .font(.body.weight(.medium))
                                if let badge = badge(for: entry) {
                                    Text(badge)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                }
                                if entry.koreanTested {
                                    Text(copy(.koreanTested))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(LocalModelSetupCopy.downloadSize(entry, languageCode: language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(copy(.consent))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(copy(.startDownload), action: model.download)
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedModel == nil)
        }
    }

    private func badge(for entry: LocalModelEntry) -> String? {
        guard case let .recommended(primary, lighter, smarter) = model.recommendation else { return nil }
        if entry.id == primary.id { return copy(.recommended) }
        if entry.id == lighter?.id { return copy(.lighter) }
        if entry.id == smarter?.id { return copy(.smarter) }
        return nil
    }

    private func progressLine(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
        }
    }

    private var closeButton: some View {
        Button(copy(.close), action: close)
    }
}
