# Unified Sprite Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all bundled openNeko character art with one coherent redesigned cyber-cat model across five skins, 15 states, and 300 validated RGBA frames.

**Architecture:** A reusable `OpenNekoKit` quality module defines the 128-pixel asset contract and performs PNG, alpha, alignment, silhouette, and AI-sigil checks. A Swift executable target extracts 2x2 generated sheets, enforces canonical masks, validates the final bundle, and creates review contact sheets. Production art is generated from one identity master, then transformed per skin while retaining the default geometry.

**Tech Stack:** Swift 5.10, AppKit/CoreGraphics, SwiftPM, SpriteKit, OpenAI image generation, XCTest, XcodeGen/xcodebuild.

## Global Constraints

- Produce exactly 300 runtime frames: five skins x 15 states x four frames.
- Every production frame is a 128 x 128, 8-bit RGBA PNG with transparent zero-RGB background pixels.
- Keep at least 12 pixels of safe padding unless a documented state exception is recorded.
- Keep within-state baseline and face-center jitter at or below 2 pixels.
- Keep within-state body-area variation at or below 8 percent except approved `dragging` and `jump` poses.
- Use one canonical anatomy, equipment geometry, tail pattern, and alpha silhouette for all skin variants.
- Keep the filled four-point mint fur marking visible on the forehead in all states.
- Animate `thinking` sigil luminance as inactive < pulse < peak > residual.
- Bake the sigil and all thinking sparkle pixels into generated PNG frames; do not implement a runtime overlay or particle effect.
- Preserve old imported skin compatibility by falling back from missing `punch` frames to `click` frames.
- Do not modify unrelated dirty workspace files.

---

### Task 1: Define The Sprite Asset Contract

**Files:**
- Create: `Sources/OpenNekoKit/Sprite/SpriteAssetQuality.swift`
- Create: `Tests/OpenNekoKitTests/SpriteAssetQualityTests.swift`

**Interfaces:**
- Produces: `SpriteFrameMetrics`, `SpriteQualityIssue`, `SpriteQualityReport`, and `SpriteAssetQuality.inspectPNG(at:)` for later extraction and validation tasks.
- Consumes: AppKit `NSBitmapImageRep` and existing `SpriteManifest`.

- [ ] **Step 1: Write failing metric and contract tests**

Create fixtures in-memory with `NSBitmapImageRep` and test the exact public contract:

```swift
func testInspectionReportsAlphaBoundsPaddingAndTransparentRGBContamination() throws {
    let url = try fixturePNG(
        width: 128,
        height: 128,
        opaqueRect: CGRect(x: 16, y: 20, width: 80, height: 90),
        contaminatedTransparentPixel: CGPoint(x: 0, y: 0)
    )

    let metrics = try SpriteAssetQuality.inspectPNG(at: url)

    XCTAssertEqual(metrics.width, 128)
    XCTAssertEqual(metrics.height, 128)
    XCTAssertEqual(metrics.alphaBounds, CGRect(x: 16, y: 20, width: 80, height: 90))
    XCTAssertEqual(metrics.minimumPadding, 16)
    XCTAssertEqual(metrics.transparentRGBPixelCount, 1)
}

func testContractRejectsEdgeContactAndWrongDimensions() throws {
    let report = SpriteAssetQuality.validate(
        frames: [edgeTouchingFixture, wrongSizeFixture],
        contract: .openNeko
    )
    XCTAssertTrue(report.issues.contains { $0.code == .alphaTouchesCanvasEdge })
    XCTAssertTrue(report.issues.contains { $0.code == .invalidDimensions })
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `swift test --filter SpriteAssetQualityTests`

Expected: compilation fails because `SpriteAssetQuality` and its metric types do not exist.

- [ ] **Step 3: Implement PNG inspection and immutable quality types**

Implement these signatures:

```swift
public struct SpriteFrameMetrics: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let alphaBounds: CGRect?
    public let minimumPadding: Int
    public let opaquePixelCount: Int
    public let transparentRGBPixelCount: Int
    public let connectedComponentAreas: [Int]
    public let foreheadCyanLuminance: Double
}

