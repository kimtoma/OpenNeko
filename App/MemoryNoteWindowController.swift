import AppKit
import SwiftUI
import OpenNekoKit

/// "Memory Notes": one window to read and edit the three memory files and
/// the memory consent settings. File logic lives in OpenNekoKit
/// (`MemoryStore`, `MemoryDocument`); this is a thin editor.
final class MemoryNoteWindowController {
    private var window: NSWindow?
    private let model: MemoryNoteModel
    private let languageCode: () -> String

    init(
        store: MemoryStore,
        languageCode: @escaping () -> String,
        settings: @escaping () -> (enabled: Bool, scope: MemoryCloudScope),
        onSettingsChange: @escaping (Bool, MemoryCloudScope) -> Void
    ) {
        self.languageCode = languageCode
        self.model = MemoryNoteModel(store: store, settings: settings, onSettingsChange: onSettingsChange)
    }

    /// Picks up files the cat just wrote, without touching unsaved edits.
    func reload() {
        model.reload()
    }

    func show() {
        let language = languageCode()
        model.reload()
        let view = MemoryNoteView(model: model, languageCode: language)
        if let window {
            (window.contentViewController as? NSHostingController<MemoryNoteView>)?.rootView = view
            window.title = MemoryCopy.text(.windowTitle, languageCode: language)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = MemoryCopy.text(.windowTitle, languageCode: language)
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 560))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class MemoryNoteModel: ObservableObject {
    @Published var selected: MemoryFile = .user
    @Published var texts: [MemoryFile: String] = [:]
    @Published private(set) var savedTexts: [MemoryFile: String] = [:]
    @Published var enabled = true
    @Published var scope: MemoryCloudScope = .ask
    @Published var status = ""

    let store: MemoryStore
    private let settings: () -> (enabled: Bool, scope: MemoryCloudScope)
    private let onSettingsChange: (Bool, MemoryCloudScope) -> Void

    init(
        store: MemoryStore,
        settings: @escaping () -> (enabled: Bool, scope: MemoryCloudScope),
        onSettingsChange: @escaping (Bool, MemoryCloudScope) -> Void
    ) {
        self.store = store
        self.settings = settings
        self.onSettingsChange = onSettingsChange
    }

    func reload() {
        for file in MemoryFile.allCases {
            let onDisk = store.read(file)
            if !isDirty(file) {
                texts[file] = onDisk
            }
            savedTexts[file] = onDisk
        }
        let current = settings()
        enabled = current.enabled
        scope = current.scope
    }

    func isDirty(_ file: MemoryFile) -> Bool {
        (texts[file] ?? "") != (savedTexts[file] ?? "")
    }

    func save(languageCode: String) {
        let file = selected
        do {
            try store.write(texts[file] ?? "", to: file)
            savedTexts[file] = texts[file] ?? ""
            status = MemoryCopy.text(.saved, languageCode: languageCode)
        } catch {
            status = error.localizedDescription
        }
    }

    func revert() {
        texts[selected] = savedTexts[selected] ?? ""
        status = ""
    }

    func applySettings(enabled: Bool, scope: MemoryCloudScope) {
        self.enabled = enabled
        self.scope = scope
        onSettingsChange(enabled, scope)
    }

    func revealInFinder() {
        let url = store.url(for: selected)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            try? FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(store.directoryURL)
        }
    }
}

struct MemoryNoteView: View {
    @ObservedObject var model: MemoryNoteModel
    let languageCode: String

    private func copy(_ key: MemoryCopy.Key) -> String {
        MemoryCopy.text(key, languageCode: languageCode)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { model.texts[model.selected] ?? "" },
            set: { model.texts[model.selected] = $0; model.status = "" }
        )
    }

    private var scopeBinding: Binding<MemoryCloudScope> {
        Binding(
            get: { model.scope == .ask ? .soulOnly : model.scope },
            set: { model.applySettings(enabled: model.enabled, scope: $0) }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.enabled },
            set: { model.applySettings(enabled: $0, scope: model.scope) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(copy(.enabledToggle), isOn: enabledBinding)
            Text(copy(.enabledHelp))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(copy(.cloudScopeLabel))
                Picker("", selection: scopeBinding) {
                    ForEach([MemoryCloudScope.all, .soulOnly, .none], id: \.self) { scope in
                        Text(MemoryCopy.scopeTitle(scope, languageCode: languageCode)).tag(scope)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            Text(copy(.cloudScopeHelp))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Picker("", selection: $model.selected) {
                ForEach(MemoryFile.allCases, id: \.self) { file in
                    Text(MemoryCopy.tabTitle(file, languageCode: languageCode)).tag(file)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(MemoryCopy.tabHelp(model.selected, languageCode: languageCode))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                TextEditor(text: textBinding)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                if model.selected == .soul, (model.texts[.soul] ?? "").isEmpty {
                    Text(ChatPromptBuilder.defaultSystemPrompt(languageCode: languageCode))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))

            HStack {
                Button(copy(.openInFinder)) { model.revealInFinder() }
                Spacer()
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(copy(.revert)) { model.revert() }
                    .disabled(!model.isDirty(model.selected))
                Button(copy(.save)) { model.save(languageCode: languageCode) }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!model.isDirty(model.selected))
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 460)
    }
}
