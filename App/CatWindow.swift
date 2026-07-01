import AppKit
import SpriteKit
import QuartzCore
import OpenNekoKit

/// 고양이를 그리는 SKView. 화면 전체 투명 레이어 위에서 실제 고양이 bounds 안의
/// 이벤트만 받도록 CatWindow가 hit-test를 제공한다.
final class CatSKView: SKView {
    var onClick: (() -> Void)?
    var onContextMenu: ((NSView) -> Void)?
    var onDragBegan: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var shouldHandleLocalPoint: ((NSPoint) -> Bool)?

    private var didDrag = false
    private var suppressNextMouseUp = false
    private var dragStartScreenPoint: NSPoint?

    // 앱이 비활성 상태여도 첫 클릭이 활성화에 먹히지 않고 바로 드래그/클릭되게.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func accepts(_ event: NSEvent) -> Bool {
        shouldHandleLocalPoint?(event.locationInWindow) ?? true
    }

    override func mouseDown(with event: NSEvent) {
        guard accepts(event) else {
            didDrag = false
            suppressNextMouseUp = false
            dragStartScreenPoint = nil
            return
        }
        if event.modifierFlags.contains(.control) {
            suppressNextMouseUp = true
            if didDrag {
                didDrag = false
                onDragEnded?()
            }
            dragStartScreenPoint = nil
            onContextMenu?(self)
            return
        }
        didDrag = false
        dragStartScreenPoint = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation  // 전역 좌표
        if !didDrag {
            if let start = dragStartScreenPoint,
               !CatDragGeometry.hasDraggedBeyondStartDistance(from: start, to: mouse) {
                return
            }
            didDrag = true
            onDragBegan?(mouse)
        }
        onDragMoved?(mouse)
    }

    override func mouseUp(with event: NSEvent) {
        if suppressNextMouseUp {
            suppressNextMouseUp = false
            return
        }
        if didDrag {
            onDragEnded?()
        } else if accepts(event) {
            onClick?()
        }
        didDrag = false
        dragStartScreenPoint = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        guard accepts(event) else { return }
        if didDrag {
            didDrag = false
            suppressNextMouseUp = true
            onDragEnded?()
        }
        dragStartScreenPoint = nil
        onContextMenu?(self)
    }
}

final class CatWindow: NSWindow {
    private let skView = CatSKView()
    private let scene: CatScene
    private let catSize = CatLayoutMetrics.primaryCatSize
    private let oneShotStates: Set<CatState> = [.click, .yawn, .success, .error, .jump]
    private var bubbleWindow: CatBubbleWindow?
    private var chatWindow: CatChatWindow?
    private let soundPlayer = CatSoundPlayer()
    private var typingActive = false
    private var typingAnimationSpeed = 1.0
    private var draggingActive = false
    private var lastDragMouseX: CGFloat?
    private var dragHorizontalVelocity: CGFloat = 0
    private var dragHorizontalAcceleration: CGFloat = 0
    private var dragVisualTimer: Timer?
    private var mousePassThroughTimer: Timer?
    private var landingTimer: Timer?
    private var catOrigin: CGPoint = .zero
    private var pointerHovering = false
    private var autonomousVerticalVelocity: CGFloat = 0
    private var autonomousWalkAirborne = false
    var soundEffectsEnabled = true
    var onChatSend: ((String) -> Void)?
    var onChatCancel: (() -> Void)?
    var onContextMenu: ((NSView) -> Void)?
    var onUserInteraction: (() -> Void)?
    var onPositionChanged: (() -> Void)?
    var chatPlaceholderProvider: () -> String = { NekoBubbleCopy.chatPlaceholder(languageCode: nil) }
    var slashCommandsProvider: () -> [SlashCommandDescriptor] = { [] }
    var currentState: CatState { scene.displayedState }
    var isAlwaysOnTopEnabled: Bool { level == .floating }
    var isChatVisible: Bool { chatWindow?.isVisible == true }
    var isAutonomousMotionSettling: Bool { autonomousWalkAirborne }
    var catScreenFrame: NSRect { frame }

    deinit {
        mousePassThroughTimer?.invalidate()
        landingTimer?.invalidate()
        dragVisualTimer?.invalidate()
    }

