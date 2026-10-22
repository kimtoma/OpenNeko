# Codex Pet Punch Sequence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make OpenNeko approach the visible Codex pet smoothly, face it, stop, and perform three stable-size full-body punches over 2.4-2.7 seconds.

**Architecture:** Put encounter timing, direction locking, phase state, and scan admission in `OpenNekoKit` for deterministic tests. Run screen capture and pixel analysis on one serial utility queue, while SpriteKit owns a single target-facing repeated punch action and the main app loop consumes cached detector results.

**Tech Stack:** Swift 5.9, AppKit, SpriteKit, CoreGraphics, XCTest, SwiftPM, XcodeGen

## Global Constraints

- Preserve the four existing generated full-body punch PNGs without image edits.
- Perform exactly three punches over 2.4-2.7 seconds.
- Mirror every punch toward the locked Codex pet direction.
- Display punch art at 1.16 times its current size and shift it 12 points toward the window floor.
- Keep pixel fallback detection and never run more than one pixel scan concurrently.
- Do not stage or revert unrelated dirty worktree files.

---

### Task 1: Deterministic Encounter State And Timing

**Files:**
- Modify: `Sources/OpenNekoKit/State/ScreenPetEncounter.swift`
- Modify: `Tests/OpenNekoKitTests/ScreenPetEncounterTests.swift`

**Interfaces:**
- Produces: `ScreenPetPunchSequence.default`, `ScreenPetEncounterSession`, and `ScreenPetScanGate`.
- Consumes: existing `ScreenPetCandidate` and `ScreenPetEncounter.nearestCodexPetCandidate`.

- [ ] **Step 1: Write failing tests for sequence timing and direction lock**

```swift
func testDefaultPunchSequencePlaysThreeTimesWithinApprovedDuration() {
    let sequence = ScreenPetPunchSequence.default
    XCTAssertEqual(sequence.punchCount, 3)
    XCTAssertGreaterThanOrEqual(sequence.totalDuration, 2.4)
    XCTAssertLessThanOrEqual(sequence.totalDuration, 2.7)
}

func testEncounterLocksDirectionTowardTarget() {
    var session = ScreenPetEncounterSession()
    session.lock(
        target: ScreenPetCandidate(
            id: "right", ownerName: "Codex", windowName: "Pet",
            frame: CGRect(x: 400, y: 0, width: 96, height: 96)
        ),
        relativeTo: CGRect(x: 100, y: 0, width: 128, height: 128)
    )
    XCTAssertEqual(session.phase, .approaching)
    XCTAssertEqual(session.direction, 1)
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter ScreenPetEncounterTests`

Expected: compilation fails because the new sequence, session, and gate types do not exist.

- [ ] **Step 3: Add the minimal pure models**