public enum SpriteQualityIssueCode: String, Codable, Sendable {
    case unreadablePNG
    case invalidDimensions
    case missingAlpha
    case alphaTouchesCanvasEdge
    case insufficientPadding
    case transparentRGBContamination
    case isolatedAlphaNoise
    case baselineJitter
    case faceCenterJitter
    case bodyAreaDrift
    case silhouetteMismatch
    case duplicateMotionFrame
    case missingAISigil
    case invalidThinkingSigilSequence
}

public enum SpriteAssetQuality {
    public static func inspectPNG(at url: URL) throws -> SpriteFrameMetrics
    public static func validate(
        frames: [SpriteFrameDescriptor],
        contract: SpriteAssetContract = .openNeko
    ) -> SpriteQualityReport
}
```

Use 4-connected alpha components, alpha threshold `> 2 / 255`, and count transparent RGB contamination only where alpha is zero and any RGB channel is nonzero.

- [ ] **Step 4: Run focused and full unit tests**

Run: `swift test --filter SpriteAssetQualityTests`

Expected: all new tests pass.

Run: `swift test`

Expected: existing suite remains green.

- [ ] **Step 5: Commit the asset contract**

```bash
git add Sources/OpenNekoKit/Sprite/SpriteAssetQuality.swift Tests/OpenNekoKitTests/SpriteAssetQualityTests.swift
git commit -m "feat: define sprite asset quality contract"
```

### Task 2: Build The Extraction And Review CLI

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SpritePipeline/main.swift`
- Create: `Sources/SpritePipeline/SpriteSheetExtractor.swift`
- Create: `Sources/SpritePipeline/SpriteContactSheet.swift`
- Create: `Tests/OpenNekoKitTests/SpriteSheetGeometryTests.swift`

**Interfaces:**
- Consumes: `SpriteAssetQuality.inspectPNG(at:)` from Task 1.
- Produces: `swift run SpritePipeline extract`, `validate`, and `contact-sheet` commands used by all art tasks.

- [ ] **Step 1: Add failing quadrant, alignment, and mask tests**

```swift
func testTwoByTwoSheetProducesFourEqualCellsInReadingOrder() {
    XCTAssertEqual(
        SpriteSheetGeometry.cells(imageSize: CGSize(width: 1254, height: 1254)),
        [
            CGRect(x: 0, y: 627, width: 627, height: 627),
            CGRect(x: 627, y: 627, width: 627, height: 627),
            CGRect(x: 0, y: 0, width: 627, height: 627),
            CGRect(x: 627, y: 0, width: 627, height: 627),
        ]
    )
}

func testCanonicalMaskReplacesVariantAlphaWithoutChangingRGBInsideMask() {
    let result = SpriteMasking.applyCanonicalAlpha(variant: variantPixels, canonical: alphaMask)
    XCTAssertEqual(result.alphaBytes, alphaMask)
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `swift test --filter SpriteSheetGeometryTests`

Expected: compilation fails because sheet geometry and masking helpers do not exist.

- [ ] **Step 3: Add the executable target**

Update `Package.swift`:

```swift
products: [
    .library(name: "OpenNekoKit", targets: ["OpenNekoKit"]),
    .executable(name: "SpritePipeline", targets: ["SpritePipeline"]),
],
targets: [
    .target(name: "OpenNekoKit"),
    .executableTarget(name: "SpritePipeline", dependencies: ["OpenNekoKit"]),
    .testTarget(name: "OpenNekoKitTests", dependencies: ["OpenNekoKit"]),
]
```

- [ ] **Step 4: Implement deterministic extraction**

Support this exact command:

```bash
swift run SpritePipeline extract \
  --sheet assets/gen/sprite-redesign/sheets/default/idle.png \
  --state idle \
  --output /tmp/openneko-sprites/default \
  --canvas 128 \
  --padding 12
```

Extraction must split in reading order, reject nonsquare or odd-sized sheets, resize with nearest-neighbor sampling, center by alpha bounds, zero RGB under zero alpha, and write `idle_0.png` through `idle_3.png` only if all four frames pass the basic contract.

- [ ] **Step 5: Implement canonical variant masks and contact sheets**

Support:

```bash
swift run SpritePipeline extract \
  --sheet assets/gen/sprite-redesign/sheets/black/idle.png \
  --state idle \
  --output /tmp/openneko-sprites/black \
  --canonical /tmp/openneko-sprites/default

swift run SpritePipeline contact-sheet \
  --sprites /tmp/openneko-sprites \
  --output output/sprite-review
