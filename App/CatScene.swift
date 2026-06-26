import SpriteKit
import OpenNekoKit

final class CatScene: SKScene {
    private let sprite = SKSpriteNode()
    private var skin: Skin?
    private var currentState: CatState?
    private let timePerFrame = 0.18

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .aspectFit
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.texture?.filteringMode = .nearest   // 픽셀아트 선명하게
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func apply(skin: Skin) {
        self.skin = skin
        currentState = nil
        play(state: .idle)
    }

    func play(state: CatState) {
        guard state != currentState else { return }
        guard let skin else { return }
        let urls = skin.frameURLs(for: state.rawValue)
        let textures: [SKTexture] = urls.compactMap { url in
            guard let img = NSImage(contentsOf: url) else { return nil }
            let t = SKTexture(image: img)
            t.filteringMode = .nearest
            return t
        }
        guard !textures.isEmpty else { return }  // 빈 프레임이면 기존 유지
        currentState = state
        sprite.size = textures[0].size()
        sprite.removeAllActions()
        if textures.count == 1 {
            sprite.texture = textures[0]
        } else {
            let anim = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: true, restore: false)
            sprite.run(SKAction.repeatForever(anim))
        }
    }
}
