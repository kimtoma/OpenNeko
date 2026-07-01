import AppKit
import SwiftUI
import OpenNekoKit

final class ChatHistoryWindowController {
    struct State {
        let messages: [ChatMessage]
        let languageCode: String
    }

    private var window: NSWindow?

    func show(state: State) {
        let root = ChatHistoryView(state: state)
        if let window {
            (window.contentViewController as? NSHostingController<ChatHistoryView>)?.rootView = root
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = ChatHistoryCopy.title(languageCode: state.languageCode)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 360, height: 420)
        window.setContentSize(NSSize(width: 460, height: 560))
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refresh(state: State) {
        guard let window,
              let hosting = window.contentViewController as? NSHostingController<ChatHistoryView>
        else { return }
        window.title = ChatHistoryCopy.title(languageCode: state.languageCode)
        hosting.rootView = ChatHistoryView(state: state)
    }
}

private struct ChatHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var copiedIndex: Int?
    let state: ChatHistoryWindowController.State

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if state.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .frame(minWidth: 360, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(ChatHistoryCopy.title(languageCode: state.languageCode))
                    .font(.headline)
                Text(ChatHistoryCopy.subtitle(languageCode: state.languageCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text(ChatHistoryCopy.empty(languageCode: state.languageCode))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(state.messages.enumerated()), id: \.offset) { index, message in
                        ChatHistoryRow(
                            index: index,
                            message: message,
                            languageCode: state.languageCode,
                            isCopied: copiedIndex == index,
                            copy: copy
                        )
                        .id(index)
                    }
                }
                .padding(14)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: state.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = state.messages.indices.last else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(last, anchor: .bottom)
        }
    }

    private func copy(_ text: String, index: Int) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedIndex == index {
                copiedIndex = nil
            }
        }
    }
}

private struct ChatHistoryRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let index: Int
    let message: ChatMessage
    let languageCode: String
    let isCopied: Bool
    let copy: (String, Int) -> Void

    private var isAssistant: Bool {
        message.role == .assistant
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isAssistant ? "sparkles" : "person")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(ChatHistoryCopy.role(message.role, languageCode: languageCode))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isAssistant {
                Button {
                    copy(message.text, index)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(ChatHistoryCopy.copyHelp(languageCode: languageCode))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowFill)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            guard isAssistant else { return }
            copy(message.text, index)
        }
        .help(isAssistant ? ChatHistoryCopy.copyHelp(languageCode: languageCode) : "")
    }

    private var rowFill: Color {
        if isAssistant {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
        return colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025)
    }
}

private enum ChatHistoryCopy {
    static func title(languageCode: String?) -> String {
        localized(languageCode, ko: "대화 내역", en: "Chat History", ja: "会話履歴", zh: "对话历史")
    }

    static func subtitle(languageCode: String?) -> String {
        localized(
            languageCode,
            ko: "로컬 Markdown에 저장된 openNeko 대화",
            en: "openNeko chats saved as local Markdown",
            ja: "ローカルMarkdownに保存されたopenNeko会話",
            zh: "保存为本地 Markdown 的 openNeko 对话"
        )
    }

    static func empty(languageCode: String?) -> String {
        localized(languageCode, ko: "아직 대화가 없다냥", en: "No chat yet, nya.", ja: "まだ会話がないにゃ", zh: "还没有对话喵")
    }

    static func copyHelp(languageCode: String?) -> String {
        NekoBubbleCopy.copyReplyHelp(languageCode: languageCode)
    }

    static func role(_ role: ChatRole, languageCode: String?) -> String {
        switch role {
        case .user:
            localized(languageCode, ko: "나", en: "Me", ja: "自分", zh: "我")
        case .assistant:
            localized(languageCode, ko: "네꼬", en: "Neko", ja: "ネコ", zh: "Neko")
        }
    }

    private static func localized(
        _ languageCode: String?,
        ko: String,
        en: String,
        ja: String,
        zh: String
    ) -> String {
        switch AppLanguage.normalized(languageCode) ?? "ko" {
        case "en": en
        case "ja": ja
        case "zh": zh
        default: ko
        }
    }
}
