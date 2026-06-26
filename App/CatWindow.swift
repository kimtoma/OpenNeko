import AppKit
import SpriteKit
import OpenNekoKit

final class CatWindow: NSWindow {
    private let skView = SKView()
    private let scene: CatScene
    private let catSize = CGSize(width: 160, height: 160)

    init() {
        scene = CatScene(size: catSize)
        super.init(
            contentRect: NSRect(origin: .zero, size: catSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        skView.allowsTransparency = true
        skView.presentScene(scene)
        contentView = skView

        positionBottomRight()
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let margin: CGFloat = 24
        let x = vf.maxX - catSize.width - margin
        let y = vf.minY + margin
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showCat(skin: Skin) {
        scene.apply(skin: skin)
        scene.play(state: .idle)
        orderFrontRegardless()
    }

    func toggle() {
        if isVisible { orderOut(nil) } else { orderFrontRegardless() }
    }
}