    init() {
        let initialFrame = NSRect(origin: .zero, size: catSize)
        let initialScene = CatScene(size: catSize)
        initialScene.setCatFrameSize(catSize)
        scene = initialScene
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        applyOpenNekoOverlayWindowPolicy()

        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 60
        skView.ignoresSiblingOrder = true
        skView.wantsLayer = true
        skView.layer?.magnificationFilter = .nearest
        skView.layer?.minificationFilter = .nearest
        skView.frame = NSRect(origin: .zero, size: catSize)
        skView.autoresizingMask = [.width, .height]
        skView.presentScene(scene)
        skView.onDragBegan = { [weak self] mouse in self?.beginDrag(mouse: mouse) }
        skView.onDragEnded = { [weak self] in self?.dropAndFall() }
        skView.onDragMoved = { [weak self] mouse in self?.dragMoved(mouse: mouse) }
        skView.onClick = { [weak self] in self?.handleClick() }
        skView.onContextMenu = { [weak self] view in self?.onContextMenu?(view) }
        skView.shouldHandleLocalPoint = { [weak self] point in
            guard let self else { return false }
            return CGRect(origin: .zero, size: self.catSize)
                .insetBy(dx: -self.catHitPadding, dy: -self.catHitPadding)
                .contains(point)
        }
        contentView = skView

        positionBottomRight()
        startMousePassThroughTimer()
        bubbleWindow = CatBubbleWindow(parentWindow: self, onClick: { [weak self] in
            self?.openChatFromBubble()
        })
        let chat = CatChatWindow(
            parentWindow: self,
            onSend: { [weak self] text in
                self?.onChatSend?(text)
            },
            onCancel: { [weak self] in
                self?.onChatCancel?()
            },
            slashCommands: { [weak self] in
                self?.slashCommandsProvider() ?? []
            }
        )
        chat.onFrameChanged = { [weak self, weak chat] in
            self?.bubbleWindow?.reposition(avoiding: chat?.visibleFrame)
        }
        chatWindow = chat
    }

    private let floorMargin = CatLayoutMetrics.floorPadding
    private let catHitPadding: CGFloat = 8

    private func resizeLayer(to _: NSScreen) {
        if frame.size != catSize {
            setFrame(NSRect(origin: frame.origin, size: catSize), display: true)
        }
        if scene.size != catSize {
            scene.size = catSize
        }
    }

    private func setCatOrigin(_ origin: CGPoint) {
        catOrigin = origin
        scene.setCatOrigin(.zero)
        let targetFrame = NSRect(origin: screenPoint(fromLocal: origin), size: catSize)
        if frame != targetFrame {
            setFrame(targetFrame, display: true)
        }
        repositionFloatingWindows()
    }

    private func resetAutonomousMotion() {
        autonomousVerticalVelocity = 0
        autonomousWalkAirborne = false
    }

    private func localPoint(fromScreen point: NSPoint) -> CGPoint {
        let screenFrame = screenFrame(containing: point)
        return CGPoint(x: point.x - screenFrame.minX, y: point.y - screenFrame.minY)
    }

    private func screenPoint(fromLocal point: CGPoint) -> NSPoint {
        let screenFrame = currentScreenFrame()
        return NSPoint(x: screenFrame.minX + point.x, y: screenFrame.minY + point.y)
    }

    private func localRect(fromScreen rect: NSRect, in screenFrame: NSRect) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: rect.minY - screenFrame.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func screenFrame(containing point: NSPoint) -> NSRect {
        NSScreen.screens.first { $0.frame.contains(point) }?.frame ?? currentScreenFrame()
    }

    private func currentScreenFrame() -> NSRect {
        screen?.frame ?? NSScreen.main?.frame ?? NSRect(origin: .zero, size: catSize)
    }

    private struct GroundContext {
        let screenFrame: CGRect
        let visibleFrame: CGRect
        let dockFrame: CGRect?
    }

    private func localGroundContext() -> GroundContext? {
        guard let currentScreen = screen ?? NSScreen.main else { return nil }
        let screenFrame = currentScreen.frame
        return GroundContext(
            screenFrame: localRect(fromScreen: screenFrame, in: screenFrame),
            visibleFrame: localRect(fromScreen: currentScreen.visibleFrame, in: screenFrame),
            dockFrame: DockSupportFrameProvider.dockFrame(for: currentScreen).map {
                localRect(fromScreen: $0, in: screenFrame)
            }
        )
    }

