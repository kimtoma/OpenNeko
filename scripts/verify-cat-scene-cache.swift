import AppKit
import CryptoKit
import Foundation
import Metal
import OpenNekoKit
import SpriteKit

/// Native regression checks and a small drag-update benchmark; see the shell wrapper.
/// Add --verify-actions for offscreen animation completion checks with local Metal access.
@main
enum CatSceneCacheVerification {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    private struct AlphaBounds {
        let sourceData: Data
        let pixelSize: CGSize
        let bounds: CGRect
    }
    @MainActor private static var alphaBoundsByURL: [URL: AlphaBounds] = [:]

    @MainActor
    private final class GPUSceneRenderer {
        let scene: CatScene
        let side: Int
        private let renderer: SKRenderer
        private let queue: MTLCommandQueue
        private let target: MTLTexture
        private let pass = MTLRenderPassDescriptor()
        private let start = ProcessInfo.processInfo.systemUptime
        private var elapsed: TimeInterval = 0

        init(scene: CatScene, capturePixels: Int = 256) throws {
            _ = NSApplication.shared
            try require((1...8192).contains(capturePixels), "capture size must be between 1 and 8192 pixels")
            let device = try unwrap(MTLCreateSystemDefaultDevice(), "offscreen rendering requires local Metal access")
            self.scene = scene
            side = capturePixels
            queue = try unwrap(device.makeCommandQueue(), "could not create a Metal command queue")
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: capturePixels, height: capturePixels, mipmapped: false)
            descriptor.usage = [.renderTarget]
            descriptor.storageMode = .shared
            target = try unwrap(device.makeTexture(descriptor: descriptor), "could not create the capture texture")
            renderer = SKRenderer(device: device)
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            renderer.scene = scene
            renderer.update(atTime: start)
        }

        func advance(to targetTime: TimeInterval) {
            while elapsed + 1.0 / 60 < targetTime {
                elapsed += 1.0 / 60
                renderer.update(atTime: start + elapsed)
            }
            if targetTime > elapsed {
                elapsed = targetTime
                renderer.update(atTime: start + elapsed)
            }
        }