```

The contact sheet command writes one labeled 15-row x 4-column PNG per skin and one five-skin comparison sheet per state.

- [ ] **Step 6: Run tests and a synthetic CLI smoke test**

Run: `swift test --filter SpriteSheetGeometryTests`

Expected: all tests pass.

Run: `swift run SpritePipeline --help`

Expected: exit 0 and list `extract`, `validate`, and `contact-sheet`.

- [ ] **Step 7: Commit the pipeline**

```bash
git add Package.swift Sources/SpritePipeline Tests/OpenNekoKitTests/SpriteSheetGeometryTests.swift
git commit -m "feat: add deterministic sprite extraction pipeline"
```

### Task 3: Add The Skin-Specific Punch Contract

**Files:**
- Modify: `App/Resources/sprites/manifest.json`
- Modify: `Sources/OpenNekoKit/Skin/Skin.swift`
- Modify: `App/CatScene.swift`
- Modify: `Tests/OpenNekoKitTests/SkinManagerTests.swift`
- Create: `Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift`

**Interfaces:**
- Produces: `Skin.animationFrameURLs(for:fallbackState:requiredCount:)` and active-skin punch loading.
- Consumes: the 60-frame per-skin asset contract generated by later tasks.

- [ ] **Step 1: Write failing punch and compatibility tests**

```swift
func testPunchUsesFourSkinFramesWhenPresent() throws {
    let skin = makeSkin(states: ["punch": ["punch_0.png", "punch_1.png", "punch_2.png", "punch_3.png"]])
    XCTAssertEqual(
        skin.animationFrameURLs(for: "punch", fallbackState: "click", requiredCount: 4)
            .map(\.lastPathComponent),
        ["punch_0.png", "punch_1.png", "punch_2.png", "punch_3.png"]
    )
}

