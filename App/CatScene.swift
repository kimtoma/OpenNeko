import AppKit
import SpriteKit
import OpenNekoKit

final class CatScene: SKScene {
    /// Optional, local to a skin directory; never inherited with SpriteManifest.
    /// Insets are measured in source-canvas pixels and scale with the texture.
    private struct SkinRenderInfo: Decodable {
        enum Filtering: String, Decodable { case nearest, linear }
        enum PunchFacing: String, Decodable { case left, right }

        let version: Int
        let canvasHeight: CGFloat
        let bottomInset: CGFloat
        let dragTopInset: CGFloat?
        let displayHeight: CGFloat?
        let filtering: Filtering?
        let punchFacing: PunchFacing?

        var isValid: Bool {
            version == 1 && canvasHeight.isFinite && canvasHeight > 0
                && bottomInset.isFinite && bottomInset >= 0 && bottomInset < canvasHeight
                && (dragTopInset.map {
                    $0.isFinite && $0 >= 0 && $0 + bottomInset < canvasHeight
                } ?? true)
                && (displayHeight.map { $0.isFinite && $0 > 0 } ?? true)
        }

        var bottomAnchor: CGFloat { bottomInset / canvasHeight }
        var dragAnchor: CGFloat { 1 - (dragTopInset ?? 0) / canvasHeight }
        var textureFiltering: SKTextureFilteringMode { filtering == .linear ? .linear : .nearest }
    }

    /// The convex outline of nontransparent pixel cells, in bottom-left unit
    /// texture coordinates. Cache it at decode time: rotating the canvas or an
    /// axis-aligned alpha rectangle would also constrain empty corner padding.
    private struct DragAlphaBounds {
        private let outline: [CGPoint]

        init?(image: CGImage) {
            let width = image.width, height = image.height
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ), let data = context.data else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let bytes = data.assumingMemoryBound(to: UInt8.self)
            var points: [CGPoint] = []
            points.reserveCapacity(height * 4)
            for row in 0..<height {
                var first = width, last = -1
                for column in 0..<width where bytes[row * context.bytesPerRow + column * 4 + 3] > 0 {
                    first = min(first, column)
                    last = column
                }
                guard last >= first else { continue }
                // The normalized bitmap rows run top to bottom; SpriteKit's
                // local y axis runs upward. Include the whole visible pixel.
                let bottom = CGFloat(height - row - 1), top = CGFloat(height - row)
                points.append(CGPoint(x: CGFloat(first), y: bottom))
                points.append(CGPoint(x: CGFloat(first), y: top))
                points.append(CGPoint(x: CGFloat(last + 1), y: bottom))
                points.append(CGPoint(x: CGFloat(last + 1), y: top))
            }
            guard !points.isEmpty else { return nil }
            points.sort { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
            func turn(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
                (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
            }
            var hull: [CGPoint] = []
            for point in points {
                while hull.count >= 2 && turn(hull[hull.count - 2], hull[hull.count - 1], point) <= 0 {
                    hull.removeLast()
                }
                hull.append(point)
            }
            let lowerCount = hull.count
            for point in points.dropLast().reversed() {
                while hull.count > lowerCount && turn(hull[hull.count - 2], hull[hull.count - 1], point) <= 0 {
                    hull.removeLast()
                }
                hull.append(point)
            }
            hull.removeLast()
            outline = hull.map { CGPoint(x: $0.x / CGFloat(width), y: $0.y / CGFloat(height)) }
        }

        func constrainedPosition(
            _ position: CGPoint, size: CGSize, anchor: CGPoint,
            rotation: CGFloat, frameSize: CGSize
        ) -> CGPoint {
            let cosine = cos(rotation), sine = sin(rotation)
            var minX = CGFloat.infinity, minY = CGFloat.infinity
            var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
            for point in outline {
                let x = (point.x - anchor.x) * size.width
                let y = (point.y - anchor.y) * size.height
                let rotatedX = position.x + x * cosine - y * sine
                let rotatedY = position.y + x * sine + y * cosine
                minX = min(minX, rotatedX)
                maxX = max(maxX, rotatedX)
                minY = min(minY, rotatedY)
                maxY = max(maxY, rotatedY)
            }
            func correction(minimum: CGFloat, maximum: CGFloat, extent: CGFloat) -> CGFloat {
                let lower = 1 - minimum, upper = extent - 1 - maximum
                // Clamp zero into the feasible translation interval. Oversized
                // artwork cannot fit by translation alone; center that axis.
                return lower <= upper ? min(max(0, lower), upper) : (lower + upper) / 2
            }
            return CGPoint(
                x: position.x + correction(minimum: minX, maximum: maxX, extent: frameSize.width),
                y: position.y + correction(minimum: minY, maximum: maxY, extent: frameSize.height)
            )
        }
    }