    private func floorY(originX: CGFloat, context: GroundContext) -> CGFloat {
        CatDragGeometry.supportFloorY(
            originX: originX,
            size: catSize,
            screenFrame: context.screenFrame,
            visibleFrame: context.visibleFrame,
            dockFrame: context.dockFrame,
            margin: floorMargin
        )
    }

    private func isPointInCat(_ point: CGPoint, padding: CGFloat = 0) -> Bool {
        CGRect(origin: catOrigin, size: catSize)
            .insetBy(dx: -padding, dy: -padding)
            .contains(point)
    }

    private func updateDraggedCatPosition(mouse: NSPoint) {
        let localMouse = localPoint(fromScreen: mouse)
        var next = CatDragGeometry.topPinnedDragOrigin(pointer: localMouse, size: catSize)
        if let context = localGroundContext() {
            next = CatDragGeometry.clampedDragOrigin(
                next,
                size: catSize,
                screenFrame: context.screenFrame,
                visibleFrame: context.visibleFrame,
                dockFrame: context.dockFrame,
                floorMargin: floorMargin
            )
        }
        setCatOrigin(next)
    }

    private func startMousePassThroughTimer() {
        mousePassThroughTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMousePassThrough()
        }
        RunLoop.main.add(timer, forMode: .common)
        mousePassThroughTimer = timer
    }

    private func updateMousePassThrough() {
        guard isVisible else {
            ignoresMouseEvents = false
            setPointerHovering(false)
            return
        }
        let localMouse = localPoint(fromScreen: NSEvent.mouseLocation)
        let hovering = isPointInCat(localMouse, padding: catHitPadding)
        if draggingActive {
            ignoresMouseEvents = false
            setPointerHovering(false)
            return
        }
        setPointerHovering(hovering)
        ignoresMouseEvents = !hovering
    }

    private func animateLanding(from: CGPoint, to: CGPoint, duration: TimeInterval, falling: Bool) {
        landingTimer?.invalidate()
        let start = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            let p = min(1, elapsed / duration)
            let eased = falling ? p * p : 1 - pow(1 - p, 2)
            let y = from.y + (to.y - from.y) * CGFloat(eased)
            setCatOrigin(CGPoint(x: to.x, y: y))
            if p >= 1 {
                timer.invalidate()
                landingTimer = nil
                setCatOrigin(to)
                draggingActive = false
                resetAutonomousMotion()
                playRestingState()
                scene.landingSquash()
                playSound(.land)
                updateMousePassThrough()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        landingTimer = timer
    }

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        resizeLayer(to: screen)
        guard let context = localGroundContext() else { return }
        let x = context.visibleFrame.maxX - catSize.width - floorMargin
        let y = floorY(originX: x, context: context)
        resetAutonomousMotion()
        setCatOrigin(CGPoint(x: x, y: y))
        updateMousePassThrough()
    }

    private func handleClick() {
        onUserInteraction?()
        playSound(.chirp)
        scene.playOnce(state: .click)
        chatWindow?.show(placeholder: chatPlaceholderProvider())
        repositionFloatingWindows()
    }

    private func openChatFromBubble() {
        onUserInteraction?()
        playSound(.chirp)
        chatWindow?.show(placeholder: chatPlaceholderProvider())
        repositionFloatingWindows()
    }

    func showChat(placeholder: String) {
        chatWindow?.show(placeholder: placeholder)
        repositionFloatingWindows()
    }

    private func beginDrag(mouse: NSPoint) {
        onUserInteraction?()
        landingTimer?.invalidate()
        landingTimer = nil
        resetAutonomousMotion()
        setPointerHovering(false)
        draggingActive = true
        lastDragMouseX = mouse.x
        dragHorizontalVelocity = 0
        dragHorizontalAcceleration = 0
        ignoresMouseEvents = false
        playSound(.pluck)
        updateDraggedCatPosition(mouse: mouse)
        updateDragVisual()
        startDragVisualTimer()
    }

    private func dragMoved(mouse: NSPoint) {
        if let previous = lastDragMouseX {
            let previousVelocity = dragHorizontalVelocity
            dragHorizontalVelocity = CatDragGeometry.smoothedHorizontalVelocity(
                previous: dragHorizontalVelocity,
                previousMouseX: previous,
                currentMouseX: mouse.x
            )
            dragHorizontalAcceleration = CatDragGeometry.smoothedHorizontalAcceleration(
                previous: dragHorizontalAcceleration,
                previousVelocity: previousVelocity,
                currentVelocity: dragHorizontalVelocity
            )
        }
        lastDragMouseX = mouse.x
        updateDraggedCatPosition(mouse: mouse)
        updateDragVisual()
    }

    private func startDragVisualTimer() {
        dragVisualTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickDragVisual()
        }
        RunLoop.main.add(timer, forMode: .common)
        dragVisualTimer = timer
    }

    private func tickDragVisual() {
        let previousVelocity = dragHorizontalVelocity
        dragHorizontalVelocity = CatDragGeometry.decayedHorizontalVelocity(dragHorizontalVelocity)
        dragHorizontalAcceleration = CatDragGeometry.smoothedHorizontalAcceleration(
            previous: dragHorizontalAcceleration,
            previousVelocity: previousVelocity,
            currentVelocity: dragHorizontalVelocity
        )
        updateDragVisual()
    }

    private func stopDragVisualTimer() {
        dragVisualTimer?.invalidate()
        dragVisualTimer = nil
        lastDragMouseX = nil
        dragHorizontalVelocity = 0
        dragHorizontalAcceleration = 0
    }

    private func updateDragVisual() {
        scene.showDragging(
            horizontalVelocity: dragHorizontalVelocity,
            horizontalAcceleration: dragHorizontalAcceleration,
            time: ProcessInfo.processInfo.systemUptime
        )
    }

    private func playRestingState() {
        scene.setTypingAnimationSpeed(typingAnimationSpeed)
        scene.play(state: typingActive ? .typing : .idle)
    }

    /// 드롭 시 놓은 위치에서 화면 바닥까지 가속하며 떨어진 뒤 착지(원본 fallToBottom 재현).
    private func dropAndFall() {
        stopDragVisualTimer()
        guard let context = localGroundContext() else {
            draggingActive = false
            resetAutonomousMotion()
            playRestingState()
            return
        }
        let origin = catOrigin
        let floorY = floorY(originX: origin.x, context: context)
        let landingDistance = CatDragGeometry.landingDistance(from: origin.y, floorY: floorY)
        guard landingDistance > 1 else {
            setCatOrigin(CGPoint(x: origin.x, y: floorY))
            draggingActive = false
            resetAutonomousMotion()
            playRestingState()
            scene.landingSquash()
            playSound(.land)
            updateMousePassThrough()
            return
        }
        scene.showFalling()
        let duration = CatDragGeometry.landingDuration(drop: landingDistance)
        animateLanding(
            from: origin,
            to: CGPoint(x: origin.x, y: floorY),
            duration: duration,
            falling: origin.y >= floorY
        )
    }

    func showCat(skin: Skin) {
        applySkin(skin)
        orderFrontRegardless()
        NSLog("[openNeko] showCat frame=\(frame) screen=\(String(describing: screen?.visibleFrame)) idleFrames=\(skin.frameURLs(for: "idle").count) visible=\(isVisible)")
    }

    func applySkin(_ skin: Skin) {
        scene.apply(skin: skin)
        playRestingState()
    }

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            // 다시 보일 때는 항상 우하단 기본 위치로 복귀(화면 밖으로 잃어버렸을 때 복구 경로).
            positionBottomRight()
            scene.play(state: .idle)
            orderFrontRegardless()
            repositionFloatingWindows()
        }
    }

    func setAlwaysOnTopEnabled(_ enabled: Bool) {
        level = enabled ? .floating : .normal
        if enabled {
            collectionBehavior.insert(.canJoinAllSpaces)
        }
    }

    func canStartAutonomousAction() -> Bool {
        guard isVisible, !draggingActive, !isChatVisible else { return false }
        switch currentState {
        case .idle, .hover, .walk:
            return true
        default:
            return false
        }
    }

    func canContinueAutonomousWalk() -> Bool {
        isVisible && !draggingActive && !isChatVisible
    }

    func playAutonomousState(_ state: CatState) {
        guard !draggingActive else { return }
        resetAutonomousMotion()
        typingActive = false
        if oneShotStates.contains(state) {
            scene.playOnce(state: state)
        } else {
            scene.play(state: state)
        }
    }

    func stopAutonomousWalk() {
        if currentState == .walk {
            scene.play(state: .idle)
        }
        resetAutonomousMotion()
    }

    func autonomousWalkStep(direction: Int, distance: CGFloat, deltaTime: TimeInterval = 1.0 / 60.0) -> Int {
        guard canContinueAutonomousWalk(), canStartAutonomousAction() || currentState == .walk else {
            return direction
        }
        scene.playWalk(direction: direction == 0 ? 1 : direction)
        guard let context = localGroundContext() else { return direction }
        let vf = context.visibleFrame
        var nextDirection = direction == 0 ? 1 : direction
        var origin = catOrigin
        let previousFloorY = floorY(originX: origin.x, context: context)
        origin.x += CGFloat(nextDirection) * distance
        if origin.x <= vf.minX {
            origin.x = vf.minX
            nextDirection = 1
        } else if origin.x >= vf.maxX - catSize.width {
            origin.x = vf.maxX - catSize.width
            nextDirection = -1
        }
        let targetFloorY = floorY(originX: origin.x, context: context)
        let vertical = CatDragGeometry.walkVerticalMotionStep(
            originY: origin.y,
            verticalVelocity: autonomousVerticalVelocity,
            previousFloorY: previousFloorY,
            targetFloorY: targetFloorY,
            deltaTime: deltaTime
        )
        let wasAirborne = autonomousWalkAirborne
        autonomousVerticalVelocity = vertical.verticalVelocity
        autonomousWalkAirborne = !vertical.isGrounded
        origin.y = vertical.originY
        scene.playWalk(direction: nextDirection)
        setCatOrigin(origin)
        if vertical.didLaunch {
            playSound(.pluck)
        }
        if wasAirborne, vertical.isGrounded {
            scene.landingSquash()
            playSound(.land)
        }
        return nextDirection
    }

    func setTypingActive(_ active: Bool, animationSpeed: Double = 1.0) {
        typingAnimationSpeed = active ? animationSpeed : 1.0
        scene.setTypingAnimationSpeed(typingAnimationSpeed)
        typingActive = active
        guard !draggingActive else { return }
        resetAutonomousMotion()
        playRestingState()
    }

    func updateTypingAnimationSpeed(_ speed: Double) {
        typingAnimationSpeed = speed
        scene.setTypingAnimationSpeed(speed)
    }

    func applyBridgeState(_ state: CatState) {
        guard !draggingActive else { return }
        resetAutonomousMotion()
        if state == .idle {
            typingActive = false
            typingAnimationSpeed = 1.0
            scene.setTypingAnimationSpeed(typingAnimationSpeed)
            scene.play(state: .idle)
        } else if state == .typing {
            typingActive = true
            scene.setTypingAnimationSpeed(typingAnimationSpeed)
            scene.play(state: .typing)
        } else if oneShotStates.contains(state) {
            if state == .success {
                playSound(.success)
            } else if state == .error {
                playSound(.error)
            }
            scene.playOnce(state: state)
        } else {
            typingActive = false
            typingAnimationSpeed = 1.0
            scene.setTypingAnimationSpeed(typingAnimationSpeed)
            scene.play(state: state)
        }
    }

    private func setHovering(_ hovering: Bool) {
        guard !draggingActive, !typingActive, !isChatVisible else { return }
        if hovering, currentState == .idle {
            scene.play(state: .hover)
        } else if !hovering, currentState == .hover {
            scene.play(state: .idle)
        }
    }

    private func setPointerHovering(_ hovering: Bool) {
        guard pointerHovering != hovering else { return }
        pointerHovering = hovering
        setHovering(hovering)
    }

    func debugDragAndDropJSON() -> String {
        guard isVisible, let context = localGroundContext() else {
            return #"{"ok":false,"reason":"cat-unavailable"}"#
        }
        let vf = context.visibleFrame
        let floorY = floorY(originX: catOrigin.x, context: context)
        let start = CGPoint(
            x: catOrigin.x + catSize.width / 2,
            y: catOrigin.y + catSize.height - CatDragGeometry.defaultPinOffsetY
        )
        let peakY = min(vf.maxY - 24, floorY + catSize.height + 280)
        let leftX = max(vf.minX + catSize.width / 2, start.x - 260)
        let rightX = min(vf.maxX - catSize.width / 2, leftX + 180)
        let points = [
            CGPoint(x: leftX, y: peakY),
            CGPoint(x: rightX, y: min(vf.maxY - 24, peakY + 28)),
            CGPoint(x: leftX, y: peakY),
            CGPoint(x: rightX, y: peakY),
        ]

        beginDrag(mouse: screenPoint(fromLocal: start))
        for (index, point) in points.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(index + 1)) { [weak self] in
                guard let self else { return }
                dragMoved(mouse: screenPoint(fromLocal: point))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(points.count + 2)) { [weak self] in
            self?.dropAndFall()
        }

        return """
        {"ok":true,"floorY":\(jsonNumber(floorY)),"start":{"x":\(jsonNumber(start.x)),"y":\(jsonNumber(start.y))},"peakY":\(jsonNumber(peakY))}
        """
    }

    func showBubble(
        _ text: String,
        onClick: (() -> Void)? = nil,
        helpText: String? = nil
    ) {
        bubbleWindow?.show(text: text, onClick: onClick, helpText: helpText)
        repositionFloatingWindows()
    }

    func capturePNGData() -> Data? {
        guard let catData = scene.capturePNGData(),
              let catImage = NSImage(data: catData) else {
            return nil
        }
        catImage.size = frame.size

        let items = [
            WindowCaptureItem(frame: frame, image: catImage),
            chatWindow?.captureItem(),
            bubbleWindow?.captureItem(),
        ].compactMap { $0 }
        return WindowCapture.pngData(items: items)
    }

    func positionDebugJSON() -> String {
        let currentScreen = screen ?? NSScreen.main
        let screenFrame = currentScreen?.frame ?? .zero
        let visibleFrame = currentScreen?.visibleFrame ?? .zero
        let dockFrame = currentScreen.flatMap { DockSupportFrameProvider.dockFrame(for: $0) }
        let catFrame = catScreenFrame
        let dockJSON: String
        if let dockFrame {
            dockJSON = #"{"x":\#(jsonNumber(dockFrame.minX)),"y":\#(jsonNumber(dockFrame.minY)),"width":\#(jsonNumber(dockFrame.width)),"height":\#(jsonNumber(dockFrame.height))}"#
        } else {
            dockJSON = "null"
        }
        return """
        {"workArea":{"x":\(jsonNumber(visibleFrame.minX)),"y":\(jsonNumber(visibleFrame.minY)),"width":\(jsonNumber(visibleFrame.width)),"height":\(jsonNumber(visibleFrame.height))},"displayBounds":{"x":\(jsonNumber(screenFrame.minX)),"y":\(jsonNumber(screenFrame.minY)),"width":\(jsonNumber(screenFrame.width)),"height":\(jsonNumber(screenFrame.height))},"dockRect":\(dockJSON),"winX":\(jsonNumber(frame.minX)),"winY":\(jsonNumber(frame.minY)),"windowBounds":{"x":\(jsonNumber(frame.minX)),"y":\(jsonNumber(frame.minY)),"width":\(jsonNumber(frame.width)),"height":\(jsonNumber(frame.height))},"catBounds":{"x":\(jsonNumber(catFrame.minX)),"y":\(jsonNumber(catFrame.minY)),"width":\(jsonNumber(catFrame.width)),"height":\(jsonNumber(catFrame.height))}}
        """
    }

    private func repositionFloatingWindows() {
        chatWindow?.reposition()
        bubbleWindow?.reposition(avoiding: chatWindow?.visibleFrame)
        onPositionChanged?()
    }

    private func playSound(_ effect: CatSoundEffect) {
        guard soundEffectsEnabled else { return }
        soundPlayer.play(effect)
    }

    private func jsonNumber(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}