func testLegacySkinFallsBackToClickWhenPunchIsMissing() throws {
    let skin = makeSkin(states: ["click": ["click_0.png", "click_1.png", "click_2.png", "click_3.png"]])
    XCTAssertEqual(
        skin.animationFrameURLs(for: "punch", fallbackState: "click", requiredCount: 4)
            .map(\.lastPathComponent),
        ["click_0.png", "click_1.png", "click_2.png", "click_3.png"]
    )
}
```

- [ ] **Step 2: Run focused tests and confirm RED**

Run: `swift test --filter SkinManagerTests`

Expected: compilation fails because the fallback API does not exist.

- [ ] **Step 3: Implement fallback resolution and update manifest**

Add to `Skin`:

```swift
public func animationFrameURLs(
    for state: String,
    fallbackState: String? = nil,
    requiredCount: Int? = nil
) -> [URL]
```

Return primary frames only when they match `requiredCount`; otherwise resolve the fallback. Add `punch_0.png` through `punch_3.png` to the root manifest.

- [ ] **Step 4: Load punch textures from the active skin**

Replace global effect-directory loading in `CatScene` with:

```swift
private func loadPunchTextures() -> [SKTexture] {
    guard let skin else { return [] }
    return skin.animationFrameURLs(for: "punch", fallbackState: "click", requiredCount: 4)
        .compactMap(loadTexture)
}
```

Invalidate the cached punch textures whenever `apply(skin:)` changes the active skin. Keep nearest-neighbor filtering and the existing three-hit timing.

- [ ] **Step 5: Run focused tests and compile the app**

Run: `swift test --filter SkinManagerTests`

Expected: primary and fallback tests pass.

Run: `xcodegen generate && xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build`

Expected: `BUILD SUCCEEDED` once temporary punch fixtures exist; do not remove the existing global effect frames until Task 7 installs the new bundle.

- [ ] **Step 6: Commit runtime support**

```bash
git add App/Resources/sprites/manifest.json Sources/OpenNekoKit/Skin/Skin.swift App/CatScene.swift Tests/OpenNekoKitTests/SkinManagerTests.swift Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift
git commit -m "feat: load punch frames from active skin"
```

### Task 4: Create The Reproducible Art Recipe

**Files:**
- Create: `assets/gen/sprite-redesign/README.md`
- Create: `assets/gen/sprite-redesign/prompts/identity-master.md`
- Create: `assets/gen/sprite-redesign/state-specs.json`
- Create: `assets/gen/sprite-redesign/skin-specs.json`
- Create: `assets/gen/sprite-redesign/reference/full-redesign-concept.png`

**Interfaces:**
- Produces: complete prompt inputs and stable source paths for Tasks 5 and 6.
- Consumes: approved design spec and updated AI-sparkle concept.

- [ ] **Step 1: Record the immutable identity prompt**

The prompt must explicitly lock: large rounded head, short body, ear roots, eye spacing, circular headset, cyan collar core, navy paws and tail tip, and the centered four-point forehead sparkle sigil drawn as part of the character pixels. It must forbid text, Unicode glyph rendering, checkerboards, borders, anatomy drift, cropped pixels, canvas-edge contact, and any separate overlay-style effect layer.

- [ ] **Step 2: Record all state choreography as structured data**

Write all 15 state entries with exactly four frame descriptions. The `thinking` entry must be:

```json
{
  "thinking": [
    "seated head tilt, forehead sparkle dim and crisp",
    "one paw near chin, tight cyan pulse around the same forehead mark",
    "focused eyes, cyan-white four-point peak inside a mint-to-ivory-to-pale-yellow circular bloom with at most three cyan-mint particles",
    "relaxed pose, small residual glow returning to the original dim mark"
  ]
}
```

- [ ] **Step 3: Record exact skin-only transformations**

Each variant prompt says `change fur palette and markings only; preserve every pixel of anatomy, equipment geometry, pose, baseline, prop, and alpha silhouette`. Define default, black, calico, orange, and pink palettes in `skin-specs.json`.

- [ ] **Step 4: Document source and output naming**

Use:

```text
assets/gen/sprite-redesign/master/default-identity.png
assets/gen/sprite-redesign/sheets/<skin>/<state>.png
App/Resources/sprites/<state>_<frame>.png
App/Resources/sprites/<skin>/<state>_<frame>.png
```

Document that generated source sheets are retained for reproducibility but never loaded by the runtime.

- [ ] **Step 5: Commit the recipe**

```bash
git add assets/gen/sprite-redesign
git commit -m "docs: add reproducible sprite art recipe"
```

### Task 5: Generate And Approve The Canonical Default Skin

**Files:**
- Create: `assets/gen/sprite-redesign/master/default-identity.png`
- Create: `assets/gen/sprite-redesign/sheets/default/*.png`
- Create: `output/sprite-review/default-contact-sheet.png`
- Replace later: `App/Resources/sprites/*.png`

**Interfaces:**
- Produces: 15 approved default 2x2 sheets and 60 canonical frames.
- Consumes: Task 4 prompts and Task 2 extraction CLI.

- [ ] **Step 1: Back up all existing runtime sprites**

Run:

```bash
timestamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "output/sprite-backups/$timestamp"
ditto App/Resources/sprites "output/sprite-backups/$timestamp/sprites"
```

Expected: backup contains the existing manifest, 280 skin frames, and four global punch-effect frames.

- [ ] **Step 2: Generate the identity master with actual transparency**

Use OpenAI image generation at high quality. Inspect the resulting file with `sips -g hasAlpha`; reject any result with baked checkerboard or no alpha. The forehead mark must be the same compact four-point cyan sparkle in front, side, and three-quarter views.

- [ ] **Step 3: Generate the 15 default 2x2 state sheets**

Use the identity master as the reference on every call and append one state entry from `state-specs.json`. Generate one state at a time, inspect immediately, and regenerate only the failing state when identity, cell isolation, padding, or choreography is wrong.

- [ ] **Step 4: Extract all 60 default frames**

Run one `SpritePipeline extract` command per state into `/tmp/openneko-sprites/default`, then:

```bash
swift run SpritePipeline validate --sprites /tmp/openneko-sprites --skin default
swift run SpritePipeline contact-sheet --sprites /tmp/openneko-sprites --skin default --output output/sprite-review
```

Expected: 60 files, zero blocking quality issues, and a complete default contact sheet.

- [ ] **Step 5: Visually review every default cycle**

Check character identity, AI-sigil shape, face-center stability, prop containment, motion readability, and `thinking` glow progression. Regenerate and re-extract any state that fails visual review.

- [ ] **Step 6: Commit canonical sources only after approval**

```bash
git add assets/gen/sprite-redesign/master assets/gen/sprite-redesign/sheets/default output/sprite-review/default-contact-sheet.png
git commit -m "art: generate canonical redesigned cat sprites"
```

### Task 6: Generate Four Geometry-Locked Skin Variants

**Files:**
- Create: `assets/gen/sprite-redesign/sheets/black/*.png`
- Create: `assets/gen/sprite-redesign/sheets/calico/*.png`
- Create: `assets/gen/sprite-redesign/sheets/orange/*.png`
- Create: `assets/gen/sprite-redesign/sheets/pink/*.png`
- Create: `output/sprite-review/<skin>-contact-sheet.png`

**Interfaces:**
- Produces: 60 source sheets and 240 validated variant frames.
- Consumes: approved default sheets, `skin-specs.json`, and canonical masks from Task 5.

- [ ] **Step 1: Transform each default sheet with high input fidelity**

For each state and skin, use the default state sheet as the edit input. Change fur palette and markings only. Reject changes to pose, equipment, props, canvas placement, facial geometry, tail bands, or forehead-sigil shape.

- [ ] **Step 2: Extract with canonical alpha enforcement**

Run `SpritePipeline extract` with `--canonical /tmp/openneko-sprites/default` for every variant state. The output alpha bytes for matching state/frame pairs must equal the default alpha bytes exactly.

- [ ] **Step 3: Validate each completed skin before starting the next**

Run:

```bash
swift run SpritePipeline validate --sprites /tmp/openneko-sprites --skin black
swift run SpritePipeline contact-sheet --sprites /tmp/openneko-sprites --skin black --output output/sprite-review
```

Repeat for `calico`, `orange`, and `pink`. Expected: 60 valid files and zero silhouette mismatches per skin.

- [ ] **Step 4: Review cross-skin state comparison sheets**

Confirm that all five skins share pose, scale, baseline, props, expression, AI-sigil placement, and frame timing. Regenerate a variant sheet when recoloring changed internal anatomy or equipment details even if its alpha mask passes.

- [ ] **Step 5: Commit approved variant sources and review sheets**

```bash
git add assets/gen/sprite-redesign/sheets/{black,calico,orange,pink} output/sprite-review
git commit -m "art: generate redesigned bundled skin variants"
```

### Task 7: Install And Validate The 300 Runtime Frames

**Files:**
- Replace: `App/Resources/sprites/*.png`
- Replace: `App/Resources/sprites/black/*.png`
- Replace: `App/Resources/sprites/calico/*.png`
- Replace: `App/Resources/sprites/orange/*.png`
- Replace: `App/Resources/sprites/pink/*.png`
- Delete: `App/Resources/sprites/effects/nyang_punch_0.png`
- Delete: `App/Resources/sprites/effects/nyang_punch_1.png`
- Delete: `App/Resources/sprites/effects/nyang_punch_2.png`
- Delete: `App/Resources/sprites/effects/nyang_punch_3.png`
- Modify: `Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift`

**Interfaces:**
- Produces: the final runtime bundle consumed by `SkinManager` and `CatScene`.
- Consumes: all 300 approved files from Tasks 5 and 6.

- [ ] **Step 1: Write the failing bundled-resource test**

```swift
func testEveryBundledSkinContainsSixtyValidFrames() throws {
    let expectedStates = Set([
        "idle", "hover", "click", "coding", "typing", "thinking", "lunch", "yawn",
        "nap", "success", "error", "dragging", "walk", "jump", "punch",
    ])
    XCTAssertEqual(Set(manifest.stateNames), expectedStates)
    for skinID in ["default", "black", "calico", "orange", "pink"] {
        XCTAssertEqual(try frameURLs(skinID: skinID).count, 60)
    }
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run: `swift test --filter BundledSpriteManifestTests`

Expected: failure because the runtime folders do not yet contain per-skin `punch` frames.

- [ ] **Step 3: Copy approved frames into runtime folders**

Copy from `/tmp/openneko-sprites` without changing filenames. Remove the obsolete global character effect frames only after all five `punch` cycles exist.

- [ ] **Step 4: Run strict bundle validation**

Run:

```bash
swift run SpritePipeline validate \
  --sprites App/Resources/sprites \
  --manifest App/Resources/sprites/manifest.json \
  --report output/sprite-review/validation.json
```

Expected: exactly 300 frames and zero errors for dimensions, alpha, edge contact, padding, alignment, silhouette, duplicate motion, or AI-sigil progression.

- [ ] **Step 5: Run full tests**

Run: `swift test`

Expected: all tests pass.

- [ ] **Step 6: Commit the runtime bundle**

```bash
git add App/Resources/sprites Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift output/sprite-review/validation.json
git commit -m "art: replace bundled sprites with unified redesign"
```

### Task 8: Synchronize Website Preview Assets

**Files:**
- Replace: `docs/assets/sprites/**/*.png`
- Create: `scripts/sync-doc-sprites.sh`
- Test: `Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift`

**Interfaces:**
- Produces: website previews that match the app's redesigned runtime assets.
- Consumes: the curated paths referenced by `docs/index.html`.

- [ ] **Step 1: Add a failing referenced-file parity test**

Parse every `assets/sprites/...png` reference in `docs/index.html`, assert the docs file exists, then compare its SHA-256 with the matching file under `App/Resources/sprites`.

- [ ] **Step 2: Run the focused test and confirm RED**

Run: `swift test --filter BundledSpriteManifestTests`

Expected: parity failures because docs still contain old art.

- [ ] **Step 3: Implement deterministic docs synchronization**

`scripts/sync-doc-sprites.sh` extracts unique sprite paths from `docs/index.html`, creates matching directories, and copies only those exact files from `App/Resources/sprites`.

- [ ] **Step 4: Synchronize and re-run parity tests**

Run: `bash scripts/sync-doc-sprites.sh && swift test --filter BundledSpriteManifestTests`

Expected: all docs references exist and hashes match runtime assets.

- [ ] **Step 5: Commit website assets**

```bash
git add scripts/sync-doc-sprites.sh docs/assets/sprites Tests/OpenNekoKitTests/BundledSpriteManifestTests.swift
git commit -m "docs: sync redesigned sprite previews"
```

### Task 9: Build, Relaunch, And Capture Every Runtime State

**Files:**
- Create: `output/sprite-review/runtime/`
- Modify only if defects are found: generated sheets or extraction configuration for the failing state

**Interfaces:**
- Consumes: final runtime bundle and existing `/state`, `/anim`, and `/capture` debug endpoints.
- Produces: final visual evidence for all states, skins, and the three-hit punch sequence.

- [ ] **Step 1: Run final static verification**

Run:

```bash
git diff --check
swift test
xcodegen generate
xcodebuild -project OpenNeko.xcodeproj -scheme OpenNeko -configuration Debug -destination 'platform=macOS' -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: clean diff check, all tests pass, and `BUILD SUCCEEDED`.