```swift
public struct ScreenPetPunchSequence: Equatable, Sendable {
    public let punchCount: Int
    public let leadInDuration: TimeInterval
    public let frameDuration: TimeInterval
    public let recoveryDuration: TimeInterval
    public let settleDuration: TimeInterval

    public var singlePunchDuration: TimeInterval { frameDuration * 4 }
    public var totalDuration: TimeInterval {
        leadInDuration
            + singlePunchDuration * Double(punchCount)
            + recoveryDuration * Double(max(0, punchCount - 1))
            + settleDuration
    }

    public static let `default` = ScreenPetPunchSequence(
        punchCount: 3,
        leadInDuration: 0.12,
        frameDuration: 0.16,
        recoveryDuration: 0.18,
        settleDuration: 0.18
    )
}

public enum ScreenPetEncounterPhase: Equatable, Sendable {
    case searching, approaching, punching, cooldown
}

public struct ScreenPetEncounterSession: Equatable, Sendable {
    public private(set) var phase: ScreenPetEncounterPhase = .searching
    public private(set) var target: ScreenPetCandidate?
    public private(set) var direction = 1
    public private(set) var phaseEndsAt: TimeInterval = 0

    public mutating func lock(target: ScreenPetCandidate, relativeTo catFrame: CGRect) {
        self.target = target
        direction = target.frame.midX < catFrame.midX ? -1 : 1
        phase = .approaching
        phaseEndsAt = 0
    }

    public mutating func refreshTarget(_ target: ScreenPetCandidate, relativeTo catFrame: CGRect) {
        guard phase == .approaching else { return }
        lock(target: target, relativeTo: catFrame)
    }

    public mutating func beginPunching(at now: TimeInterval) {
        phase = .punching
        phaseEndsAt = now + ScreenPetPunchSequence.default.totalDuration
    }

    public mutating func beginCooldown(at now: TimeInterval) {
        target = nil
        phase = .cooldown
        phaseEndsAt = now + ScreenPetEncounter.defaultPunchCooldown
    }

    public mutating func cancel() {
        self = ScreenPetEncounterSession()
    }

    public mutating func resetIfCooldownExpired(at now: TimeInterval) -> Bool {
        guard phase == .cooldown, now >= phaseEndsAt else { return false }
        self = ScreenPetEncounterSession()
        return true
    }
}

public struct ScreenPetScanGate: Equatable, Sendable {
    public private(set) var isInFlight = false
    private var lastStartedAt = -TimeInterval.infinity

    public mutating func beginScan(now: TimeInterval, minimumInterval: TimeInterval) -> Bool {
        guard !isInFlight, now - lastStartedAt >= minimumInterval else { return false }
        isInFlight = true
        lastStartedAt = now
        return true
    }

    public mutating func finishScan() {
        isInFlight = false
    }
}
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `swift test --filter ScreenPetEncounterTests`

Expected: all `ScreenPetEncounterTests` pass.

---

### Task 2: Stable-Size Three-Punch Sprite Sequence

**Files:**
- Modify: `Sources/OpenNekoKit/State/ScreenPetEncounter.swift`
- Modify: `App/CatScene.swift`
- Modify: `App/CatWindow.swift`
- Modify: `Tests/OpenNekoKitTests/ScreenPetEncounterTests.swift`

**Interfaces:**
- Consumes: `ScreenPetPunchSequence.default` and the locked `direction` from `ScreenPetEncounterSession`.
- Produces: `CatScene.playPunch(direction:sequence:)` and `CatWindow.playScreenPetPunch(direction:)`.

- [ ] **Step 1: Write a failing normalized-presentation test**

```swift
func testPunchPresentationMatchesWalkScaleAndFloor() {
    let presentation = ScreenPetPunchPresentation.fullBody(
        catFrameSize: CGSize(width: 128, height: 128), direction: 1
    )
    XCTAssertEqual(presentation.size, CGSize(width: 148.48, height: 148.48))
    XCTAssertEqual(presentation.position, CGPoint(x: 64, y: 52))
    XCTAssertEqual(presentation.xScale, -1)
    XCTAssertEqual(presentation.yScale, 1)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter ScreenPetEncounterTests/testPunchPresentationMatchesWalkScaleAndFloor`

Expected: compilation fails because `yScale` is missing and the old size/position values do not match.

- [ ] **Step 3: Implement the repeated SpriteKit action**

Return a presentation with `size = catFrameSize * 1.16`, `position = (width / 2, height / 2 - 12)`, target-facing `xScale`, and positive `yScale`. In `CatScene`, construct the action without a uniform scale action:

```swift
let punch = SKAction.animate(
    with: textures,
    timePerFrame: sequence.frameDuration,
    resize: false,
    restore: false
)
var actions: [SKAction] = [.wait(forDuration: sequence.leadInDuration)]
for index in 0..<sequence.punchCount {
    actions.append(punch)
    if index < sequence.punchCount - 1 {
        actions.append(.wait(forDuration: sequence.recoveryDuration))
    }
}
actions.append(.wait(forDuration: sequence.settleDuration))
actions.append(.run { [weak self] in self?.finishPunchSequence() })
punchEffect.run(.sequence(actions))
```

Keep the base sprite hidden until `finishPunchSequence()` restores visibility, hides the punch node, clears its actions, resets its independent scales, and starts idle once.

Change the window entry point to accept the already locked direction:

```swift
func playScreenPetPunch(direction: Int) {
    resetAutonomousMotion()
    scene.playPunch(direction: direction, sequence: .default)
}
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --filter ScreenPetEncounterTests`

Expected: all encounter tests pass, including left/right mirror and scale/floor assertions.

---

### Task 3: Non-Blocking Detection And Encounter Integration

**Files:**
- Modify: `App/ScreenPetPixelCaptureDetector.swift`
- Modify: `App/OpenNekoApp.swift`
- Modify: `Tests/OpenNekoKitTests/ScreenPetEncounterTests.swift`

**Interfaces:**
- Consumes: `ScreenPetScanGate`, `ScreenPetEncounterSession`, `ScreenPetPunchSequence.default`, and cached `[ScreenPetCandidate]`.
- Produces: a single-flight background pixel scan and a main-loop phase transition from search to approach to punching to cooldown.

- [ ] **Step 1: Write the failing single-flight gate test**

```swift
func testScanGateRejectsOverlappingAndTooFrequentScans() {
    var gate = ScreenPetScanGate()
    XCTAssertTrue(gate.beginScan(now: 10, minimumInterval: 0.8))
    XCTAssertFalse(gate.beginScan(now: 11, minimumInterval: 0.8))
    gate.finishScan()
    XCTAssertFalse(gate.beginScan(now: 10.5, minimumInterval: 0.8))
    XCTAssertTrue(gate.beginScan(now: 10.8, minimumInterval: 0.8))
}
```

- [ ] **Step 2: Run the gate test and verify RED**

Run: `swift test --filter ScreenPetEncounterTests/testScanGateRejectsOverlappingAndTooFrequentScans`

Expected: the test fails until the gate tracks both in-flight state and last-start time.

- [ ] **Step 3: Move pixel capture and analysis off the main thread**

Expose main-thread capture rectangles as `[CGRect]`, then pass only value types into a serial queue:

```swift
private let screenPetDetectionQueue = DispatchQueue(
    label: "com.openneko.screen-pet-detection", qos: .utility
)

private func requestScreenPetScan(now: TimeInterval, cat: CatWindow) {
    let windows = ScreenPetWindowDetector.candidates()
    if !windows.isEmpty {
        screenPetCandidates = windows
        return
    }
    guard screenPetScanGate.beginScan(now: now, minimumInterval: 0.8) else { return }
    let displayFrames = ScreenPetPixelCaptureDetector.displayFrames()
    let exclusions = [cat.catScreenFrame.insetBy(dx: -12, dy: -12)]
    screenPetDetectionQueue.async { [weak self] in
        let result = ScreenPetPixelCaptureDetector.candidates(
            displayFrames: displayFrames, excludingFrames: exclusions
        )
        DispatchQueue.main.async {
            self?.screenPetCandidates = result
            self?.screenPetScanGate.finishScan()
        }
    }
}
```

Replace timestamp/cooldown ad hoc properties with the session. During `.approaching`, request background revalidation without changing to another pet: match the locked target by stable ID or by an intersecting/nearby refreshed pixel frame. Refresh its frame and walking direction when matched; call `session.cancel()` after a completed scan no longer contains it. During `.punching`, do not request scans and return from the autonomous tick until `phaseEndsAt`; then call `beginCooldown(at:)`. Pass `session.direction` directly into `CatWindow.playScreenPetPunch(direction:)`.

- [ ] **Step 4: Run all encounter and package tests**

Run: `swift test`

Expected: the complete test suite passes with zero failures.

---

### Task 4: Native Build And Live Interaction Verification

**Files:**
- Verify: `OpenNeko.xcodeproj`
- Save: `output/imagegen/nyang-punch-sequence-success.png`

**Interfaces:**
- Consumes: the completed Debug app and a visible Codex-like smoke target.
- Produces: test, build, process, health, direction, timing, and screenshot evidence.

- [ ] **Step 1: Regenerate and build the Xcode project**

Run: `xcodegen generate`

Run: `xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build`

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Fully quit and relaunch the newest Debug app**

Run: `pkill -x OpenNeko`, verify no stale process with `pgrep -fl OpenNeko`, then open `.derivedData/Build/Products/Debug/OpenNeko.app`.

Expected: one process runs from the current `.derivedData` path and `GET http://127.0.0.1:48800/health` returns `openneko`.

- [ ] **Step 3: Verify the live visual requirements**

Place a Codex-like smoke target to the right, capture the three-punch sequence, then repeat with the target to the left. Confirm the cat approaches without periodic animation pauses, stops translating during all three punches, mirrors toward the target, keeps a stable body scale/floor line, and returns to idle.

- [ ] **Step 4: Save final evidence**

Save the clearest live interaction frame to `output/imagegen/nyang-punch-sequence-success.png` and inspect it at original resolution before completion.
