import AppKit
import QuartzCore
import SpriteKit
import SwiftUI
import OpenNekoKit

private final class GuestCatSKView: SKView {
    var onClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private var tracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let tracking {
            removeTrackingArea(tracking)
        }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        tracking = next
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseUp(with event: NSEvent) {
        guard event.buttonNumber == 0 else { return }
        onClick?()
    }
}

final class GuestCatWindow: NSWindow {
    private static let catSize = CatLayoutMetrics.guestCatSize
    private static let floorMargin = CatLayoutMetrics.floorPadding

    private let skView = GuestCatSKView()
    private let scene: CatScene
    private var bubbleWindow: CatBubbleWindow!
    private let nameWindow = GuestNameWindow()
    private var visitTimer: Timer?
    private var leaveDeadline: TimeInterval = 0
    private var isLeaving = false
    private var languageCode: String?
    private(set) var peer: NeighborPeer

    var onWave: ((NeighborPeer) -> Void)?
    var onVisitExpired: ((NeighborPeer) -> Void)?

    init(peer: NeighborPeer, skin: Skin, languageCode: String?, near parentWindow: NSWindow) {
        self.peer = peer
        self.languageCode = languageCode
        scene = CatScene(size: Self.catSize)
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.catSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = parentWindow.level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 60
        skView.ignoresSiblingOrder = true
        skView.wantsLayer = true
        skView.layer?.magnificationFilter = .nearest
        skView.layer?.minificationFilter = .nearest
        skView.presentScene(scene)
        skView.onClick = { [weak self] in
            guard let self else { return }
            self.scene.playOnce(state: .jump)
            self.onWave?(self.peer)
        }
        skView.onHoverChanged = { [weak self] hovering in
            guard let self, !self.isLeaving else { return }
            if hovering, self.scene.displayedState == .idle {
                self.scene.play(state: .hover)
            } else if !hovering, self.scene.displayedState == .hover {
                self.scene.play(state: NeighborEventPresentation.presenceState(for: self.peer.presence))
            }
        }
        contentView = skView
        bubbleWindow = CatBubbleWindow(parentWindow: self)
        scene.apply(skin: skin)
        reposition(near: parentWindow, animated: false)
    }

    deinit {
        visitTimer?.invalidate()
    }