        func capture() throws -> (png: Data, rgba: [UInt8]) {
            let buffer = try unwrap(queue.makeCommandBuffer(), "could not create a capture command buffer")
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: side, height: side),
                            commandBuffer: buffer, renderPassDescriptor: pass)
            buffer.commit()
            buffer.waitUntilCompleted()
            try require(buffer.status == .completed && buffer.error == nil, "Metal capture failed: \(String(describing: buffer.error))")
            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            pixels.withUnsafeMutableBytes { bytes in
                target.getBytes(bytes.baseAddress!, bytesPerRow: side * 4,
                                from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
            }
            let bitmap = try unwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32), "could not allocate capture bitmap")
            pixels.withUnsafeBufferPointer { source in
                bitmap.bitmapData!.update(from: source.baseAddress!, count: source.count)
            }
            return (try unwrap(bitmap.representation(using: .png, properties: [:]), "could not encode capture PNG"), pixels)
        }
    }

    @MainActor
    private static func verifyHighResolutionRendering(sourceSize: Int) throws {
        _ = NSApplication.shared
        try require(MTLCreateSystemDefaultDevice() != nil, "high-resolution checks require local Metal access")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-highres-fixtures-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let skin = try makePaddedSkin(directory: root, size: sourceSize)
        let bottomInset = sourceSize * 12 / 128
        let dragTopInset = sourceSize * 18 / 128
        let metadata = root.appendingPathComponent("render-info.json")
        try writeRenderInfo(at: metadata, canvasHeight: sourceSize, bottomInset: bottomInset, dragTopInset: dragTopInset,
                            displayHeight: 128, filtering: "linear")
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let sprite = try spriteNode(in: scene, zPosition: 0)
        let texture = try unwrap(sprite.texture, "high-resolution idle should be available")
        try require(texture.size() == CGSize(width: 128, height: 128) && sprite.size == texture.size(),
                    "\(sourceSize)px input must have a 128pt texture and sprite size")
        try require(texture.cgImage().width == sourceSize && texture.cgImage().height == sourceSize,
                    "the high-resolution texture lost its \(sourceSize)px backing representation")
        try require(texture.filteringMode == .linear && sprite.position.y == 54, "high-resolution filtering or ground line changed")
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        try require(sprite.size.height == 128 && sprite.anchorPoint.y == 1 - CGFloat(dragTopInset) / CGFloat(sourceSize),
                    "high-resolution drag pinning must use source-pixel insets at 128pt")
        let dragTexture = try unwrap(sprite.texture, "high-resolution drag should be displayed")
        for _ in 0..<600 {
            scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
            try require(sprite.texture === dragTexture, "\(sourceSize)px dragging recreated its cached texture")
        }
        scene.showFalling()
        try require(sprite.texture === dragTexture, "\(sourceSize)px falling did not reuse the drag texture")
        try writeRenderInfo(at: metadata, canvasHeight: sourceSize, bottomInset: bottomInset, displayHeight: 64, filtering: "nearest")
        scene.play(state: .idle)
        try require(sprite.size.height == 128 && sprite.texture?.filteringMode == .linear, "display metadata was reread between states")
        scene.apply(skin: skin)
        try require(sprite.size.height == 64 && sprite.texture?.filteringMode == .nearest,
                    "skin refresh should reload display size and filtering together")
        try writeRenderInfo(at: metadata, canvasHeight: sourceSize, bottomInset: bottomInset, displayHeight: 128, filtering: "linear")

        let wideWidth = sourceSize * 3 / 2
        try writeFrame(at: root.appendingPathComponent("wide.png"), width: wideWidth, height: sourceSize,
                       bottomInset: bottomInset, topInset: bottomInset)
        let wideSkin = Skin(id: "wide", directory: root,
                            manifest: try SpriteManifest(data: Data(#"{"idle":["wide.png"]}"#.utf8)))
        scene.apply(skin: wideSkin)
        try require(sprite.size == CGSize(width: 192, height: 128) && sprite.texture?.cgImage().width == wideWidth,
                    "displayHeight must preserve a non-square source's aspect ratio and pixel width")

        // A retained backing image alone is insufficient: a source-resolution
        // GPU capture must still resolve alternating one-source-pixel detail.
        try writeDetailFrame(at: root.appendingPathComponent("detail.png"), size: sourceSize)
        try writeRenderInfo(at: metadata, canvasHeight: sourceSize, bottomInset: 0, displayHeight: 128, filtering: "linear")
        let detailSkin = Skin(id: "detail", directory: root,
                              manifest: try SpriteManifest(data: Data(#"{"idle":["detail.png"]}"#.utf8)))
        scene.apply(skin: detailSkin)
        scene.setCatOrigin(CGPoint(x: 0, y: -2)) // Fill the viewport with the opaque detail fixture.
        let gpu = try GPUSceneRenderer(scene: scene, capturePixels: sourceSize)
        gpu.advance(to: 4.0 / 60)
        let capture = try gpu.capture()
        let margin = sourceSize / 16
        let row = (margin..<(sourceSize - margin)).map { Int(capture.rgba[(sourceSize / 2 * sourceSize + $0) * 4]) }
        try require(zip(row, row.dropFirst()).allSatisfy { abs($0.0 - $0.1) > 240 },
                    "the 128pt GPU rendering resampled away retained \(sourceSize)px source detail")
        let decoded = try unwrap(NSBitmapImageRep(data: capture.png), "high-resolution capture PNG did not decode")
        try require(decoded.pixelsWide == sourceSize && decoded.pixelsHigh == sourceSize,
                    "source-resolution capture must be \(sourceSize)px square")
        scene.setCatOrigin(.zero)

        let resources = try unwrap(Bundle.main.resourceURL, "expected harness bundle resources")
        try require(resources.lastPathComponent.hasPrefix("openneko-cat-scene-cache."), "use the shell wrapper for effect fixtures")
        let effects = resources.appendingPathComponent("sprites/effects", isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: effects.path), "effect fixture directory already exists")
        try FileManager.default.createDirectory(at: effects, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: effects) }
        for index in 0..<4 {
            try writeFrame(at: effects.appendingPathComponent("nyang_punch_\(index).png"), width: sourceSize, height: sourceSize,
                           bottomInset: bottomInset, topInset: bottomInset)
        }
        try writeRenderInfo(at: effects.appendingPathComponent("render-info.json"), canvasHeight: sourceSize, bottomInset: bottomInset,
                            displayHeight: 128, filtering: "linear")
        try writeRenderInfo(at: metadata, canvasHeight: sourceSize, bottomInset: bottomInset, displayHeight: 128, filtering: "linear")
        scene.apply(skin: skin)
        scene.playPunch(direction: 1)
        let punch = try spriteNode(in: scene, zPosition: 2)
        let punchTexture = try unwrap(punch.texture, "expected the high-resolution global punch")
        try require(punch.size == CGSize(width: 128, height: 128) && punch.position.y == 54
                    && punchTexture.cgImage().height == sourceSize && punchTexture.filteringMode == .linear,
                    "the global punch must retain \(sourceSize)px pixels at its 128pt grounded size")
        scene.play(state: .idle)
        let legacy = try makeSkin(directory: root.appendingPathComponent("legacy"), width: 24)
        scene.apply(skin: legacy)
        try require(sprite.size == CGSize(width: 24, height: 16) && sprite.position.y == 64
                    && sprite.texture?.filteringMode == .nearest, "switching from high-resolution to legacy changed legacy rendering")
    }

    private static func writeDetailFrame(at url: URL, size: Int) throws {
        let bitmap = try unwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32), "could not create the detail fixture")
        for y in 0..<size {
            for x in 0..<size {
                let pixel = bitmap.bitmapData! + y * bitmap.bytesPerRow + x * 4
                let value: UInt8 = (x + y).isMultiple(of: 2) ? 255 : 0
                pixel[0] = value
                pixel[1] = value
                pixel[2] = value
                pixel[3] = 255
            }
        }
        try unwrap(bitmap.representation(using: .png, properties: [:]), "could not encode the detail fixture").write(to: url)
    }

    @MainActor
    private static func captureFrameCycles(spritesRoot: URL, output: URL, states: [CatState],
                                           expectedSourcePixels: Int?, capturePixels: Int) throws {
        let root = spritesRoot.resolvingSymlinksInPath().standardizedFileURL
        let sourcePixels = try expectedSourcePixels ?? declaredSourcePixels(in: root)
        let manager = SkinManager(bundledRoot: root)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let oneShotStates: Set<CatState> = [.click, .yawn, .success, .error, .jump]
        var records: [[String: Any]] = []
        var dragLimitRecords: [[String: Any]] = []
        for id in ["default", "black", "orange", "calico", "pink"] {
            let skin = try manager.loadSkin(id: id)
            for state in states {
                let frames = try autoreleasepool {
                    let sources = skin.frameURLs(for: state.rawValue)
                    try require(sources.count == 4, "frame-cycle capture requires four frames: \(id)/\(state)")
                    let scene = CatScene(size: CGSize(width: 128, height: 128))
                    scene.apply(skin: skin)
                    let gpu = try GPUSceneRenderer(scene: scene, capturePixels: capturePixels)
                    let node = try spriteNode(in: scene, zPosition: 0)
                    if oneShotStates.contains(state) {
                        scene.playOnce(state: state)
                    } else if state == .walk {
                        scene.playWalk(direction: 1)
                    } else if state != .dragging {
                        scene.play(state: state)
                    }
                    var elapsed = 2.0 / 60
                    var previousTexture: ObjectIdentifier?
                    var textureIDs: Set<ObjectIdentifier> = []
                    var result: [[String: Any]] = []
                    for index in sources.indices {
                        var dragInput: [String: Double]?
                        if state == .dragging {
                            // Exercise the same pose selector and pinning used
                            // by CatWindow, including both movement directions.
                            let velocity: CGFloat = index == 1 ? 8 : index == 3 ? -8 : 0
                            let time = index == 2 ? CatDragGeometry.idleWrigglePeriod + 0.03 : 0
                            try require(CatDragGeometry.dangleFrameIndex(horizontalVelocity: velocity, time: time) == index,
                                        "drag input no longer selects frame \(index)")
                            scene.showDragging(horizontalVelocity: velocity, horizontalAcceleration: 0, time: time)
                            elapsed += 1.0 / 60
                            gpu.advance(to: elapsed)
                            dragInput = ["horizontal_velocity": Double(velocity), "time": time]
                        } else {
                            gpu.advance(to: elapsed)
                            if let previousTexture {
                                let deadline = elapsed + 2
                                while node.texture.map(ObjectIdentifier.init) == previousTexture && elapsed < deadline {
                                    elapsed += 1.0 / 60
                                    gpu.advance(to: elapsed)
                                }
                            }
                        }
                        try require(scene.displayedState == state, "\(id)/\(state) ended before frame \(index)")
                        let texture = try unwrap(node.texture, "missing running texture for \(id)/\(state)/\(index)")
                        let textureID = ObjectIdentifier(texture)
                        try require(textureIDs.insert(textureID).inserted, "\(id)/\(state) repeated a texture before all four frames")
                        previousTexture = textureID
                        let sourceBitmap = try unwrap(NSBitmapImageRep(data: Data(contentsOf: sources[index])), "source frame did not decode")
                        let sourceImage = try unwrap(sourceBitmap.cgImage, "source frame has no CGImage")
                        let sourceDigest = try imagePixelDigest(sourceImage)
                        let textureDigest = try imagePixelDigest(texture.cgImage())
                        try require(sourceDigest == textureDigest,
                                    "\(id)/\(state) running texture does not match expected source frame \(index)")
                        var record = try captureRecord(
                            gpu: gpu, node: node, skin: id, requestedState: state, source: sources[index],
                            metadataDirectory: skin.directory, expectedSourcePixels: sourcePixels,
                            destination: output.appendingPathComponent("\(id)-\(state.rawValue)-\(index).png"))
                        record["frame_index"] = index
                        record["sample_time_seconds"] = elapsed
                        record["source_texture_rgba_sha256"] = sourceDigest
                        record["running_texture_matches_source"] = true
                        record["runtime_path"] = state == .dragging ? "showDragging" : "SKAction"
                        if let dragInput { record["drag_input"] = dragInput }
                        result.append(record)
                        elapsed += 1.0 / 60
                    }
                    try require(textureIDs.count == 4, "expected four runtime textures for \(id)/\(state)")
                    if state == .dragging {
                        // Catch clipping at the production swing/offset limits,
                        // and at the idle bob peaks between the four pose samples.
                        let samples: [(String, CGFloat, CGFloat, TimeInterval)] = [
                            ("fast-right", 40, 0, 0), ("fast-left", -40, 0, 0),
                            ("accelerating-right", 40, 80, 0), ("accelerating-left", -40, -80, 0),
                            ("idle-bob-first", 0, 0, 0.0525), ("idle-bob-second", 0, 0, 0.2325),
                        ]
                        for (name, velocity, acceleration, time) in samples {
                            let index = CatDragGeometry.dangleFrameIndex(
                                horizontalVelocity: velocity, horizontalAcceleration: acceleration, time: time)
                            scene.showDragging(horizontalVelocity: velocity, horizontalAcceleration: acceleration, time: time)
                            elapsed += 1.0 / 60
                            gpu.advance(to: elapsed)
                            var record = try captureRecord(
                                gpu: gpu, node: node, skin: id, requestedState: state, source: sources[index],
                                metadataDirectory: skin.directory, expectedSourcePixels: sourcePixels,
                                destination: output.appendingPathComponent("\(id)-drag-limit-\(name).png"))
                            record["sample"] = name
                            record["frame_index"] = index
                            record["drag_input"] = ["velocity": Double(velocity), "acceleration": Double(acceleration), "time": time]
                            record["rotation_radians"] = Double(node.zRotation)
                            dragLimitRecords.append(record)
                        }
                    }
                    return result
                }
                records.append(contentsOf: frames)
            }
        }
        try require(records.count == 5 * states.count * 4, "incomplete runtime frame cycles")
        let report: [String: Any] = [
            "scope": "Every requested animation frame through real CatScene; dragging uses live pose selection and pinning",
            "sprites_root": root.path,
            "requested_states": states.map(\.rawValue),
            "scene_points": [128, 128],
            "capture_pixels": [capturePixels, capturePixels],
            "frame_count": records.count,
            "all_running_textures_match_source": true,
            "all_viewport_borders_transparent": true,
            "frames": records,
            "drag_limit_frame_count": dragLimitRecords.count,
            "drag_limit_frames": dragLimitRecords,
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("report.json"), options: .atomic)
        let dragDetail = states.contains(.dragging) ? ", including actual drag poses" : ""
        print("PASS: \(records.count) source-matched runtime animation frames\(dragDetail); report=\(output.appendingPathComponent("report.json").path)")
    }

    private static func imagePixelDigest(_ image: CGImage) throws -> String {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try unwrap(CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                "could not normalize frame pixels")
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return sha256(Data(pixels))
    }

    @MainActor
    private static func captureBuiltSprites(spritesRoot: URL, output: URL,
                                            expectedSourcePixels: Int?, capturePixels: Int) throws {
        _ = NSApplication.shared
        let root = spritesRoot.resolvingSymlinksInPath().standardizedFileURL
        let sourcePixels = try expectedSourcePixels ?? declaredSourcePixels(in: root)
        let manager = SkinManager(bundledRoot: root)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let oneShotStates: Set<CatState> = [.click, .yawn, .success, .error, .jump]
        var states: [[String: Any]] = []
        for id in ["default", "black", "orange", "calico", "pink"] {
            let skin = try manager.loadSkin(id: id)
            for state in CatState.allCases {
                // Release each independent scene's decoded images and Metal
                // resources before loading the next high-resolution state.
                let record = try autoreleasepool {
                    let scene = CatScene(size: CGSize(width: 128, height: 128))
                    scene.apply(skin: skin)
                    let gpu = try GPUSceneRenderer(scene: scene, capturePixels: capturePixels)
                    if oneShotStates.contains(state) {
                        scene.playOnce(state: state)
                    } else if state == .walk {
                        scene.playWalk(direction: 1)
                    } else {
                        scene.play(state: state)
                    }
                    gpu.advance(to: 4.0 / 60)
                    try require(scene.displayedState == state, "\(id)/\(state) changed state before its deterministic capture")
                    let source = try unwrap(skin.frameURLs(for: state.rawValue).first, "missing \(id)/\(state) source frame")
                    return try captureRecord(gpu: gpu, node: spriteNode(in: scene, zPosition: 0),
                                             skin: id, requestedState: state, source: source,
                                             metadataDirectory: skin.directory, expectedSourcePixels: sourcePixels,
                                             destination: output.appendingPathComponent("\(id)-\(state.rawValue).png"))
                }
                states.append(record)
            }
        }
        try require(states.count == 70, "expected 5 skins × 14 state captures")
        let idleHashes = Set(states.filter { ($0["requested_state"] as? String) == "idle" }
            .compactMap { $0["png_sha256"] as? String })
        try require(idleHashes.count == 5, "the five skin idle captures must be visually distinct")

        var punches: [[String: Any]] = []
        var punchDirectionChecks: [[String: Any]] = []
        let sourceEffects = root.appendingPathComponent("effects", isDirectory: true)
        if FileManager.default.fileExists(atPath: sourceEffects.path) {
            let resources = try unwrap(Bundle.main.resourceURL, "expected the harness bundle resource directory")
            try require(resources.lastPathComponent.hasPrefix("openneko-cat-scene-cache."), "use the shell wrapper for built effects capture")
            let copiedEffects = resources.appendingPathComponent("sprites/effects", isDirectory: true)
            try require(!FileManager.default.fileExists(atPath: copiedEffects.path), "effect fixtures were not cleaned up before artifact capture")
            try FileManager.default.createDirectory(at: copiedEffects.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceEffects, to: copiedEffects)
            defer { try? FileManager.default.removeItem(at: copiedEffects) }
            let sourceFacing = try declaredPunchFacing(in: sourceEffects)
            for direction in [1, -1] {
                try autoreleasepool {
                    let scene = CatScene(size: CGSize(width: 128, height: 128))
                    scene.apply(skin: try manager.loadSkin(id: "default"))
                    let gpu = try GPUSceneRenderer(scene: scene, capturePixels: capturePixels)
                    scene.playPunch(direction: direction)
                    let punch = try spriteNode(in: scene, zPosition: 2)
                    var textureIDs: Set<ObjectIdentifier> = []
                    for index in 0..<4 {
                        let sampleTime = ScreenPetPunchSequence.default.leadInDuration
                            + (Double(index) + 0.5) * ScreenPetPunchSequence.default.frameDuration
                        gpu.advance(to: sampleTime)
                        try require(scene.displayedState == .click && !punch.isHidden, "punch frame \(index) ended before capture")
                        let texture = try unwrap(punch.texture, "punch frame \(index) has no texture")
                        textureIDs.insert(ObjectIdentifier(texture))
                        var directionRecord = try punchDirectionRecord(node: punch, targetDirection: direction,
                                                                        sourceFacing: sourceFacing)
                        directionRecord["punch_frame"] = index
                        directionRecord["sample_time_seconds"] = sampleTime
                        directionRecord["png_captured"] = direction == 1
                        punchDirectionChecks.append(directionRecord)
                        // Keep the original four right-target PNGs while checking
                        // every running frame's transform for both target directions.
                        if direction == 1 {
                            var record = try autoreleasepool {
                                try captureRecord(
                                    gpu: gpu, node: punch, skin: "default", requestedState: .click,
                                    source: sourceEffects.appendingPathComponent("nyang_punch_\(index).png"),
                                    metadataDirectory: sourceEffects, expectedSourcePixels: sourcePixels,
                                    destination: output.appendingPathComponent("punch-\(index).png"))
                            }
                            record.merge(directionRecord) { _, value in value }
                            punches.append(record)
                        }
                    }
                    try require(textureIDs.count == 4, "expected four distinct running punch textures for direction \(direction)")
                }
            }
            try require(punches.count == 4 && punchDirectionChecks.count == 8,
                        "expected four punch PNGs and eight bidirectional frame checks")
        }
        let report: [String: Any] = [
            "scope": "Source-matched CatScene offscreen GPU rendering of built-app resources; excludes app input monitors and window placement",
            "sprites_root": root.path,
            "scene_points": [128, 128],
            "expected_source_pixels": [sourcePixels, sourcePixels],
            "capture_pixels": [capturePixels, capturePixels],
            "skin_state_count": states.count,
            "idle_unique_digest_count": idleHashes.count,
            "punch_count": punches.count,
            "punch_direction_check_count": punchDirectionChecks.count,
            "matching_source_resolution_state_count": states.filter {
                ($0["texture_pixels"] as? [Int]) == [sourcePixels, sourcePixels]
            }.count,
            "display_128pt_state_count": states.filter {
                ($0["display_points"] as? [Double]) == [128, 128]
            }.count,
            "states": states,
            "punches": punches,
            "punch_direction_checks": punchDirectionChecks,
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("report.json"), options: .atomic)
        print("PASS: \(states.count) deterministic skin/state captures, \(punches.count) punch frames, \(punchDirectionChecks.count) punch direction checks, 5 distinct idle images; source=\(sourcePixels)px; capture=\(capturePixels)px; resources=\(root.path); report=\(output.appendingPathComponent("report.json").path)")
    }

    private static func declaredPunchFacing(in directory: URL) throws -> String? {
        let url = directory.appendingPathComponent("render-info.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let metadata = try unwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  "punch render metadata must be a JSON object")
        guard let value = metadata["punchFacing"], !(value is NSNull) else { return nil }
        guard let facing = value as? String, ["left", "right"].contains(facing) else {
            throw Failure(description: "punchFacing must be left or right")
        }
        return facing
    }

    @MainActor
    private static func punchDirectionRecord(node: SKSpriteNode, targetDirection: Int,
                                             sourceFacing: String?) throws -> [String: Any] {
        try require(targetDirection == -1 || targetDirection == 1, "punch direction checks require a left or right target")
        let facing = sourceFacing ?? "left"
        let targetFacing = targetDirection == 1 ? "right" : "left"
        let expectedXScale: CGFloat = facing == targetFacing ? 1 : -1
        let displayedFacing = node.xScale > 0 ? facing : (facing == "left" ? "right" : "left")
        try require(node.xScale == expectedXScale && displayedFacing == targetFacing,
                    "\(facing)-facing punch aimed \(targetFacing) has xScale \(node.xScale); expected \(expectedXScale)")
        var record: [String: Any] = [
            "target_direction": targetDirection,
            "target_facing": targetFacing,
            "x_scale": Double(node.xScale),
            "expected_x_scale": Double(expectedXScale),
            "source_facing": facing,
            "displayed_facing": displayedFacing,
        ]
        if let sourceFacing {
            record["punch_facing_metadata"] = sourceFacing
        } else {
            record["punch_facing_metadata"] = NSNull()
        }
        return record
    }

    @MainActor
    private static func captureRecord(gpu: GPUSceneRenderer, node: SKSpriteNode, skin: String,
                                      requestedState: CatState, source: URL, metadataDirectory: URL,
                                      expectedSourcePixels: Int, destination: URL) throws -> [String: Any] {
        let texture = try unwrap(node.texture, "\(skin)/\(requestedState) has no displayed texture")
        let sourceData = try Data(contentsOf: source)
        let bitmap = try unwrap(NSBitmapImageRep(data: sourceData), "could not decode source \(source.path)")
        let backing = texture.cgImage()
        try require(backing.width == bitmap.pixelsWide && backing.height == bitmap.pixelsHigh,
                    "\(skin)/\(requestedState) texture no longer matches source pixel dimensions")
        try require(backing.width == expectedSourcePixels && backing.height == expectedSourcePixels,
                    "\(skin)/\(requestedState) expected \(expectedSourcePixels)px source and backing, found \(backing.width)×\(backing.height)")
        let metadataURL = metadataDirectory.appendingPathComponent("render-info.json")
        if let data = try? Data(contentsOf: metadataURL),
           let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let canvasHeight = metadata["canvasHeight"] as? NSNumber {
                try require(backing.height == canvasHeight.intValue, "\(skin)/\(requestedState) backing height disagrees with render metadata")
            }
            if let displayHeight = metadata["displayHeight"] as? NSNumber {
                try require(abs(node.size.height - displayHeight.doubleValue) < 0.001
                            && abs(texture.size().height - displayHeight.doubleValue) < 0.001,
                            "\(skin)/\(requestedState) is not using its declared point height")
                let sourceAspect = Double(backing.width) / Double(backing.height)
                try require(abs(node.size.width / node.size.height - sourceAspect) < 0.001,
                            "\(skin)/\(requestedState) changed the source aspect ratio")
            }
            if let filtering = metadata["filtering"] as? String {
                let actual = texture.filteringMode == .linear ? "linear" : "nearest"
                try require(actual == filtering, "\(skin)/\(requestedState) filtering disagrees with render metadata")
            }
        }
        let frame = try gpu.capture()
        var nonzeroAlpha = 0
        var transparentBorder = 0
        var minX = gpu.side, minY = gpu.side, maxX = -1, maxY = -1
        for y in 0..<gpu.side {
            for x in 0..<gpu.side {
                let alpha = frame.rgba[(y * gpu.side + x) * 4 + 3]
                if alpha > 0 {
                    nonzeroAlpha += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                } else if x == 0 || y == 0 || x == gpu.side - 1 || y == gpu.side - 1 {
                    transparentBorder += 1
                }
            }
        }
        let cornerAlpha = [0, gpu.side - 1, (gpu.side - 1) * gpu.side, gpu.side * gpu.side - 1]
            .map { Int(frame.rgba[$0 * 4 + 3]) }
        let perimeter = gpu.side * 4 - 4
        try frame.png.write(to: destination, options: .atomic)
        try require(nonzeroAlpha > 0 && cornerAlpha.allSatisfy { $0 == 0 } && transparentBorder == perimeter,
                    "\(skin)/\(requestedState) capture is empty or contacts the viewport border: \(destination.lastPathComponent)")
        return [
            "skin": skin,
            "requested_state": requestedState.rawValue,
            "displayed_state": gpu.scene.displayedState.rawValue,
            "source": source.path,
            "source_sha256": sha256(sourceData),
            "source_pixels": [bitmap.pixelsWide, bitmap.pixelsHigh],
            "texture_pixels": [backing.width, backing.height],
            "texture_points": [Double(texture.size().width), Double(texture.size().height)],
            "display_points": [Double(node.size.width), Double(node.size.height)],
            "filtering": texture.filteringMode == .linear ? "linear" : "nearest",
            "position_points": [Double(node.position.x), Double(node.position.y)],
            "png": destination.path,
            "png_sha256": sha256(frame.png),
            "capture_pixels": [gpu.side, gpu.side],
            "nonzero_alpha_pixels": nonzeroAlpha,
            "transparent_border_pixels": transparentBorder,
            "viewport_border_pixels": perimeter,
            "corner_alpha": cornerAlpha,
            "alpha_bounds_pixels": [minX, minY, maxX + 1, maxY + 1],
        ]
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func pixelArgument(_ option: String, in arguments: [String]) throws -> Int? {
        guard let index = arguments.firstIndex(of: option) else { return nil }
        guard arguments.indices.contains(index + 1), let value = Int(arguments[index + 1]),
              (1...8192).contains(value) else {
            throw Failure(description: "\(option) requires an integer between 1 and 8192")
        }
        return value
    }

    private static func declaredSourcePixels(in root: URL) throws -> Int {
        let url = root.appendingPathComponent("render-info.json")
        guard let data = try? Data(contentsOf: url),
              let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let height = metadata["canvasHeight"] as? NSNumber,
              (1...8192).contains(height.intValue), height.doubleValue == Double(height.intValue) else {
            throw Failure(description: "--sprite-output requires --expected-source-pixels or a canvasHeight in root render-info.json")
        }
        return height.intValue
    }

    @MainActor
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let rootIndex = arguments.firstIndex(of: "--sprites-root"),
              arguments.indices.contains(rootIndex + 1) else {
            throw Failure(description: "--sprites-root is required")
        }
        let spritesRoot = URL(fileURLWithPath: arguments[rootIndex + 1], isDirectory: true)
        let expectedSourcePixels = try pixelArgument("--expected-source-pixels", in: arguments)
        let capturePixels = try pixelArgument("--capture-pixels", in: arguments) ?? 256
        if !arguments.contains("--benchmark-only") {
            try verifyCacheBehavior()
            print("PASS: lazy loading, drag/state texture reuse, nearest filtering, skin refresh, missing frames, punch fallback refresh")
            try verifyRenderGeometry()
            print("PASS: opt-in grounding, visible bounds, drag pinning, action resets, metadata refresh and legacy fallback")
            try verifyPunchRenderInfo()
            print("PASS: bundled punch geometry and bidirectional facing, metadata caching/refresh and legacy/partial-asset fallback")
            if arguments.contains("--verify-actions") {
                try verifyAnimatedGrounding()
                print("PASS: offscreen SpriteKit walk, jump, landing, punch completion and interrupted-action grounding")
                for sourceSize in [256, 1024] {
                    try autoreleasepool {
                        try verifyHighResolutionRendering(sourceSize: sourceSize)
                        try verifyAnimatedGrounding(sourceSize: sourceSize, displayHeight: 128)
                    }
                    print("PASS: retained \(sourceSize)px detail at 128pt, linear filtering, cached drag/falling and high-resolution action/skin transitions")
                }
            }
        }
        if let outputIndex = arguments.firstIndex(of: "--sprite-output") {
            guard arguments.indices.contains(outputIndex + 1) else { throw Failure(description: "--sprite-output requires a directory") }
            try captureBuiltSprites(spritesRoot: spritesRoot,
                                    output: URL(fileURLWithPath: arguments[outputIndex + 1], isDirectory: true),
                                    expectedSourcePixels: expectedSourcePixels, capturePixels: capturePixels)
        }
        if let outputIndex = arguments.firstIndex(of: "--frame-cycle-output") {
            guard arguments.indices.contains(outputIndex + 1),
                  let statesIndex = arguments.firstIndex(of: "--frame-cycle-states"),
                  arguments.indices.contains(statesIndex + 1) else {
                throw Failure(description: "--frame-cycle-output requires a directory and --frame-cycle-states requires a comma-separated state list")
            }
            let names = arguments[statesIndex + 1].split(separator: ",").map(String.init)
            let states = names.compactMap(CatState.init(rawValue:))
            try require(!states.isEmpty && states.count == names.count && Set(states).count == states.count,
                        "frame-cycle states must be valid and unique")
            try captureFrameCycles(spritesRoot: spritesRoot,
                                   output: URL(fileURLWithPath: arguments[outputIndex + 1], isDirectory: true),
                                   states: states, expectedSourcePixels: expectedSourcePixels, capturePixels: capturePixels)
        }
        if !arguments.contains("--verify-only") {
            try benchmark(spritesRoot: spritesRoot)
        }
    }

    @MainActor
    private static func verifyAnimatedGrounding(sourceSize: Int = 128, displayHeight: Int? = nil) throws {
        // This optional check needs local Metal access, but creates no window.
        _ = NSApplication.shared
        let device = try unwrap(MTLCreateSystemDefaultDevice(), "--verify-actions requires local Metal access")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-action-fixtures-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let skin = try makePaddedSkin(directory: root, size: sourceSize)
        let source = root.appendingPathComponent("body.png")
        try writeRenderInfo(at: root.appendingPathComponent("render-info.json"), canvasHeight: sourceSize,
                            bottomInset: sourceSize * 12 / 128, displayHeight: displayHeight,
                            filtering: displayHeight == nil ? nil : "linear")
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let sprite = try spriteNode(in: scene, zPosition: 0)
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        var time = ProcessInfo.processInfo.systemUptime
        renderer.update(atTime: time)
        func advance(_ frames: Int) {
            for _ in 0..<frames {
                time += 1.0 / 60
                renderer.update(atTime: time)
            }
        }

        scene.playWalk(direction: -1)
        for _ in 0..<120 {
            advance(1)
            try require((53.99...56.01).contains(sprite.position.y), "walk bob must stay above its grounded baseline")
        }
        scene.play(state: .idle)
        advance(2)
        try require(sprite.position.y == 54, "stopping walk must restore the grounded center")

        // CatWindow lands without leaving .walk. Exercise both halves of the
        // bob cycle; checking landing only after .idle misses competing moves.
        for phase in [1, 3, 6, 8, 10, 13] {
            scene.play(state: .idle)
            scene.playWalk(direction: -1)
            advance(phase)
            scene.landingSquash()
            var landingFrames: Set<ObjectIdentifier> = []
            for _ in 0..<10 {
                advance(1)
                if let texture = sprite.texture { landingFrames.insert(ObjectIdentifier(texture)) }
                let footY = try opaqueBounds(of: sprite, source: source).minY
                if sprite.anchorPoint.y == 12.0 / 128 {
                    try require(abs(footY - 2) < 0.001,
                                "walk bob moved the landing foot line at phase \(phase): \(footY)")
                } else {
                    try require((1.99...4.01).contains(footY), "walk resumed outside its safe foot range")
                }
            }
            try require(landingFrames.count == 2, "walking frame animation should continue throughout landing")
            var minimumFootY: CGFloat = .greatestFiniteMagnitude
            var maximumFootY: CGFloat = -.greatestFiniteMagnitude
            for _ in 0..<60 {
                advance(1)
                let footY = try opaqueBounds(of: sprite, source: source).minY
                minimumFootY = min(minimumFootY, footY)
                maximumFootY = max(maximumFootY, footY)
                try require((1.99...4.01).contains(footY),
                            "walk retained a landing offset at phase \(phase): \(footY)")
            }
            try require(minimumFootY < 2.5 && maximumFootY > 3.5, "walk bob did not resume above the ground after landing")
            try require(sprite.size.height == 128, "walking landing changed the natural frame height to \(sprite.size.height)")
            try require(sprite.xScale == -1, "landing recovery lost the walking direction")

            scene.landingSquash()
            advance(3)
            scene.landingSquash()
            for _ in 0..<36 {
                advance(1)
                let footY = try opaqueBounds(of: sprite, source: source).minY
                if sprite.anchorPoint.y == 12.0 / 128 {
                    try require(abs(footY - 2) < 0.001, "repeated walking landings shifted the squash anchor")
                } else {
                    try require((1.99...4.01).contains(footY), "repeated walking landings accumulated bob offset")
                }
            }
        }

        for nextState in [CatState.idle, .typing, .dragging] {
            scene.playWalk(direction: 1)
            advance(6)
            scene.landingSquash()
            advance(3)
            if nextState == .dragging {
                scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
            } else {
                scene.play(state: nextState)
            }
            advance(40)
            let expectedY: CGFloat = nextState == .dragging ? 124 : 54
            let expectedAnchorY: CGFloat = nextState == .dragging ? 1 : 0.5
            try require(sprite.position.y == expectedY && sprite.anchorPoint.y == expectedAnchorY
                        && sprite.size.height == 128 && !sprite.hasActions(),
                        "switching to \(nextState) during recovery left position=\(sprite.position.y), anchor=\(sprite.anchorPoint.y), height=\(sprite.size.height), actions=\(sprite.hasActions())")
        }
        scene.play(state: .idle)

        scene.playOnce(state: .jump)
        advance(10)
        try require(sprite.position.y > 54, "jump action did not advance offscreen")
        advance(30)
        try require(sprite.position.y == 54 && scene.displayedState == .idle,
                    "completed jump must land on the grounded center")

        for _ in 0..<2 {
            scene.landingSquash()
            advance(3)
            try require(sprite.yScale < 1, "landing squash did not advance offscreen")
            try require(abs(try opaqueBounds(of: sprite, source: source).minY - 2) < 0.001,
                        "landing squash moved its opaque foot line")
            advance(20)
            try require(sprite.position.y == 54 && sprite.anchorPoint.y == 0.5 && sprite.yScale == 1,
                        "completed landing must restore the grounded center")
        }

        scene.landingSquash()
        advance(3)
        scene.landingSquash()
        for _ in 0..<24 {
            advance(1)
            try require(abs(try opaqueBounds(of: sprite, source: source).minY - 2) < 0.001,
                        "an older landing reset interrupted the current squash anchor")
        }
        try require(sprite.position.y == 54, "repeated landing should not accumulate a vertical offset")

        scene.playPunch(direction: 1)
        advance(Int(ceil(ScreenPetPunchSequence.default.totalDuration * 60)) + 10)
        let punch = try spriteNode(in: scene, zPosition: 2)
        try require(sprite.position.y == 54 && !sprite.isHidden && punch.isHidden && scene.displayedState == .idle,
                    "completed punch must restore the grounded base sprite")

        for refreshSkin in [false, true] {
            scene.playOnce(state: .jump)
            advance(8)
            if refreshSkin {
                scene.apply(skin: skin)
            } else {
                scene.play(state: .idle)
            }
            advance(40)
            try require(sprite.position.y == 54 && !sprite.hasActions(),
                        "an interrupted action left a transform or action behind")
        }

        guard sourceSize == 128 else { return }
        try FileManager.default.removeItem(at: root.appendingPathComponent("render-info.json"))
        scene.apply(skin: skin)
        scene.playWalk(direction: 1)
        advance(6)
        scene.landingSquash()
        advance(3)
        scene.landingSquash()
        for _ in 0..<60 {
            advance(1)
            if sprite.anchorPoint.y == 0 {
                try require(sprite.position.y == 0, "legacy repeated landing subtracted the canvas half-height twice")
            } else {
                try require((61.99...64.01).contains(sprite.position.y), "legacy walk baseline changed after landing")
            }
        }
    }

    @MainActor
    private static func verifyPunchRenderInfo() throws {
        let resources = try unwrap(Bundle.main.resourceURL, "expected the harness resource directory")
        try require(resources.lastPathComponent.hasPrefix("openneko-cat-scene-cache."),
                    "run with the shell wrapper so bundled punch fixtures stay in its temporary directory")
        let effects = resources.appendingPathComponent("sprites/effects", isDirectory: true)
        try require(!FileManager.default.fileExists(atPath: effects.path), "bundled punch fixture directory already exists")
        try FileManager.default.createDirectory(at: effects, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: effects) }
        for index in 0..<4 {
            try writeFrame(at: effects.appendingPathComponent("nyang_punch_\(index).png"), width: 128, height: 128,
                           bottomInset: 12, topInset: 12)
        }
        let fixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-punch-fixture-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let skin = try makeSkin(directory: fixture, width: 24)
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let sprite = try spriteNode(in: scene, zPosition: 0)
        let punch = try spriteNode(in: scene, zPosition: 2)
        @MainActor
        func verifyDirections(rightXScale: CGFloat, leftXScale: CGFloat, context: String) throws {
            for (direction, expected) in [(1, rightXScale), (-1, leftXScale)] {
                scene.play(state: .idle)
                scene.playPunch(direction: direction)
                try require(!punch.isHidden && punch.xScale == expected,
                            "\(context): target \(direction) expected xScale \(expected), found \(punch.xScale)")
            }
            scene.play(state: .idle)
        }

        scene.playPunch(direction: 1)
        try require(abs(punch.size.height - 148.48) < 0.001 && punch.position.y == 52,
                    "dedicated effects without metadata must keep their legacy presentation")
        let originalTexture = try unwrap(punch.texture, "expected a dedicated punch texture")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "missing effect metadata must retain legacy facing")
        let metadata = effects.appendingPathComponent("render-info.json")
        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 12)
        scene.playPunch(direction: 1)
        try require(punch.texture === originalTexture && punch.position.y == 52,
                    "punch metadata should stay cached with its textures until skin reload")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "adding metadata must not change cached facing")

        scene.apply(skin: skin)
        scene.playPunch(direction: 1)
        try require(punch.size == CGSize(width: 128, height: 128) && punch.position.y == 54,
                    "opt-in dedicated effects must use their natural canvas and grounded center")
        try require(try opaqueBounds(of: punch, source: effects.appendingPathComponent("nyang_punch_0.png")).minY == 2,
                    "new dedicated punch feet should meet y2 without clipping")
        try require(punch.texture?.filteringMode == .nearest, "dedicated punch metadata changed pixel filtering")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "metadata without punchFacing must retain legacy facing")
        try require(sprite.position.y == 64, "global punch metadata must not alter the selected skin geometry")

        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 12, punchFacing: "left")
        scene.apply(skin: skin)
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "explicit left-facing effects must retain legacy facing")
        let leftFacingTexture = try unwrap(punch.texture, "expected the cached left-facing effect")

        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 0, punchFacing: "right")
        scene.playPunch(direction: 1)
        try require(punch.texture === leftFacingTexture && punch.position.y == 54,
                    "punch geometry and facing metadata must stay cached with the textures")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "new right-facing metadata must wait for skin refresh")
        scene.apply(skin: skin)
        scene.playPunch(direction: 1)
        try require(punch.position.y == 66, "reapplying a skin must refresh global punch metadata")
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "right-facing effects must point toward either target")

        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 12)
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "removing punchFacing must not bypass its texture cache")
        scene.apply(skin: skin)
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "skin refresh must clear a removed punchFacing hint")

        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 12, punchFacing: "right")
        scene.apply(skin: skin)
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "restored right-facing metadata must reload")
        try Data("invalid metadata".utf8).write(to: metadata)
        scene.apply(skin: skin)
        scene.playPunch(direction: 1)
        try require(abs(punch.size.height - 148.48) < 0.001 && punch.position.y == 52,
                    "invalid dedicated effect metadata must restore legacy geometry")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "invalid metadata must clear right-facing presentation")

        try writeRenderInfo(at: metadata, canvasHeight: 128, bottomInset: 12, punchFacing: "right")
        scene.apply(skin: skin)
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "complete right-facing effects must be restored")
        let dedicatedTexture = try unwrap(punch.texture, "expected the complete dedicated effect")
        try FileManager.default.removeItem(at: effects.appendingPathComponent("nyang_punch_3.png"))
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "removed effect frames must wait for cache refresh")
        try require(punch.texture === dedicatedTexture, "removing an effect frame changed the cached punch textures")
        scene.apply(skin: skin)
        scene.playPunch(direction: 1)
        try require(punch.texture?.size().width == 24 && punch.position.y == 52,
                    "partial global effects must use the skin fallback without global render metadata")
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "skin fallback must not inherit global right-facing metadata")
        let fallbackTexture = try unwrap(punch.texture, "expected the cached skin fallback")
        try writeFrame(at: effects.appendingPathComponent("nyang_punch_3.png"), width: 128, height: 128,
                       bottomInset: 12, topInset: 12)
        try verifyDirections(rightXScale: -1, leftXScale: 1, context: "restored effects must not bypass the cached skin fallback")
        try require(punch.texture === fallbackTexture, "restoring an effect frame changed the cached fallback")
        scene.apply(skin: skin)
        try verifyDirections(rightXScale: 1, leftXScale: -1, context: "skin refresh must restore dedicated right-facing effects")
        try require(punch.texture?.size().width == 128, "skin refresh did not replace the fallback with dedicated textures")
    }

    @MainActor
    private static func verifyRenderGeometry() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-render-fixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let skin = try makePaddedSkin(directory: root.appendingPathComponent("padded"), size: 128)
        let bodyURL = skin.directory.appendingPathComponent("body.png")
        let dragURL = skin.directory.appendingPathComponent("drag.png")
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let sprite = try spriteNode(in: scene, zPosition: 0)
        try require(sprite.position.y == 64, "skins without metadata must keep legacy centering")

        let metadataURL = skin.directory.appendingPathComponent("render-info.json")
        try writeRenderInfo(at: metadataURL, canvasHeight: 128, bottomInset: 12, dragTopInset: 18)
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        try require(sprite.anchorPoint.y == 1, "new metadata must not be read during drag updates")
        scene.play(state: .idle)
        try require(sprite.position.y == 64, "metadata should remain cached until skin reload")

        scene.apply(skin: skin)
        try require(sprite.position.y == 54, "12px bottom padding should place a 128px sprite at y54")
        try require(try opaqueBounds(of: sprite, source: bodyURL).minY == 2, "visible feet should meet the ground at y2")
        for state in [CatState.idle, .hover, .coding, .typing, .thinking, .lunch, .yawn, .nap, .success, .error] {
            scene.play(state: state)
            let bounds = try opaqueBounds(of: sprite, source: bodyURL)
            try require(bounds.minY == 2 && bounds.maxY <= 128,
                        "neutral \(state) content is clipped or floating")
            try require(sprite.texture?.filteringMode == .nearest, "metadata changed nearest filtering")
        }

        // A real transparent top inset pins the head rather than the canvas edge.
        // Updating the file must not change any of the 600 hot-path drag updates.
        try writeRenderInfo(at: metadataURL, canvasHeight: 128, bottomInset: 0, dragTopInset: 0)
        for _ in 0..<600 {
            scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
            try require(sprite.anchorPoint.y == 110.0 / 128, "drag pin metadata was reloaded per tick")
        }
        try require(try opaqueBounds(of: sprite, source: dragURL).maxY == 124, "drag head should stay on the existing pointer pin")
        scene.showFalling()
        try require(try opaqueBounds(of: sprite, source: dragURL).maxY == 124, "falling should keep the drag pin")
        scene.play(state: .idle)
        try require(sprite.position.y == 54, "leaving drag should restore the grounded center")

        for _ in 0..<3 {
            scene.playWalk(direction: -1)
            try require(sprite.position.y == 54 && sprite.xScale == -1 && sprite.hasActions(),
                        "walk should begin at its canonical grounded center")
            scene.play(state: .idle)
            scene.landingSquash()
            try require(sprite.anchorPoint.y == 12.0 / 128 && sprite.position.y == 2,
                        "landing should scale around the opaque foot line")
            try require(try opaqueBounds(of: sprite, source: bodyURL).minY == 2, "landing moved the feet off the ground")
            scene.playOnce(state: .jump, direction: 1)
            try require(sprite.position.y == 54 && sprite.anchorPoint.y == 0.5,
                        "jump should reset the landing transform without accumulating an offset")
            scene.play(state: .idle)
            try require(sprite.position.y == 54 && sprite.yScale == 1, "action cancellation should restore grounding")
        }

        scene.playPunch(direction: 1)
        let punch = try spriteNode(in: scene, zPosition: 2)
        try require(abs(try opaqueBounds(of: punch, source: bodyURL).minY - 2) < 0.001,
                    "a scaled skin click fallback should retain its visible foot line")
        scene.play(state: .idle)
        try require(!sprite.isHidden && punch.isHidden && sprite.position.y == 54,
                    "cancelling a punch should restore the grounded base sprite")
        scene.setCatFrameSize(CGSize(width: 160, height: 160))
        try require(sprite.position == CGPoint(x: 80, y: 54), "frame resize should not shift the foot line")
        scene.setCatFrameSize(CGSize(width: 128, height: 128))

        scene.apply(skin: skin)
        try require(sprite.position.y == 66, "same-skin refresh should reload changed bottom padding")
        try writeRenderInfo(at: metadataURL, canvasHeight: 128, bottomInset: 12)
        scene.apply(skin: skin)
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        try require(sprite.anchorPoint.y == 1, "omitting dragTopInset should preserve the legacy drag pin")
        scene.play(state: .idle)
        try require(sprite.position.y == 54, "optional drag padding must not disable grounding")

        // A parent manifest and render file must not opt a custom skin in.
        try writeRenderInfo(at: root.appendingPathComponent("render-info.json"), canvasHeight: 128, bottomInset: 12)
        let custom = try makePaddedSkin(directory: root.appendingPathComponent("custom"), size: 128)
        scene.apply(skin: custom)
        try require(sprite.position.y == 64, "custom skins must not inherit parent render metadata")
        scene.showFalling()
        try require(sprite.anchorPoint.y == 1 && sprite.position.y == 124, "legacy falling pin changed")

        // Different texture dimensions catch resets that still use the old texture size.
        let small = try makePaddedSkin(directory: root.appendingPathComponent("small"), size: 64)
        try writeRenderInfo(at: small.directory.appendingPathComponent("render-info.json"), canvasHeight: 64, bottomInset: 6)
        scene.apply(skin: small)
        try require(sprite.position.y == 28 && sprite.size.height == 64,
                    "skin switching should calculate grounding from the new frame size")
        scene.apply(skin: skin)
        try require(sprite.position.y == 54, "switching back should restore the larger skin geometry")

        for data in [
            Data("not JSON".utf8),
            Data(#"{"version":2,"canvasHeight":128,"bottomInset":12}"#.utf8),
            Data(#"{"version":1,"canvasHeight":0,"bottomInset":12}"#.utf8),
            Data(#"{"version":1,"canvasHeight":128,"bottomInset":-1}"#.utf8),
            Data(#"{"version":1,"canvasHeight":128,"bottomInset":12,"dragTopInset":116}"#.utf8),
            Data(#"{"version":1,"canvasHeight":128,"bottomInset":12,"displayHeight":0}"#.utf8),
            Data(#"{"version":1,"canvasHeight":128,"bottomInset":12,"filtering":"unknown"}"#.utf8),
            Data(#"{"version":1,"bottomInset":12}"#.utf8),
        ] {
            try data.write(to: metadataURL)
            scene.apply(skin: skin)
            try require(sprite.position.y == 64, "invalid metadata should restore legacy centering")
        }
        try writeRenderInfo(at: metadataURL, canvasHeight: 128, bottomInset: 12)
        scene.apply(skin: skin)
        try FileManager.default.removeItem(at: metadataURL)
        scene.apply(skin: skin)
        try require(sprite.position.y == 64, "removing metadata must clear the previous skin geometry")
    }

    @MainActor
    private static func verifyCacheBehavior() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-cache-fixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skin = try makeSkin(directory: root.appendingPathComponent("first"), width: 24)
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let sprite = try spriteNode(in: scene, zPosition: 0)
        let idleTexture = try unwrap(sprite.texture, "idle should be displayed")

        // A frame changed before its first use must be loaded with the new size.
        try writeFrame(at: skin.directory.appendingPathComponent("dragging.png"), width: 27)
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        let firstDragTexture = try unwrap(sprite.texture, "dragging should be displayed")
        try require(firstDragTexture.size().width == 27, "drag frames should load lazily")
        try require(firstDragTexture.filteringMode == .nearest, "pixel art filtering changed")
        for _ in 0..<600 {
            scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
            try require(sprite.texture === firstDragTexture, "drag updates recreated the texture")
        }
        scene.play(state: .idle)
        try require(sprite.texture === idleTexture, "state transitions should reuse textures")
        scene.showFalling()
        try require(sprite.texture === firstDragTexture, "falling should reuse the drag texture")

        try writeFrame(at: skin.directory.appendingPathComponent("dragging.png"), width: 31)
        scene.apply(skin: skin)
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        try require(sprite.texture !== firstDragTexture, "reapplying a skin kept stale textures")
        try require(sprite.texture?.size().width == 31, "reapplying a skin did not reload replaced files")

        scene.play(state: .idle)
        scene.play(state: .success) // Listed in the manifest but not yet on disk.
        try require(scene.displayedState == .idle, "missing frames should preserve the current state")
        try writeFrame(at: skin.directory.appendingPathComponent("missing.png"), width: 33)
        scene.play(state: .success)
        try require(scene.displayedState == .idle, "failed loads should stay cached until skin reload")
        scene.apply(skin: skin)
        scene.play(state: .success)
        try require(scene.displayedState == .success, "skin reload should retry previously missing frames")

        // This command-line harness has no bundled punch effect assets. It must
        // therefore reuse the current skin's click texture and invalidate it on reload.
        let bundledEffects = Bundle.main.resourceURL?
            .appendingPathComponent("sprites/effects/nyang_punch_0.png")
        try require(bundledEffects.map { !FileManager.default.fileExists(atPath: $0.path) } ?? true,
                    "run with the shell wrapper so punch fallback fixtures remain isolated")
        scene.play(state: .click)
        let clickTexture = try unwrap(sprite.texture, "click texture should be available")
        scene.play(state: .idle)
        scene.playPunch(direction: 1)
        let punch = try spriteNode(in: scene, zPosition: 2)
        try require(punch.texture === clickTexture, "punch fallback should share the click texture")
        scene.play(state: .idle)
        scene.playPunch(direction: -1)
        try require(punch.texture === clickTexture, "repeated punch should reuse its textures")

        // Use the same skin ID in another directory to catch identity-only invalidation.
        let replacement = try makeSkin(directory: root.appendingPathComponent("replacement"), width: 41)
        scene.apply(skin: replacement)
        scene.playPunch(direction: 1)
        try require(punch.texture !== clickTexture, "switching skins kept the old punch fallback")
        try require(punch.texture?.size().width == 41, "punch fallback came from the wrong skin")

        let missingClick = replacement.directory.appendingPathComponent("click.png")
        try FileManager.default.removeItem(at: missingClick)
        scene.apply(skin: replacement)
        scene.playPunch(direction: 1)
        try require(punch.isHidden, "a missing punch fallback should not start an animation")
        try writeFrame(at: missingClick, width: 43)
        scene.playPunch(direction: 1)
        try require(punch.isHidden, "an empty punch result should stay cached until skin reload")
        scene.apply(skin: replacement)
        scene.playPunch(direction: 1)
        try require(!punch.isHidden && punch.texture?.size().width == 43,
                    "skin reload should retry the missing punch fallback")
    }

    @MainActor
    private static func benchmark(spritesRoot: URL) throws {
        let manifest = try SpriteManifest(data: Data(contentsOf: spritesRoot.appendingPathComponent("manifest.json")))
        let skin = Skin(id: "benchmark", directory: spritesRoot, manifest: manifest)
        try require(skin.frameURLs(for: "dragging").count == 4, "benchmark requires four drag frames")
        let scene = CatScene(size: CGSize(width: 128, height: 128))
        scene.apply(skin: skin)
        let coldStart = ProcessInfo.processInfo.systemUptime
        scene.showDragging(horizontalVelocity: 0, horizontalAcceleration: 0, time: 0)
        let coldMilliseconds = (ProcessInfo.processInfo.systemUptime - coldStart) * 1_000
        let sprite = try spriteNode(in: scene, zPosition: 0)
        try require(sprite.texture != nil, "benchmark drag textures failed to load")

        var samples: [Double] = []
        for _ in 0..<7 {
            let start = ProcessInfo.processInfo.systemUptime
            autoreleasepool {
                for index in 0..<600 {
                    scene.showDragging(
                        horizontalVelocity: CGFloat(index % 17 - 8),
                        horizontalAcceleration: CGFloat(index % 11 - 5),
                        time: Double(index) / 60
                    )
                }
            }
            samples.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
        }
        let median = samples.sorted()[samples.count / 2]
        let result: [String: Any] = [
            "scope": "CatScene.showDragging CPU-side update wall time; excludes GPU rendering and event delivery",
            "optimization": "-O",
            "drag_frame_count": 4,
            "updates_per_sample": 600,
            "cold_first_drag_ms": coldMilliseconds,
            "samples_ms": samples,
            "median_ms": median,
            "median_us_per_update": median * 1_000 / 600,
        ]
        let output = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: output, as: UTF8.self))
    }

    @MainActor
    private static func spriteNode(in scene: CatScene, zPosition: CGFloat) throws -> SKSpriteNode {
        try unwrap(scene.children.flatMap(\.children)
            .compactMap { $0 as? SKSpriteNode }
            .first { $0.zPosition == zPosition }, "expected sprite node at zPosition \(zPosition)")
    }

    private static func makeSkin(directory: URL, width: Int) throws -> Skin {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["idle.png", "dragging.png", "click.png"] {
            try writeFrame(at: directory.appendingPathComponent(name), width: width)
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "idle": ["idle.png"], "dragging": ["dragging.png"],
            "click": ["click.png"], "success": ["missing.png"], "error": [],
        ])
        return Skin(id: "fixture", directory: directory, manifest: try SpriteManifest(data: data))
    }

    private static func makePaddedSkin(directory: URL, size: Int) throws -> Skin {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeFrame(at: directory.appendingPathComponent("body.png"), width: size, height: size,
                       bottomInset: size * 12 / 128, topInset: size * 12 / 128)
        try writeFrame(at: directory.appendingPathComponent("drag.png"), width: size, height: size,
                       bottomInset: size * 12 / 128, topInset: size * 18 / 128)
        var frames = Dictionary(uniqueKeysWithValues: CatState.allCases.map { ($0.rawValue, ["body.png"]) })
        frames["dragging"] = ["drag.png"]
        frames["walk"] = ["body.png", "body.png"]
        let manifest = try SpriteManifest(data: JSONSerialization.data(withJSONObject: frames))
        return Skin(id: "fixture", directory: directory, manifest: manifest)
    }

    private static func writeRenderInfo(at url: URL, canvasHeight: Int, bottomInset: Int, dragTopInset: Int? = nil,
                                        displayHeight: Int? = nil, filtering: String? = nil, punchFacing: String? = nil) throws {
        var object: [String: Any] = ["version": 1, "canvasHeight": canvasHeight, "bottomInset": bottomInset]
        object["dragTopInset"] = dragTopInset
        object["displayHeight"] = displayHeight
        object["filtering"] = filtering
        object["punchFacing"] = punchFacing
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }

    @MainActor
    private static func opaqueBounds(of sprite: SKSpriteNode, source: URL) throws -> CGRect {
        // Decode the source PNG so this geometry check also works without a GPU.
        // SKTexture.cgImage() requires a Metal device on recent macOS versions.
        let data = try Data(contentsOf: source)
        let alpha: AlphaBounds
        if let cached = alphaBoundsByURL[source], cached.sourceData == data {
            alpha = cached
        } else {
            let image = try unwrap(NSBitmapImageRep(data: data), "could not decode the fixture source")
            var minX = image.pixelsWide, minY = image.pixelsHigh, maxX = -1, maxY = -1
            for y in 0..<image.pixelsHigh {
                for x in 0..<image.pixelsWide where (image.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            try require(maxX >= minX && maxY >= minY, "fixture texture has no opaque pixels")
            alpha = AlphaBounds(sourceData: data, pixelSize: CGSize(width: image.pixelsWide, height: image.pixelsHigh),
                                bounds: CGRect(x: minX, y: image.pixelsHigh - maxY - 1,
                                               width: maxX - minX + 1, height: maxY - minY + 1))
            alphaBoundsByURL[source] = alpha
        }
        // size is already expressed in the parent coordinate space; remove
        // node scaling before convert applies that transform to local points.
        let localWidth = sprite.size.width / abs(sprite.xScale)
        let localHeight = sprite.size.height / abs(sprite.yScale)
        let scaleX = localWidth / alpha.pixelSize.width
        let scaleY = localHeight / alpha.pixelSize.height
        let corners = [
            CGPoint(x: alpha.bounds.minX * scaleX - localWidth * sprite.anchorPoint.x,
                    y: alpha.bounds.minY * scaleY - localHeight * sprite.anchorPoint.y),
            CGPoint(x: alpha.bounds.maxX * scaleX - localWidth * sprite.anchorPoint.x,
                    y: alpha.bounds.maxY * scaleY - localHeight * sprite.anchorPoint.y),
        ].map { sprite.convert($0, to: sprite.parent!) }
        return CGRect(x: min(corners[0].x, corners[1].x), y: min(corners[0].y, corners[1].y),
                      width: abs(corners[1].x - corners[0].x), height: abs(corners[1].y - corners[0].y))
    }

    private static func writeFrame(at url: URL, width: Int, height: Int = 16, bottomInset: Int = 0, topInset: Int = 0) throws {
        let image = try unwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), "could not allocate fixture image")
        let color = NSColor(deviceRed: 1, green: 0.5, blue: 0, alpha: 1)
        let clearColor = NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0)
        for y in 0..<height {
            for x in 0..<width {
                let isOpaque = y >= topInset && y < height - bottomInset
                image.setColor(isOpaque ? color : clearColor, atX: x, y: y)
            }
        }
        let data = try unwrap(image.representation(using: .png, properties: [:]), "could not encode fixture image")
        try data.write(to: url)
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw Failure(description: message) }
        return value
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw Failure(description: message) }
    }
}
