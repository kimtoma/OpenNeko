import AppKit
import SwiftUI
import OpenNekoKit

private final class CatChatNSWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CatChatWindow {
    private weak var parentWindow: NSWindow?
    private var window: NSWindow?
    private let chatWidth: CGFloat = 320
    private let baseHeight: CGFloat = 64
    private let maxVisibleSuggestionRows = 6
    private var currentSuggestionCount = 0
    private let onSend: (String) -> Void
    private let onCancel: () -> Void
    private let slashCommands: () -> [SlashCommandDescriptor]
    var onFrameChanged: (() -> Void)?
    var isVisible: Bool {
        window?.isVisible == true
    }
    var visibleFrame: NSRect? {
        guard let window, window.isVisible else { return nil }
        return window.frame
    }

    init(
        parentWindow: NSWindow,
        onSend: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        slashCommands: @escaping () -> [SlashCommandDescriptor]
    ) {
        self.parentWindow = parentWindow
        self.onSend = onSend
        self.onCancel = onCancel
        self.slashCommands = slashCommands
    }

    func show(placeholder: String = NekoBubbleCopy.chatPlaceholder(languageCode: nil)) {
        currentSuggestionCount = 0
        let root = CatChatView(
            placeholder: placeholder,
            slashCommands: slashCommands(),
            onSend: { [weak self] text in
                self?.hide()
                self?.onSend(text)
            },
            onCancel: { [weak self] in
                self?.hide()
                self?.onCancel()
            },
            onSuggestionCountChanged: { [weak self] count in
                self?.resizeForSuggestions(count)
            }
        )

        if let window {
            (window.contentViewController as? NSHostingController<CatChatView>)?.rootView = root
        } else {
            let hosting = NSHostingController(rootView: root)
            let window = CatChatNSWindow(
                contentRect: NSRect(origin: .zero, size: currentSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            self.window = window
        }

        reposition()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        focusTextField()
        NSLog("[openNeko] chat input shown")
    }

    func hide() {
        window?.orderOut(nil)
        onFrameChanged?()
    }

    func captureItem() -> WindowCaptureItem? {
        window?.openNekoCaptureItem()
    }

    func reposition() {
        guard let parentWindow, let window else { return }
        let parentFrame = (parentWindow as? CatWindow)?.catScreenFrame ?? parentWindow.frame
        let size = currentSize
        var origin = NSPoint(
            x: parentFrame.midX - size.width / 2,
            y: parentFrame.maxY + 8
        )

        if let visibleFrame = parentWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            origin.x = min(max(origin.x, visibleFrame.minX + 10), visibleFrame.maxX - size.width - 10)
            origin.y = min(max(origin.y, visibleFrame.minY + 10), visibleFrame.maxY - size.height - 10)
        }
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private var currentSize: NSSize {
        let suggestionHeight: CGFloat
        if currentSuggestionCount == 0 {
            suggestionHeight = 0
        } else {
            let rows = CGFloat(currentSuggestionCount) * 28
            let gaps = CGFloat(max(currentSuggestionCount - 1, 0)) * 2
            suggestionHeight = 8 + 8 + rows + gaps
        }
        return NSSize(
            width: chatWidth,
            height: baseHeight + suggestionHeight
        )
    }

    private func resizeForSuggestions(_ count: Int) {
        let next = min(max(count, 0), maxVisibleSuggestionRows)
        guard next != currentSuggestionCount else { return }
        currentSuggestionCount = next
        reposition()
        onFrameChanged?()
    }

    private func focusTextField() {
        guard let window else { return }
        DispatchQueue.main.async {
            if let textField = window.contentView?.firstDescendant(of: NSTextField.self) {
                window.makeFirstResponder(textField)
                textField.currentEditor()?.moveToEndOfLine(nil)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let textField = window.contentView?.firstDescendant(of: NSTextField.self) {
                window.makeFirstResponder(textField)
            }
        }
    }
}

private struct CatChatView: View {
    private let maxVisibleSuggestionRows = 6
    @Environment(\.colorScheme) private var colorScheme
    @State private var text = ""
    @State private var selectedSuggestionIndex = 0
    @State private var suppressSuggestions = false
    @FocusState private var isFocused: Bool
    let placeholder: String
    let slashCommands: [SlashCommandDescriptor]
    let onSend: (String) -> Void
    let onCancel: () -> Void
    let onSuggestionCountChanged: (Int) -> Void

    var body: some View {
        OpenNekoGlassContainer {
            VStack(spacing: 6) {
                if !visibleSuggestions.isEmpty {
                    suggestionList
                }

                HStack(spacing: 8) {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit(send)
                        .font(.body)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(fieldFill)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(fieldStroke, lineWidth: 1)
                        }

                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle()
                                    .fill(sendButtonFill)
                            }
                            .overlay {
                                Circle()
                                    .stroke(sendButtonStroke, lineWidth: 1)
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .help("보내기")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(panelFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(panelStroke, lineWidth: 1)
                }
                .openNekoGlass(cornerRadius: 18, interactive: true)
            }
        }
        .frame(width: 320, alignment: .bottom)
        .padding(.bottom, 8)
        .onExitCommand(perform: cancelOrCloseSuggestions)
        .onMoveCommand(perform: moveSuggestionSelection)
        .onChange(of: text) { _, _ in
            suppressSuggestions = false
            selectedSuggestionIndex = 0
            notifySuggestionCount()
        }
        .onChange(of: visibleSuggestions.count) { _, _ in
            selectedSuggestionIndex = min(selectedSuggestionIndex, max(visibleSuggestions.count - 1, 0))
            notifySuggestionCount()
        }
        .onAppear {
            notifySuggestionCount()
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }

    private var panelFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.11) : Color.white.opacity(0.38)
    }

    private var panelStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.54)
    }

