import ApplicationServices
import Foundation
import OpenNekoKit

final class KeyboardMonitor {
    enum Mode: String {
        case inactive
        case eventTap
        case polling
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fallbackTimer: Timer?
    private var fallbackDetector = TypingPulseDetector()
    private let onKeyDown: () -> Void

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
    }

    var isActive: Bool {
        mode != .inactive
    }

    var mode: Mode {
        if eventTap != nil { return .eventTap }
        if fallbackTimer != nil { return .polling }
        return .inactive
    }

    deinit {
        stop()
    }

    static var hasListenPermission: Bool {
        CGPreflightListenEventAccess()
    }

    @discardableResult
    static func requestListenPermission() -> Bool {
        CGRequestListenEventAccess()
    }

    @discardableResult
    func start() -> Bool {
        guard mode == .inactive else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyboardEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return startFallbackPolling()
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return startFallbackPolling()
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func startFallbackPolling() -> Bool {
        guard fallbackTimer == nil else { return true }
        fallbackDetector = TypingPulseDetector()
        fallbackDetector.prime(keyDownAge: Self.keyDownIdleInterval())
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollKeyDownIdleInterval()
        }
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer
        return true
    }

    private func pollKeyDownIdleInterval() {
        let now = ProcessInfo.processInfo.systemUptime
        if fallbackDetector.sample(keyDownAge: Self.keyDownIdleInterval(), at: now) {
            handleKeyDown()
        }
    }

    private static func keyDownIdleInterval() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
    }

    fileprivate func handleKeyDown() {
        DispatchQueue.main.async { [weak self] in
            self?.onKeyDown()
        }
    }
}

private let keyboardEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handleKeyDown()
    return Unmanaged.passUnretained(event)
}