    func enter(near parentWindow: NSWindow) {
        guard let visibleFrame = parentWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let target = targetOrigin(near: parentWindow)
        let anchorFrame = Self.anchorFrame(for: parentWindow)
        let fromLeft = target.x < anchorFrame.midX
        let startX = fromLeft ? visibleFrame.minX - frame.width - 8 : visibleFrame.maxX + 8
        setFrameOrigin(NSPoint(x: startX, y: target.y))
        orderFrontRegardless()
        scene.play(state: .walk)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrameOrigin(target)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.scene.play(state: NeighborEventPresentation.presenceState(for: self.peer.presence))
            self.showName()
        })
        resetVisitTimer()
    }

    func update(peer: NeighborPeer, skin: Skin, languageCode: String?, near parentWindow: NSWindow) {
        self.peer = peer
        self.languageCode = languageCode
        scene.apply(skin: skin)
        scene.play(state: NeighborEventPresentation.presenceState(for: peer.presence))
        reposition(near: parentWindow, animated: true)
        showName()
    }

    func updatePresence(_ presence: NeighborPresence) {
        peer.presence = presence
        guard !isLeaving else { return }
        scene.play(state: NeighborEventPresentation.presenceState(for: presence))
    }

    func showBubble(_ text: String) {
        bubbleWindow.show(text: text)
        extendVisitTimer()
    }

    func setAlwaysOnTopEnabled(_ enabled: Bool) {
        level = enabled ? .floating : .normal
        nameWindow.setLevel(level)
    }

    func reposition(near parentWindow: NSWindow, animated: Bool) {
        let target = targetOrigin(near: parentWindow)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrameOrigin(target)
            }
        } else {
            setFrameOrigin(target)
        }
        bubbleWindow.reposition()
        nameWindow.reposition(parentFrame: NSRect(origin: target, size: frame.size))
    }

    func leave(near parentWindow: NSWindow?, completion: @escaping () -> Void) {
        guard !isLeaving else { return }
        isLeaving = true
        visitTimer?.invalidate()
        visitTimer = nil
        bubbleWindow.hide()
        nameWindow.hide()
        scene.play(state: .walk)

        let visibleFrame = parentWindow?.screen?.visibleFrame ?? screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let exitX: CGFloat
        if let visibleFrame {
            exitX = frame.midX < visibleFrame.midX ? visibleFrame.minX - frame.width - 8 : visibleFrame.maxX + 8
        } else {
            exitX = frame.minX
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.42
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().setFrameOrigin(NSPoint(x: exitX, y: frame.minY))
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            completion()
        })
    }

    private func showName() {
        nameWindow.show(
            name: NeighborEventPresentation.displayName(for: peer, languageCode: languageCode),
            parentFrame: frame,
            level: level
        )
    }

    private func resetVisitTimer() {
        scheduleVisit(until: ProcessInfo.processInfo.systemUptime + NeighborEventPresentation.guestVisitDuration)
    }

    private func extendVisitTimer() {
        let now = ProcessInfo.processInfo.systemUptime
        scheduleVisit(until: max(leaveDeadline, now + NeighborEventPresentation.guestBubbleExtension))
    }

    private func scheduleVisit(until deadline: TimeInterval) {
        leaveDeadline = deadline
        visitTimer?.invalidate()
        let delay = max(0.1, deadline - ProcessInfo.processInfo.systemUptime)
        visitTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.onVisitExpired?(self.peer)
        }
    }

    private func targetOrigin(near parentWindow: NSWindow) -> NSPoint {
        let parentFrame = Self.anchorFrame(for: parentWindow)
        guard let visibleFrame = parentWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            return NSPoint(x: parentFrame.minX - frame.width - 18, y: parentFrame.minY)
        }

        let gap: CGFloat = 18
        let roomLeft = parentFrame.minX - visibleFrame.minX
        let roomRight = visibleFrame.maxX - parentFrame.maxX
        let placeLeft = roomLeft >= frame.width + gap || roomLeft >= roomRight

        var x = placeLeft ? parentFrame.minX - frame.width - gap : parentFrame.maxX + gap
        x = min(max(x, visibleFrame.minX + 10), visibleFrame.maxX - frame.width - 10)

        var y = parentFrame.minY
        y = min(max(y, visibleFrame.minY + Self.floorMargin), visibleFrame.maxY - frame.height - 10)
        return NSPoint(x: x, y: y)
    }

    private static func anchorFrame(for parentWindow: NSWindow) -> NSRect {
        (parentWindow as? CatWindow)?.catScreenFrame ?? parentWindow.frame
    }
}

private final class GuestNameWindow {
    private var window: NSWindow?
    private let size = NSSize(width: 170, height: 30)

    func show(name: String, parentFrame: NSRect, level: NSWindow.Level) {
        let root = GuestNameView(name: name)
        if let window {
            (window.contentViewController as? NSHostingController<GuestNameView>)?.rootView = root
        } else {
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            self.window = window
        }

        setLevel(level)
        reposition(parentFrame: parentFrame)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    func setLevel(_ level: NSWindow.Level) {
        window?.level = level
    }

    func reposition(parentFrame: NSRect) {
        guard let window else { return }
        var origin = NSPoint(
            x: parentFrame.midX - size.width / 2,
            y: parentFrame.minY - size.height + 8
        )
        if let visibleFrame = NSScreen.main?.visibleFrame {
            origin.x = min(max(origin.x, visibleFrame.minX + 10), visibleFrame.maxX - size.width - 10)
            origin.y = min(max(origin.y, visibleFrame.minY + 10), visibleFrame.maxY - size.height - 10)
        }
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}

private struct GuestNameView: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .frame(width: 170, height: 24)
            .openNekoGlass(cornerRadius: 12)
            .padding(.vertical, 3)
    }
}