    private var fieldFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.44)
    }

    private var fieldStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
    }

    private var sendButtonFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08)
    }

    private var sendButtonStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.12)
    }

    private var visibleSuggestions: [SlashCommandDescriptor] {
        guard !suppressSuggestions, text.first == "/" else { return [] }
        let rawPrefix = text.dropFirst()
        guard !rawPrefix.contains(where: \.isWhitespace) else { return [] }
        return SlashCommandParser.matchingCommands(prefix: String(rawPrefix), catalog: slashCommands)
    }

    private var suggestionList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(visibleSuggestions.enumerated()), id: \.element.name) { index, command in
                        Button {
                            complete(command)
                        } label: {
                            HStack(spacing: 8) {
                                Text("/\(command.name)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(command.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background {
                                if index == selectedSuggestionIndex {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.primary.opacity(0.08))
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(command.name)
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: suggestionListHeight)
            .scrollIndicators(.visible)
            .onChange(of: selectedSuggestionIndex) { _, index in
                guard let command = visibleSuggestions[safe: index] else { return }
                withAnimation(.snappy(duration: 0.12)) {
                    proxy.scrollTo(command.name, anchor: .center)
                }
            }
        }
        .openNekoGlass(cornerRadius: 12, interactive: true)
    }

    private var suggestionListHeight: CGFloat {
        let rows = CGFloat(min(visibleSuggestions.count, maxVisibleSuggestionRows))
        let gaps = CGFloat(max(min(visibleSuggestions.count, maxVisibleSuggestionRows) - 1, 0)) * 2
        return 8 + rows * 28 + gaps
    }

    private func send() {
        if let selected = visibleSuggestions[safe: selectedSuggestionIndex] ?? visibleSuggestions.first {
            complete(selected)
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(String(trimmed.prefix(2_000)))
        text = ""
    }

    private func complete(_ command: SlashCommandDescriptor) {
        text = "/\(command.name) "
        suppressSuggestions = true
        selectedSuggestionIndex = 0
        notifySuggestionCount()
    }

    private func cancelOrCloseSuggestions() {
        if !visibleSuggestions.isEmpty {
            suppressSuggestions = true
            notifySuggestionCount()
        } else {
            onCancel()
        }
    }

    private func moveSuggestionSelection(_ direction: MoveCommandDirection) {
        guard !visibleSuggestions.isEmpty else { return }
        switch direction {
        case .down:
            selectedSuggestionIndex = min(selectedSuggestionIndex + 1, visibleSuggestions.count - 1)
        case .up:
            selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0)
        default:
            break
        }
    }

    private func notifySuggestionCount() {
        onSuggestionCountChanged(visibleSuggestions.count)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension NSView {
    func firstDescendant<ViewType: NSView>(of type: ViewType.Type) -> ViewType? {
        if let match = self as? ViewType {
            return match
        }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type) {
                return match
            }
        }
        return nil
    }
}