    private let catNode = SKNode()
    private let sprite = SKSpriteNode()
    private let punchEffect = SKSpriteNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 76, height: 9))
    private var skin: Skin?
    // Keep only frames requested by this scene's current skin. Empty results are
    // cached too, so a missing frame cannot trigger disk reads on every drag tick.
    private var texturesByState: [CatState: [SKTexture]] = [:]
    private var dragAlphaBoundsByTexture: [ObjectIdentifier: DragAlphaBounds] = [:]
    private var punchEffectTextures: [SKTexture]?
    private var punchEffectUsesSkinFrames = false
    private var punchRenderInfo: SkinRenderInfo?
    private var renderInfo: SkinRenderInfo?
    private let groundedFootY: CGFloat = 2
    private var currentState: CatState?
    private var catFrameSize: CGSize
    private var typingAnimationSpeed: CGFloat = 1.0
    private var isPunching = false
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
        punchEffect.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        punchEffect.zPosition = 2
        punchEffect.isHidden = true
        catNode.addChild(punchEffect)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    static func frameSize(for skin: Skin) -> CGSize {
        let height = loadRenderInfo(in: skin.directory)?.displayHeight ?? CatLayoutMetrics.spriteFrameLength
        return CGSize(width: height, height: height)
    }

    func setCatFrameSize(_ size: CGSize) {
        cancelPunchSequence()
        catFrameSize = size
        self.size = size
        resetTransform()
    }

    func setCatOrigin(_ origin: CGPoint) {
        catNode.position = origin
    }

    func apply(skin: Skin) {
        cancelPunchSequence()
        self.skin = skin
        // Reapplying the same skin also refreshes files replaced on disk.
        texturesByState.removeAll(keepingCapacity: true)
        dragAlphaBoundsByTexture.removeAll(keepingCapacity: true)
        punchEffectTextures = nil
        punchEffectUsesSkinFrames = false
        punchRenderInfo = nil
        renderInfo = Self.loadRenderInfo(in: skin.directory)
        currentState = nil
        play(state: .idle)
    }

    func play(state: CatState) {
        cancelPunchSequence()
        applySpriteActionSpeed(for: state)
        guard state != currentState else { return }
        let textures = loadTextures(for: state)
        guard !textures.isEmpty else { return }  // 빈 프레임이면 기존 유지
        currentState = state
        sprite.removeAllActions()
        resetTransform(textureSize: textures[0].size())
        shadow.isHidden = state == .dragging
        if textures.count == 1 {
            sprite.texture = textures[0]
        } else {
            let anim = SKAction.animate(
                with: textures,
                timePerFrame: CatAnimationTiming.frameDuration(for: state, frameCount: textures.count),
                resize: renderInfo?.displayHeight == nil,
                restore: false
            )
            sprite.run(SKAction.repeatForever(anim), withKey: "frameAnimation")
            startWalkBob()
        }
    }

    func playWalk(direction: Int) {
        play(state: .walk)
        sprite.xScale = direction < 0 ? -1 : 1
    }

    func setTypingAnimationSpeed(_ speed: Double) {
        typingAnimationSpeed = CGFloat(min(1.8, max(0.8, speed)))
        if currentState == .typing {
            sprite.speed = typingAnimationSpeed
        }
    }

    /// 한 번만 재생한 뒤 idle로 복귀. 클릭 반응 같은 일회성 동작에 사용.
    func playOnce(state: CatState, direction: Int? = nil) {
        cancelPunchSequence()
        let textures = loadTextures(for: state)
        guard !textures.isEmpty else { return }
        currentState = state
        sprite.removeAllActions()
        resetTransform(textureSize: textures[0].size())
        if let direction {
            sprite.xScale = direction < 0 ? -1 : 1
        }
        shadow.isHidden = false
        sprite.speed = 1.0
        let anim = SKAction.animate(
            with: textures,
            timePerFrame: CatAnimationTiming.frameDuration(for: state, frameCount: textures.count),
            resize: renderInfo?.displayHeight == nil,
            restore: false
        )
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

    func playPunch(
        direction: Int,
        sequence: ScreenPetPunchSequence = .default
    ) {
        guard !isPunching else { return }
        let textures = loadPunchEffectTextures()
        if textures.isEmpty {
            playFallbackPunch(direction: direction, sequence: sequence)
        } else {
            playFullBodyPunch(textures: textures, direction: direction, sequence: sequence)
        }
    }

    func showDragging(horizontalVelocity: CGFloat, horizontalAcceleration: CGFloat, time: TimeInterval) {
        cancelPunchSequence()
        let textures = loadTextures(for: .dragging)
        guard !textures.isEmpty else { return }
        currentState = .dragging
        shadow.isHidden = true
        sprite.removeAllActions()
        sprite.speed = 1.0
        let index = CatDragGeometry.dangleFrameIndex(
            horizontalVelocity: horizontalVelocity,
            horizontalAcceleration: horizontalAcceleration,
            time: time,
            frameCount: textures.count
        )
        sprite.texture = textures[index]
        pinSpriteForDragging(
            offset: CatDragGeometry.dangleBodyOffset(
                horizontalVelocity: horizontalVelocity,
                horizontalAcceleration: horizontalAcceleration,
                time: time
            )
        )
        sprite.size = textures[index].size()
        sprite.zRotation = CatDragGeometry.dangleSwingAngle(
            horizontalVelocity: horizontalVelocity,
            horizontalAcceleration: horizontalAcceleration,
            time: time
        )
        keepDraggingVisible(texture: textures[index])
    }

    func showFalling() {
        cancelPunchSequence()
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
        pinSpriteForDragging()
        sprite.size = texture.size()
        sprite.zRotation = 0
        keepDraggingVisible(texture: texture)
    }

    /// 착지 순간 살짝 찌그러졌다 펴지는 효과.
    func landingSquash() {
        shadow.isHidden = false
        // Window-level walking can land while its frame animation continues.
        // Stop positional movement before changing the anchor for the squash.
        sprite.removeAction(forKey: "walkBob")
        let facing: CGFloat = currentState == .walk && sprite.xScale < 0 ? -1 : 1
        if let renderInfo {
            // Squash around the visible feet, not the transparent canvas edge.
            sprite.anchorPoint = CGPoint(x: 0.5, y: renderInfo.bottomAnchor)
            sprite.position = CGPoint(x: catFrameSize.width / 2, y: groundedFootY)
        } else {
            let height = sprite.texture?.size().height ?? sprite.size.height
            let bottomY = catFrameSize.height / 2 - height / 2
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = CGPoint(x: catFrameSize.width / 2, y: bottomY)
        }
        let squash = SKAction.scaleX(to: facing * 1.12, y: 0.88, duration: 0.06)
        let recover = SKAction.scaleX(to: facing, y: 1.0, duration: 0.10)
        recover.timingMode = .easeOut
        let reset = SKAction.run { [weak self] in
            guard let self else { return }
            let walkingDirection: CGFloat = sprite.xScale < 0 ? -1 : 1
            resetTransform()
            if currentState == .walk {
                sprite.xScale = walkingDirection
                startWalkBob()
            }
        }
        // A second landing replaces the first recovery, whose reset would
        // otherwise change the anchor in the middle of the newer squash.
        sprite.run(SKAction.sequence([squash, recover, reset]), withKey: "landingSquash")
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
        if let textures = texturesByState[state] {
            return textures
        }
        guard let skin else { return [] }
        let textures = skin.frameURLs(for: state.rawValue).compactMap { url in
            loadTexture(at: url, info: renderInfo,
                        cacheDragBounds: state == .dragging && renderInfo != nil)
        }
        texturesByState[state] = textures
        return textures
    }

    private func loadTexture(at url: URL, info: SkinRenderInfo?, cacheDragBounds: Bool = false) -> SKTexture? {
        guard let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data), let pixels = bitmap.cgImage else { return nil }
        // Invalid or absent metadata must not turn a 1024px PNG into a 1024pt cat.
        // NSImage's point size retains the full-resolution CGImage on the GPU.
        let displayHeight = info?.displayHeight
            ?? min(CGFloat(pixels.height), CatLayoutMetrics.spriteFrameLength)
        let points = CGSize(width: CGFloat(pixels.width) * displayHeight / CGFloat(pixels.height),
                            height: displayHeight)
        let image = NSImage(cgImage: pixels, size: points)
        let texture = SKTexture(image: image)
        texture.filteringMode = info?.textureFiltering ?? .nearest
        if cacheDragBounds, let bounds = DragAlphaBounds(image: pixels) {
            dragAlphaBoundsByTexture[ObjectIdentifier(texture)] = bounds
        }
        return texture
    }

    private static func loadRenderInfo(in directory: URL) -> SkinRenderInfo? {
        let url = directory.appendingPathComponent("render-info.json")
        guard let data = try? Data(contentsOf: url),
              let info = try? JSONDecoder().decode(SkinRenderInfo.self, from: data), info.isValid else {
            return nil
        }
        return info
    }

    private func loadPunchEffectTextures() -> [SKTexture] {
        if let textures = punchEffectTextures {
            return textures
        }
        let root = Bundle.main.resourceURL?
            .appendingPathComponent("sprites", isDirectory: true)
            .appendingPathComponent("effects", isDirectory: true)
        let info = root.flatMap { Self.loadRenderInfo(in: $0) }
        let textures = (0..<4).compactMap { index -> SKTexture? in
            guard let url = root?.appendingPathComponent("nyang_punch_\(index).png") else { return nil }
            return loadTexture(at: url, info: info)
        }
        punchEffectUsesSkinFrames = textures.count != 4
        punchRenderInfo = punchEffectUsesSkinFrames ? nil : info
        let resolvedTextures = punchEffectUsesSkinFrames ? loadTextures(for: .click) : textures
        // The fallback belongs to the selected skin, so apply(skin:) clears it.
        punchEffectTextures = resolvedTextures
        return resolvedTextures
    }

    private func playFullBodyPunch(
        textures: [SKTexture],
        direction: Int,
        sequence: ScreenPetPunchSequence
    ) {
        let presentation = ScreenPetPunchPresentation.fullBody(
            catFrameSize: catFrameSize,
            direction: direction
        )
        isPunching = true
        punchEffect.removeAllActions()
        punchEffect.isHidden = false
        punchEffect.texture = textures[0]
        punchEffect.size = presentation.size
        punchEffect.position = presentation.position
        if let info = punchEffectUsesSkinFrames ? renderInfo : punchRenderInfo {
            if info.displayHeight != nil {
                punchEffect.size = textures[0].size()
            } else if !punchEffectUsesSkinFrames {
                // New full-body sheets declare a square logical canvas. Older
                // effects retain the original enlarged presentation above.
                punchEffect.size = CGSize(width: info.canvasHeight, height: info.canvasHeight)
            }
            punchEffect.position.y = groundedCenterY(height: punchEffect.size.height, info: info)
        }
        // Legacy punch sheets face left. Only a complete dedicated effect set
        // can opt into right-facing artwork; skin click fallbacks keep their contract.
        let facesRight = !punchEffectUsesSkinFrames && punchRenderInfo?.punchFacing == .right
        punchEffect.xScale = facesRight ? -presentation.xScale : presentation.xScale
        punchEffect.yScale = presentation.yScale
        punchEffect.alpha = 1
        if presentation.hidesBaseSprite {
            sprite.isHidden = true
        }
        sprite.removeAllActions()
        currentState = .click
        shadow.isHidden = false
        var actions: [SKAction] = [SKAction.wait(forDuration: sequence.leadInDuration)]
        for index in 0..<sequence.punchCount {
            actions.append(SKAction.animate(
                with: textures,
                timePerFrame: CatAnimationTiming.frameDuration(
                    cycleDuration: sequence.singlePunchDuration,
                    frameCount: textures.count
                ),
                resize: false,
                restore: false
            ))
            if index < sequence.punchCount - 1 {
                actions.append(SKAction.wait(forDuration: sequence.recoveryDuration))
            }
        }
        actions.append(SKAction.wait(forDuration: sequence.settleDuration))
        actions.append(SKAction.run { [weak self] in
            self?.finishPunchSequence()
        })
        punchEffect.run(SKAction.sequence(actions))
    }

    private func playFallbackPunch(direction: Int, sequence: ScreenPetPunchSequence) {
        let textures = loadTextures(for: .click)
        guard !textures.isEmpty else { return }
        isPunching = true
        currentState = .click
        sprite.removeAllActions()
        resetTransform(textureSize: textures[0].size())
        sprite.xScale = direction < 0 ? -1 : 1
        shadow.isHidden = false
        sprite.speed = 1

        var actions: [SKAction] = [SKAction.wait(forDuration: sequence.leadInDuration)]
        for index in 0..<sequence.punchCount {
            actions.append(SKAction.animate(
                with: textures,
                timePerFrame: CatAnimationTiming.frameDuration(
                    cycleDuration: sequence.singlePunchDuration,
                    frameCount: textures.count
                ),
                resize: renderInfo?.displayHeight == nil,
                restore: false
            ))
            if index < sequence.punchCount - 1 {
                actions.append(SKAction.wait(forDuration: sequence.recoveryDuration))
            }
        }
        actions.append(SKAction.wait(forDuration: sequence.settleDuration))
        actions.append(SKAction.run { [weak self] in
            self?.finishPunchSequence()
        })
        sprite.run(SKAction.sequence(actions))
    }

    private func finishPunchSequence() {
        cancelPunchSequence()
        play(state: .idle)
    }

    private func cancelPunchSequence() {
        guard isPunching else { return }
        isPunching = false
        punchEffect.removeAllActions()
        sprite.isHidden = false
        punchEffect.isHidden = true
        punchEffect.alpha = 1
        punchEffect.xScale = 1
        punchEffect.yScale = 1
        currentState = nil
    }

    private func resetTransform(textureSize: CGSize? = nil) {
        sprite.isHidden = false
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.zRotation = 0
        sprite.setScale(1)
        // SKSpriteNode.size includes scale. Assign only after clearing a squash
        // so a state change or texture resize cannot retain an enlarged canvas.
        if let size = textureSize ?? sprite.texture?.size() {
            sprite.size = size
        }
        sprite.position = CGPoint(
            x: catFrameSize.width / 2,
            y: renderInfo.map { groundedCenterY(height: sprite.size.height, info: $0) }
                ?? catFrameSize.height / 2
        )
        shadow.position = CGPoint(x: catFrameSize.width / 2, y: 5)
    }

    private func groundedCenterY(height: CGFloat, info: SkinRenderInfo) -> CGFloat {
        groundedFootY + height * (0.5 - info.bottomAnchor)
    }

    private func applySpriteActionSpeed(for state: CatState) {
        sprite.speed = state == .typing ? typingAnimationSpeed : 1.0
    }

    private func pinSpriteForDragging(offset: CGPoint = .zero) {
        sprite.anchorPoint = CGPoint(x: 0.5, y: renderInfo?.dragAnchor ?? 1)
        sprite.setScale(1)
        sprite.position = CGPoint(
            x: catFrameSize.width / 2 + offset.x,
            y: catFrameSize.height - CatDragGeometry.defaultPinOffsetY + offset.y
        )
    }

    private func keepDraggingVisible(texture: SKTexture) {
        guard renderInfo != nil,
              let bounds = dragAlphaBoundsByTexture[ObjectIdentifier(texture)] else { return }
        sprite.position = bounds.constrainedPosition(
            sprite.position, size: sprite.size, anchor: sprite.anchorPoint,
            rotation: sprite.zRotation, frameSize: catFrameSize
        )
    }

    private func walkBobAction() -> SKAction {
        let baseline = renderInfo.map { groundedCenterY(height: sprite.size.height, info: $0) }
            ?? catFrameSize.height / 2
        // Grounded artwork has only 2pt beneath its feet. Bob above that line
        // so the passing poses never push their antialiased toes out of view.
        let offset: CGFloat = renderInfo == nil ? -2 : 2
        let bob = SKAction.moveTo(y: baseline + offset, duration: 0.12)
        bob.timingMode = .linear
        let settle = SKAction.moveTo(y: baseline, duration: 0.12)
        settle.timingMode = .linear
        return SKAction.repeatForever(SKAction.sequence([bob, settle]))
    }

    private func startWalkBob() {
        guard currentState == .walk, (texturesByState[.walk]?.count ?? 0) > 1 else { return }
        sprite.run(walkBobAction(), withKey: "walkBob")
    }
}