- [ ] **Step 2: Fully quit and relaunch the new product**

Run:

```bash
pkill -x OpenNeko || true
pgrep -fl OpenNeko
/usr/bin/open -n .derivedData/Build/Products/Debug/OpenNeko.app
curl -fsS http://127.0.0.1:48800/health
```

Expected: no old process before launch, one new product process afterward, and `openneko` health response.

- [ ] **Step 3: Capture every default state**

POST each state to `http://127.0.0.1:48800/state`, capture all four animation phases, and save labeled images under `output/sprite-review/runtime/default/<state>/`. Verify the AI sparkle remains dim except for the four-stage `thinking` glow.

- [ ] **Step 4: Capture representative cycles for all variants**

For each of `black`, `calico`, `orange`, and `pink`, capture `idle`, `walk`, `thinking`, `typing`, `success`, and `punch`. Confirm the selected skin never changes anatomy, equipment, or fur identity between states.

- [ ] **Step 5: Verify the complete three-hit punch sequence**

Place OpenNeko beside the visible Codex pet, capture the full sequence, and confirm all three repetitions use the selected skin's `punch` frames with stable scale, baseline, direction, and AI forehead sigil.

- [ ] **Step 6: Perform the completion audit**

Check every requirement in `docs/superpowers/specs/2026-07-12-unified-sprite-redesign-design.md` against the manifest, validation report, contact sheets, test output, build output, running process, and runtime captures. Do not mark completion if any of the 300 frames or required visual checks lacks evidence.

- [ ] **Step 7: Commit final review artifacts only if they are intended for version control**

```bash
git add output/sprite-review/runtime
git commit -m "test: capture unified sprite runtime verification"
```
