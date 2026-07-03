import AppKit
import SpriteKit
import OpenNekoKit

final class CatScene: SKScene {
    private let catNode = SKNode()
    private let sprite = SKSpriteNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 76, height: 9))
    private var skin: Skin?
    private var currentState: CatState?
    private var catFrameSize: CGSize
    private var typingAnimationSpeed: CGFloat = 1.0
    var displayedState: CatState { currentState ?? .idle }

    override init(size: CGSize) {
        catFrameSize = size
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .aspectFit
        addChild(catNode)
        shadow.fillColor = NSColor.black.withAlphaComponent(0.16)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: catFrameSize.width / 2, y: 5)
        shadow.zPosition = -1
        catNode.addChild(shadow)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.position = CGPoint(x: catFrameSize.width / 2, y: catFrameSize.height / 2)
        catNode.addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func setCatFrameSize(_ size: CGSize) {
        catFrameSize = size
        resetTransform()
    }

    func setCatOrigin(_ origin: CGPoint) {
        catNode.position = origin
    }

    func apply(skin: Skin) {
        self.skin = skin
        currentState = nil
        play(state: .idle)
    }

    func play(state: CatState) {
        applySpriteActionSpeed(for: state)
        guard state != currentState else { return }
        let textures = loadTextures(for: state)
        guard !textures.isEmpty else { return }  // 빈 프레임이면 기존 유지
        currentState = state
        resetTransform()
        shadow.isHidden = state == .dragging
        sprite.size = textures[0].size()
        sprite.removeAllActions()
        if textures.count == 1 {
            sprite.texture = textures[0]
        } else {
            let anim = SKAction.animate(with: textures, timePerFrame: timePerFrame(for: state), resize: true, restore: false)
            if state == .walk {
                sprite.run(SKAction.group([SKAction.repeatForever(anim), walkBobAction()]))
            } else {
                sprite.run(SKAction.repeatForever(anim))
            }
        }
    }

    func playWalk(direction: Int) {
        play(state: .walk)
        sprite.xScale = direction < 0 ? -1 : 1
    }

    func setTypingAnimationSpeed(_ speed: Double) {
        typingAnimationSpeed = CGFloat(CatAnimationTiming.clampedTypingSpeed(speed))
        if currentState == .typing {
            sprite.speed = typingAnimationSpeed
        }
    }

    /// 한 번만 재생한 뒤 idle로 복귀. 클릭 반응 같은 일회성 동작에 사용.
    func playOnce(state: CatState) {
        let textures = loadTextures(for: state)
        guard !textures.isEmpty else { return }
        currentState = state
        resetTransform()
        shadow.isHidden = false
        sprite.size = textures[0].size()
        sprite.removeAllActions()
        sprite.speed = 1.0
        let anim = SKAction.animate(with: textures, timePerFrame: timePerFrame(for: state), resize: true, restore: false)
        let action: SKAction
        if state == .jump {
            let lift = SKAction.moveBy(x: 0, y: 23, duration: 0.18)
            lift.timingMode = .easeOut
            let settle = SKAction.moveBy(x: 0, y: -23, duration: 0.20)
            settle.timingMode = .easeIn
            action = SKAction.group([anim, SKAction.sequence([lift, settle])])
        } else {
            action = anim
        }
        let backToIdle = SKAction.run { [weak self] in
            self?.currentState = nil
            self?.play(state: .idle)
        }
        sprite.run(SKAction.sequence([action, backToIdle]))
    }

    func showDragging(horizontalVelocity: CGFloat, horizontalAcceleration: CGFloat, time: TimeInterval) {
        let textures = loadTextures(for: .dragging)
        guard !textures.isEmpty else { return }
        currentState = .dragging
        shadow.isHidden = true
        sprite.removeAllActions()
        sprite.speed = 1.0
        let index = min(
            CatDragGeometry.dangleFrameIndex(
                horizontalVelocity: horizontalVelocity,
                horizontalAcceleration: horizontalAcceleration,
                time: time
            ),
            textures.count - 1
        )
        sprite.texture = textures[index]
        sprite.size = textures[index].size()
        pinSpriteForDragging(
            offset: CatDragGeometry.dangleBodyOffset(
                horizontalVelocity: horizontalVelocity,
                horizontalAcceleration: horizontalAcceleration,
                time: time
            )
        )
        sprite.zRotation = CatDragGeometry.dangleSwingAngle(
            horizontalVelocity: horizontalVelocity,
            horizontalAcceleration: horizontalAcceleration,
            time: time
        )
    }

    func showFalling() {
        let textures = loadTextures(for: .dragging)
        guard let texture = textures.first else {
            play(state: .dragging)
            return
        }
        currentState = .dragging
        shadow.isHidden = true
        sprite.removeAllActions()
        sprite.speed = 1.0
        sprite.texture = texture
        sprite.size = texture.size()
        pinSpriteForDragging()
        sprite.zRotation = 0
    }

    /// 착지 순간 살짝 찌그러졌다 펴지는 효과.
    func landingSquash() {
        shadow.isHidden = false
        let bottomY = sprite.position.y - sprite.size.height / 2
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: catFrameSize.width / 2, y: bottomY)
        let squash = SKAction.scaleX(to: 1.12, y: 0.88, duration: 0.06)
        let recover = SKAction.scale(to: 1.0, duration: 0.10)
        recover.timingMode = .easeOut
        let reset = SKAction.run { [weak self] in
            self?.resetTransform()
        }
        sprite.run(SKAction.sequence([squash, recover, reset]))
    }

    func capturePNGData() -> Data? {
        guard let texture = view?.texture(from: self) else {
            return nil
        }
        let image = texture.cgImage()
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .png, properties: [:])
    }

    private func loadTextures(for state: CatState) -> [SKTexture] {
        guard let skin else { return [] }
        return skin.frameURLs(for: state.rawValue).compactMap { url in
            guard let img = NSImage(contentsOf: url) else { return nil }
            let t = SKTexture(image: img)
            t.filteringMode = .nearest
            return t
        }
    }

    private func resetTransform() {
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.zRotation = 0
        sprite.setScale(1)
        sprite.position = CGPoint(x: catFrameSize.width / 2, y: catFrameSize.height / 2)
        shadow.position = CGPoint(x: catFrameSize.width / 2, y: 5)
    }

    private func applySpriteActionSpeed(for state: CatState) {
        sprite.speed = state == .typing ? typingAnimationSpeed : 1.0
    }

    private func pinSpriteForDragging(offset: CGPoint = .zero) {
        sprite.anchorPoint = CGPoint(x: 0.5, y: 1)
        sprite.setScale(1)
        sprite.position = CGPoint(
            x: catFrameSize.width / 2 + offset.x,
            y: catFrameSize.height - CatDragGeometry.defaultPinOffsetY + offset.y
        )
    }

    private func timePerFrame(for state: CatState) -> TimeInterval {
        CatAnimationTiming.timePerFrame(for: state)
    }

    private func walkBobAction() -> SKAction {
        let down = SKAction.moveBy(x: 0, y: -2, duration: 0.12)
        down.timingMode = .linear
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.12)
        up.timingMode = .linear
        return SKAction.repeatForever(SKAction.sequence([down, up]))
    }
}
