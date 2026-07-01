import AppKit
import SwiftUI

final class CatBubbleWindow {
    private weak var parentWindow: NSWindow?
    private var window: NSWindow?
    private var hideTimer: Timer?
    private let minimumBubbleWidth: CGFloat = 132
    private let maximumBubbleWidth: CGFloat = 224
    private let minimumTextHeight: CGFloat = 24
    private let maximumTextHeight: CGFloat = 148
    private let horizontalPadding: CGFloat = 12
    private let verticalPadding: CGFloat = 8
    private let tailPadding: CGFloat = 7
    private var currentWidth: CGFloat = 132
    private var currentTextHeight: CGFloat = 24
    private let defaultOnClick: (() -> Void)?

    init(parentWindow: NSWindow, onClick: (() -> Void)? = nil) {
        self.parentWindow = parentWindow
        self.defaultOnClick = onClick
    }

    func show(
        text: String,
        onClick: (() -> Void)? = nil,
        helpText: String? = nil
    ) {
        hideTimer?.invalidate()
        let metrics = metrics(for: text)
        currentWidth = metrics.width
        currentTextHeight = metrics.textHeight
        let clickAction = onClick ?? defaultOnClick
        let root = CatBubbleView(
            text: text,
            width: metrics.width,
            textHeight: metrics.textHeight,
            isScrollable: metrics.isScrollable,
            onClick: clickAction,
            helpText: helpText ?? (clickAction == nil ? "" : "채팅 이어가기")
        )

        if let window {
            (window.contentViewController as? NSHostingController<CatBubbleView>)?.rootView = root
            window.ignoresMouseEvents = clickAction == nil
        } else {
            let hosting = CatBubbleHostingController(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: currentSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = clickAction == nil
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.applyOpenNekoOverlayWindowPolicy()
            self.window = window
        }

        reposition()
        window?.orderFrontRegardless()
        NSLog("[openNeko] bubble shown text=\(text)")
        hideTimer = Timer.scheduledTimer(withTimeInterval: metrics.duration, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
    }

    func captureItem() -> WindowCaptureItem? {
        window?.openNekoCaptureItem()
    }

    func reposition(avoiding avoidFrame: NSRect? = nil) {
        guard let parentWindow, let window else { return }
        let parentFrame = (parentWindow as? CatWindow)?.catScreenFrame ?? parentWindow.frame
        let size = currentSize
        var origin = NSPoint(
            x: parentFrame.midX - size.width / 2,
            y: parentFrame.maxY - 2
        )

        if let visibleFrame = parentWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            if let avoidFrame {
                origin = nonOverlappingOrigin(
                    proposed: origin,
                    size: size,
                    avoidFrame: avoidFrame,
                    visibleFrame: visibleFrame
                )
            }
            origin.x = min(max(origin.x, visibleFrame.minX + 10), visibleFrame.maxX - size.width - 10)
            origin.y = min(max(origin.y, visibleFrame.minY + 10), visibleFrame.maxY - size.height - 10)
        }
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func nonOverlappingOrigin(
        proposed: NSPoint,
        size: NSSize,
        avoidFrame: NSRect,
        visibleFrame: NSRect
    ) -> NSPoint {
        let gap: CGFloat = 8
        let paddedAvoidFrame = avoidFrame.insetBy(dx: -gap, dy: -gap)
        let proposedFrame = NSRect(origin: proposed, size: size)
        guard proposedFrame.intersects(paddedAvoidFrame) else { return proposed }

        var origin = proposed
        let aboveY = paddedAvoidFrame.maxY + gap
        let belowY = paddedAvoidFrame.minY - size.height - gap
        if aboveY + size.height <= visibleFrame.maxY - 10 {
            origin.y = aboveY
        } else if belowY >= visibleFrame.minY + 10 {
            origin.y = belowY
        } else {
            let aboveOverflow = aboveY + size.height - (visibleFrame.maxY - 10)
            let belowOverflow = (visibleFrame.minY + 10) - belowY
            origin.y = aboveOverflow <= belowOverflow ? aboveY : belowY
        }
        return origin
    }

    private var currentSize: NSSize {
        let height = max(
            48,
            currentTextHeight + verticalPadding * 2 + tailPadding
        )
        return NSSize(width: currentWidth, height: height)
    }

    private func metrics(for text: String) -> (width: CGFloat, textHeight: CGFloat, isScrollable: Bool, duration: TimeInterval) {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .center
        let attributed = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraph,
            ]
        )
        let singleLineWidth = ceil(attributed.boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 24),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).width)
        let width = min(
            maximumBubbleWidth,
            max(minimumBubbleWidth, singleLineWidth + horizontalPadding * 2 + 10)
        )
        let availableWidth = width - horizontalPadding * 2
        let measured = attributed.boundingRect(
            with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let naturalHeight = ceil(measured.height)
        let textHeight = min(max(naturalHeight, minimumTextHeight), maximumTextHeight)
        let extraReadTime = min(3.5, Double(text.count) / 90)
        return (
            width,
            textHeight,
            naturalHeight > maximumTextHeight,
            max(3.5, 4.2 + extraReadTime)
        )
    }
}

private final class CatBubbleHostingController: NSHostingController<CatBubbleView> {
    override func loadView() {
        view = FirstMouseHostingView(rootView: rootView)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct CatBubbleView: View {
    let text: String
    let width: CGFloat
    let textHeight: CGFloat
    let isScrollable: Bool
    let onClick: (() -> Void)?
    let helpText: String

    var body: some View {
        bubbleContent
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                onClick?()
            }
            .help(helpText)
    }

    private var bubbleContent: some View {
        Group {
            if isScrollable {
                ScrollView {
                    bubbleText
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            } else {
                bubbleText
            }
        }
        .frame(width: width - 24, height: textHeight, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: width)
        .background {
            bubbleShape
                .fill(.black.opacity(0.92))
        }
        .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            CompactBubbleTail()
                .offset(y: 6)
        }
        .padding(.bottom, 7)
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private var bubbleText: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
    }
}

private struct CompactBubbleTail: View {
    var body: some View {
        BubbleTailShape()
            .fill(.black.opacity(0.92))
            .frame(width: 16, height: 8)
    }
}

private struct BubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
