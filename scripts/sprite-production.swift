#!/usr/bin/env swift
// Mechanical import/QA only. Creative artwork and recolors must come from image_gen.
import AppKit
import CryptoKit
import Foundation

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

enum ImportMode: String {
    case highres
    case highres1024
    case pixel64
    var isHighResolution: Bool { self != .pixel64 }
    var canvasSize: Int { self == .highres1024 ? 1024 : (self == .highres ? 256 : 128) }
    var padding: Int { self == .highres1024 ? 96 : (self == .highres ? 24 : 12) }
    var displayHeight: Int { 128 }
    var maximumArtSpan: Double { self == .highres1024 ? 832 : (self == .highres ? 208 : 52) }
    var jumpArtSpan: Double { self == .highres1024 ? 800 : (self == .highres ? 200 : 50) }
    var baseline: Double { self == .highres1024 ? 928 : (self == .highres ? 232 : 58) }
    var resampling: String {
        isHighResolution ? "premultiplied-alpha-bilinear" : "nearest64-logical-then2x"
    }
}

func importMode(_ values: [String: String]) throws -> ImportMode {
    guard let mode = ImportMode(rawValue: values["--mode"] ?? "highres") else {
        throw Failure("--mode must be highres, highres1024, or pixel64")
    }
    return mode
}

struct Raster {
    let width: Int
    let height: Int
    var bytes: [UInt8]
    init(width: Int, height: Int, bytes: [UInt8]? = nil) {
        self.width = width
        self.height = height
        self.bytes = bytes ?? Array(repeating: 0, count: width * height * 4)
    }
    func offset(_ x: Int, _ y: Int) -> Int { (y * width + x) * 4 }
    func crop(x: Int, y: Int, width: Int, height: Int) -> Raster {
        var result = Raster(width: width, height: height)
        for row in 0..<height {
            let start = offset(x, y + row)
            result.bytes.replaceSubrange(row * width * 4..<(row + 1) * width * 4,
                                         with: bytes[start..<start + width * 4])
        }
        return result
    }
    static func read(_ url: URL) throws -> Raster {
        try decode(Data(contentsOf: url), sourceDescription: url.path)
    }
    static func decode(_ data: Data, sourceDescription: String) throws -> Raster {
        guard let bitmap = NSBitmapImageRep(data: data),
              bitmap.bitsPerSample == 8, !bitmap.isPlanar,
              bitmap.samplesPerPixel >= 3 else {
            throw Failure("Expected a readable 8-bit RGB/RGBA image: \(sourceDescription)")
        }
        var result = Raster(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        var values = [Int](repeating: 0, count: bitmap.samplesPerPixel)
        for y in 0..<result.height {
            for x in 0..<result.width {
                bitmap.getPixel(&values, atX: x, y: y)
                let o = result.offset(x, y)
                result.bytes[o] = UInt8(clamping: values[0])
                result.bytes[o + 1] = UInt8(clamping: values[1])
                result.bytes[o + 2] = UInt8(clamping: values[2])
                result.bytes[o + 3] = bitmap.hasAlpha ? UInt8(clamping: values[3]) : 255
            }
        }
        return result
    }
    func bitmapRepresentation() throws -> NSBitmapImageRep {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width,
            pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied,
            bytesPerRow: width * 4, bitsPerPixel: 32), let destination = bitmap.bitmapData else {
            throw Failure("Cannot create output bitmap")
        }
        bytes.withUnsafeBufferPointer { source in destination.update(from: source.baseAddress!, count: bytes.count) }
        return bitmap
    }
    func write(_ url: URL) throws {
        let bitmap = try bitmapRepresentation()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure("Cannot encode PNG")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url, options: .atomic)
    }
    var transparentCount: Int { stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] == 0 }.count }
    var digest: String { SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined() }
}

struct Bounds: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    var right: Int { x + width }
    var bottom: Int { y + height }
    var centerX: Double { Double(x) + Double(width) / 2 }
    var centerY: Double { Double(y) + Double(height) / 2 }
}

func bounds(_ image: Raster) -> Bounds? {
    var left = image.width, top = image.height, right = -1, bottom = -1
    for y in 0..<image.height {
        for x in 0..<image.width where image.bytes[image.offset(x, y) + 3] > 0 {
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
        }
    }
    return right < left ? nil : Bounds(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
}

func edgeContacts(_ image: Raster, minimumAlpha: UInt8 = 1) -> [String: Int] {
    var result = ["top": 0, "bottom": 0, "left": 0, "right": 0]
    for x in 0..<image.width {
        if image.bytes[image.offset(x, 0) + 3] >= minimumAlpha { result["top", default: 0] += 1 }
        if image.bytes[image.offset(x, image.height - 1) + 3] >= minimumAlpha { result["bottom", default: 0] += 1 }
    }
    for y in 0..<image.height {
        if image.bytes[image.offset(0, y) + 3] >= minimumAlpha { result["left", default: 0] += 1 }
        if image.bytes[image.offset(image.width - 1, y) + 3] >= minimumAlpha { result["right", default: 0] += 1 }
    }
    return result
}

func permitsTraceOnlyEdgeContact(_ image: Raster, mode: ImportMode) -> Bool {
    mode == .highres1024 && edgeContacts(image, minimumAlpha: 16).values.allSatisfy { $0 == 0 }
}

// Four-connected flood from cell edges. Interior white fur is never globally keyed.
func clearNeutralEdge(_ image: Raster, floor: Int = 220, spread: Int = 18) -> (Raster, Int) {
    var output = image
    var visited = [Bool](repeating: false, count: image.width * image.height)
    var queue: [Int] = []
    func enqueue(_ index: Int) {
        if visited[index] { return }
        let o = index * 4
        let channels = [Int(image.bytes[o]), Int(image.bytes[o + 1]), Int(image.bytes[o + 2])]
        if image.bytes[o + 3] == 0 || (channels.min()! >= floor && channels.max()! - channels.min()! <= spread) {
            visited[index] = true
            queue.append(index)
        }
    }
    for x in 0..<image.width { enqueue(x); enqueue((image.height - 1) * image.width + x) }
    for y in 0..<image.height { enqueue(y * image.width); enqueue(y * image.width + image.width - 1) }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]; cursor += 1
        let x = index % image.width, y = index / image.width
        if x > 0 { enqueue(index - 1) }
        if x + 1 < image.width { enqueue(index + 1) }
        if y > 0 { enqueue(index - image.width) }
        if y + 1 < image.height { enqueue(index + image.width) }
    }
    var removed = 0
    for index in queue {
        let o = index * 4
        if output.bytes[o + 3] > 0 { removed += 1 }
        for channel in 0..<4 { output.bytes[o + channel] = 0 }
    }
    return (output, removed)
}

struct ChromaMagentaRecord: Codable {
    let keyColorRGB: [Int]
    let measuredKeyColorRGB: [Int]
    let keyTolerance: String
    let keyPixelsRemoved: Int
    let isolatedKeyOutliersRemoved: Int?
    let enclosedKeyPixelsRemoved: Int
    let boundaryBandPixels: Int
    let decontaminatedEdgePixels: Int
    let projectedGreenEdgePixels: Int?
    let projectedUpperRGBEdgePixels: Int?
    let lowCoverageSpillPixelsRemoved: Int
    let fringePolicy: String?
    let reservedFringePixelsRemoved: Int?
    let maximumReservedFringeDistance: Int?
    let interiorHueCandidatesPreserved: Int?
    let unresolvedCandidatePixels: Int
    let unresolvedReasons: [String: Int]
    let maximumReconstructionError: Double
    let nativeAlphaPassthrough: Bool
    let issues: [String]
    let sourceRGBAHash: String
    let isolatedRGBAHash: String
}

func isMagentaKey(_ red: Int, _ green: Int, _ blue: Int) -> Bool {
    red >= 224 && blue >= 224 && green <= 40 && abs(red - blue) <= 32
}

func isMagentaMixture(_ red: Int, _ green: Int, _ blue: Int) -> Bool {
    min(red, blue) - green >= 16 && abs(red - blue) <= 64
}

func isReservedPixelMagenta(_ red: Int, _ green: Int, _ blue: Int) -> Bool {
    let rgb = [red, green, blue]
    // A neutral bright source pixel can be real white fur. Preserve it even
    // when a tiny channel difference resembles low-saturation magenta.
    if rgb.min()! >= 220 && rgb.max()! - rgb.min()! <= 18 { return false }
    return isMagentaMixture(red, green, blue)
        || (min(red, blue) - green >= 32 && abs(red - blue) <= 128)
}

func isPixelMagentaKey(_ red: Int, _ green: Int, _ blue: Int) -> Bool {
    min(red, blue) >= 160 && min(red, blue) - green >= 96 && abs(red - blue) <= 96
}

// Explicit reserved-color extraction. Unlike the neutral-edge path, the key is
// removed everywhere, including holes enclosed by a tail/outline. A small matte
// boundary may be unmixed only when a nearby existing dark outline explains it.
// No foreground texture is created and no global white/pink desaturation occurs.
func clearChromaMagenta(_ source: Raster, trimReservedPixelFringe: Bool = false) -> (Raster, ChromaMagentaRecord) {
    var output = source
    let count = source.width * source.height
    let nativeAlpha = stride(from: 3, to: source.bytes.count, by: 4).contains { source.bytes[$0] < 255 }
    if nativeAlpha {
        zeroTransparentRGB(&output)
        return (output, ChromaMagentaRecord(keyColorRGB: [255, 0, 255], measuredKeyColorRGB: [],
            keyTolerance: "native nonopaque alpha takes precedence over the reserved color",
            keyPixelsRemoved: 0, isolatedKeyOutliersRemoved: 0, enclosedKeyPixelsRemoved: 0, boundaryBandPixels: 0,
            decontaminatedEdgePixels: 0, projectedGreenEdgePixels: 0, projectedUpperRGBEdgePixels: 0, lowCoverageSpillPixelsRemoved: 0,
            fringePolicy: trimReservedPixelFringe ? "reserved-color-hard-edge-16px" : "strict-unmix", reservedFringePixelsRemoved: 0, maximumReservedFringeDistance: 0,
            interiorHueCandidatesPreserved: 0,
            unresolvedCandidatePixels: 0, unresolvedReasons: [:], maximumReconstructionError: 0,
            nativeAlphaPassthrough: true, issues: [], sourceRGBAHash: source.digest, isolatedRGBAHash: output.digest))
    }
    var key = [Bool](repeating: false, count: count)
    var keyCounts = [[Int]](repeating: [Int](repeating: 0, count: 256), count: 3)
    var removed = 0
    for index in 0..<count {
        let o = index * 4
        let red = Int(source.bytes[o]), green = Int(source.bytes[o + 1]), blue = Int(source.bytes[o + 2])
        let matchesKey = trimReservedPixelFringe ? isPixelMagentaKey(red, green, blue) : isMagentaKey(red, green, blue)
        if source.bytes[o + 3] > 0 && matchesKey {
            key[index] = true; removed += 1
            for channel in 0..<3 { keyCounts[channel][Int(source.bytes[o + channel])] += 1 }
            for channel in 0..<4 { output.bytes[o + channel] = 0 }
        }
    }
    // Native generators occasionally emit one reserved-color corner pixel a
    // few bytes outside the key tolerance. Only an isolated near-key pixel
    // surrounded entirely by the strict key can be classified as matte noise.
    let strictKey = key
    var isolatedKeyOutliers = 0
    for index in 0..<count where !strictKey[index] {
        let o = index * 4, x = index % source.width, y = index / source.width
        let red = Int(source.bytes[o]), green = Int(source.bytes[o + 1]), blue = Int(source.bytes[o + 2])
        guard red >= 216, blue >= 216, green <= 48, abs(red - blue) <= 32 else { continue }
        var neighbors = 0, allStrict = true
        for dy in -1...1 {
            for dx in -1...1 where dx != 0 || dy != 0 {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= source.width || ny < 0 || ny >= source.height { continue }
                neighbors += 1
                if !strictKey[ny * source.width + nx] { allStrict = false }
            }
        }
        if neighbors >= 3 && allStrict {
            key[index] = true; removed += 1; isolatedKeyOutliers += 1
            for channel in 0..<3 { keyCounts[channel][Int(source.bytes[o + channel])] += 1 }
            for channel in 0..<4 { output.bytes[o + channel] = 0 }
        }
    }
    let measured = keyCounts.map { histogram -> Int in
        var cumulative = 0
        for value in 0..<256 {
            cumulative += histogram[value]
            if cumulative > removed / 2 { return value }
        }
        return 0
    }
    // Count the part of the global key that an exterior flood could not reach.
    var exterior = [Bool](repeating: false, count: count)
    var queue: [Int] = []
    func enqueueExterior(_ index: Int) {
        if !exterior[index] && (key[index] || source.bytes[index * 4 + 3] == 0) {
            exterior[index] = true; queue.append(index)
        }
    }
    for x in 0..<source.width { enqueueExterior(x); enqueueExterior((source.height - 1) * source.width + x) }
    for y in 0..<source.height { enqueueExterior(y * source.width); enqueueExterior(y * source.width + source.width - 1) }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]; cursor += 1
        let x = index % source.width, y = index / source.width
        if x > 0 { enqueueExterior(index - 1) }
        if x + 1 < source.width { enqueueExterior(index + 1) }
        if y > 0 { enqueueExterior(index - source.width) }
        if y + 1 < source.height { enqueueExterior(index + source.width) }
    }
    let enclosed = key.indices.filter { key[$0] && !exterior[$0] }.count
    // Follow only magenta-colored pixels from the actual key. This admits a
    // generated dark spill at an outline corner without reaching a separate
    // pink/peach detail through intervening coat pixels.
    var spillDepth = [UInt8](repeating: 255, count: count)
    queue.removeAll(keepingCapacity: true)
    for index in key.indices where key[index] { spillDepth[index] = 0; queue.append(index) }
    cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]; cursor += 1
        if spillDepth[index] >= 12 { continue }
        let x = index % source.width, y = index / source.width
        for dy in -1...1 {
            for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= source.width || ny < 0 || ny >= source.height { continue }
                let next = ny * source.width + nx, no = next * 4
                let red = Int(source.bytes[no]), green = Int(source.bytes[no + 1]), blue = Int(source.bytes[no + 2])
                let weakChromaPath = min(red, blue) - green >= 8 && abs(red - blue) <= 96
                if spillDepth[next] == 255 && weakChromaPath {
                    spillDepth[next] = spillDepth[index] + 1; queue.append(next)
                }
            }
        }
    }
    var boundaryPixels = 0, decontaminated = 0, projectedGreen = 0, projectedUpper = 0, lowCoverageRemoved = 0, unresolved = 0
    var unresolvedReasons: [String: Int] = [:]
    var reservedFringeRemoved = 0, maximumReservedDistance = 0, interiorHuePreserved = 0
    func rejectCandidate(_ reason: String, at index: Int) {
        // Pixel artwork explicitly reserves magenta for its matte. Hard-key
        // this narrow hue boundary; do not invent colored edge RGB from a
        // generated fringe that does not obey linear compositing. Subsequent
        // premultiplied-alpha resampling supplies clean output edge coverage.
        // This is separate from strict mode's color-connected unmixing.
        if trimReservedPixelFringe {
            let x = index % source.width, y = index / source.width
            var nearest = 17
            for dy in -16...16 {
                for dx in -16...16 {
                    let nx = x + dx, ny = y + dy
                    if nx < 0 || nx >= source.width || ny < 0 || ny >= source.height { continue }
                    let distance = max(abs(dx), abs(dy))
                    if distance < nearest && key[ny * source.width + nx] { nearest = distance }
                }
            }
            if nearest <= 16 {
                for channel in 0..<4 { output.bytes[index * 4 + channel] = 0 }
                reservedFringeRemoved += 1
                maximumReservedDistance = max(maximumReservedDistance, nearest)
                return
            }
            // Dark outline antialiasing, pink cheeks and nose colors can have
            // this low-chroma hue inside the character. Hue alone is not proof
            // of background. Keep their exact RGBA and expose the count for
            // visual review; only the high-saturation reserved key is global.
            interiorHuePreserved += 1
            return
        }
        unresolved += 1; unresolvedReasons[reason, default: 0] += 1
    }
    var maximumError = 0.0
    for index in 0..<count where removed > 0 && !key[index] && source.bytes[index * 4 + 3] > 0 {
        let o = index * 4
        let rgb = (0..<3).map { Int(source.bytes[o + $0]) }
        guard trimReservedPixelFringe
            ? isReservedPixelMagenta(rgb[0], rgb[1], rgb[2])
            : isMagentaMixture(rgb[0], rgb[1], rgb[2]) else { continue }
        if trimReservedPixelFringe {
            rejectCandidate("reservedHueOutsideSpatialBoundary", at: index)
            continue
        }
        let x = index % source.width, y = index / source.width
        guard spillDepth[index] <= 12 else { rejectCandidate("outsideConnectedMatteBand", at: index); continue }
        guard spillDepth[index] <= 4 || rgb[1] <= 96 else { rejectCandidate("unsupportedLightChromaPatch", at: index); continue }
        var localKey: (score: Int, rgb: [Double])?
        for dy in -12...12 {
            for dx in -12...12 {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= source.width || ny < 0 || ny >= source.height { continue }
                let next = ny * source.width + nx, distance = dx * dx + dy * dy
                let greenDeficit = max(0, Int(source.bytes[next * 4 + 1]) - rgb[1])
                let score = distance + greenDeficit * 100_000
                if key[next] && (localKey == nil || score < localKey!.score) {
                    localKey = (score, (0..<3).map { Double(source.bytes[next * 4 + $0]) })
                }
            }
        }
        guard let matte = localKey?.rgb else { rejectCandidate("noCompatibleLocalMatte", at: index); continue }
        boundaryPixels += 1
        let observed = rgb.map(Double.init)
        var anchor: (rgb: [Double], distance: Int, coverage: Double, score: Double)?
        for dy in -12...12 {
            for dx in -12...12 {
                let nx = x + dx, ny = y + dy
                if nx < 0 || nx >= source.width || ny < 0 || ny >= source.height { continue }
                let next = ny * source.width + nx, no = next * 4
                let foreground = (0..<3).map { Double(source.bytes[no + $0]) }
                // These anchors are actual dark ink from the selected artwork.
                guard source.bytes[no + 3] == 255, foreground.max()! <= 128,
                      min(foreground[0], foreground[2]) - foreground[1] <= 8 else { continue }
                var fitNumerator: Double = 0, fitDenominator: Double = 0, minimumCoverage: Double = 0
                for channel in 0..<3 {
                    let direction: Double = foreground[channel] - matte[channel]
                    fitNumerator += (observed[channel] - matte[channel]) * direction
                    fitDenominator += direction * direction
                    let channelMinimum: Double
                    if observed[channel] < matte[channel] {
                        channelMinimum = (matte[channel] - observed[channel]) / matte[channel]
                    } else {
                        channelMinimum = (observed[channel] - matte[channel]) / (255.0 - matte[channel])
                    }
                    if channelMinimum.isFinite { minimumCoverage = max(minimumCoverage, channelMinimum) }
                }
                let fittedCoverage: Double = fitNumerator / fitDenominator
                let coverage: Double = max(minimumCoverage, min(1.0, fittedCoverage))
                let distance = dx * dx + dy * dy
                var squaredError: Double = 0
                for channel in 0..<3 {
                    let error = foreground[channel] * coverage + matte[channel] * (1 - coverage) - observed[channel]
                    squaredError += error * error
                }
                // Prefer nearby intact ink when fits are comparable; use a
                // farther existing reference when the nearest one is physically
                // incompatible (for example a highlight beside dark outline).
                let score = squaredError + Double(distance) * 0.5
                if anchor == nil || score < anchor!.score {
                    anchor = (foreground, distance, coverage, score)
                }
            }
        }
        guard let anchor else { rejectCandidate("noIntactLocalOutline", at: index); continue }
        // Resolve the remaining matte chroma with an actual ink color difference,
        // then require physical RGB coverage. Using the anchor's lower red/blue
        // channel avoids declaring a genuine blue-black outline to be magenta.
        // The original RGB is unmixed; an anchor's texture is never copied.
        let chromaChannel = anchor.rgb[0] < anchor.rgb[2] ? 0 : 2
        let matteDifference = matte[chromaChannel] - matte[1]
        let outlineDifference = anchor.rgb[chromaChannel] - anchor.rgb[1]
        let differenceCoverage = (matteDifference - (observed[chromaChannel] - observed[1])) / (matteDifference - outlineDifference)
        var minimumCoverage: Double = 0
        for channel in 0..<3 {
            // Dark generated edge pixels can have G=0 while every local matte
            // sample has a small positive green value. Permit only this green
            // floor to project to zero, with an explicit recomposition bound.
            if channel == 1 && observed[channel] < matte[channel] { continue }
            // A channel clipped to255 carries no exact upper-gamut equation.
            // Preserve the lower physical bound; test any upper projection by
            // recomposing it below, instead of forcing an unchanged alpha of1.
            if observed[channel] < matte[channel] {
                let channelMinimum = (matte[channel] - observed[channel]) / matte[channel]
                if channelMinimum.isFinite { minimumCoverage = max(minimumCoverage, channelMinimum) }
            }
        }
        let coverage = max(differenceCoverage, minimumCoverage)
        if coverage <= 0.125 {
            // A trace with at most1/8 foreground coverage is predominantly the
            // reserved matte; keep the selected pixel silhouette crisp.
            for channel in 0..<4 { output.bytes[o + channel] = 0 }
            lowCoverageRemoved += 1
            continue
        }
        guard coverage.isFinite && coverage > 0 && coverage <= 1 else { rejectCandidate("invalidRecoveredCoverage", at: index); continue }
        var foreground = (0..<3).map { (observed[$0] - (1 - coverage) * matte[$0]) / coverage }
        guard [0, 2].allSatisfy({ foreground[$0] >= -0.00001 }) else {
            rejectCandidate("recoveredForegroundOutsidePhysicalRange", at: index); continue
        }
        let projectsGreen = foreground[1] < 0
        let projectsUpper = foreground.contains { $0 > 255 }
        foreground = foreground.map { min(255, max(0, $0)) }
        let recoveredRGB = foreground.map { Int($0.rounded()) }
        guard !isMagentaMixture(recoveredRGB[0], recoveredRGB[1], recoveredRGB[2]) else {
            rejectCandidate("noSupportedMatteContribution", at: index); continue
        }
        let alpha = UInt8(clamping: Int((Double(source.bytes[o + 3]) * coverage).rounded()))
        let outputRGB = foreground.map { alpha == 0 ? UInt8(0) : UInt8(clamping: Int($0.rounded())) }
        let roundTripCoverage = Double(alpha) / 255
        let error = (0..<3).map { abs(Double(outputRGB[$0]) * roundTripCoverage + matte[$0] * (1 - roundTripCoverage) - observed[$0]) }.max()!
        guard error <= 8 else { rejectCandidate("projectedColorResidualTooLarge", at: index); continue }
        for channel in 0..<3 { output.bytes[o + channel] = outputRGB[channel] }
        output.bytes[o + 3] = alpha
        if projectsGreen { projectedGreen += 1 }
        if projectsUpper { projectedUpper += 1 }
        decontaminated += 1; maximumError = max(maximumError, error)
    }
    zeroTransparentRGB(&output)
    var issues: [String] = []
    if removed == 0 && !nativeAlpha { issues.append("noMagentaKeyInOpaqueSource") }
    if unresolved > 0 { issues.append("unresolvedMagentaCandidates") }
    if reservedFringeRemoved > max(64, (count - removed) / 20) { issues.append("reservedFringeExceedsFivePercentOfForeground") }
    let record = ChromaMagentaRecord(keyColorRGB: [255, 0, 255], measuredKeyColorRGB: measured,
        keyTolerance: trimReservedPixelFringe
            ? "global reserved key min(R,B)>=160, min(R,B)-G>=96, abs(R-B)<=96; reserved fringe excess>=16,abs(R-B)<=64 or excess>=32,abs(R-B)<=128; neutral-bright fur protected; hard alpha trim only within Chebyshev distance16 of measured key; interior low-chroma colors preserved; no foreground RGB reconstruction"
            : "R/B>=224,G<=40,abs(R-B)<=32; isolated strict-key-surrounded outliers R/B>=216,G<=48; mixture: min(R,B)-G>=16,abs(R-B)<=64; connected weak-chroma path<=12px; beyond4px requires G<=96; compatible actual matte/dark-ink references<=12px; least-squares reference selection and physical color-difference unmix; clipped-channel projection requires recomposition error<=8/255; trace coverage<=1/8 removed",
        keyPixelsRemoved: removed, isolatedKeyOutliersRemoved: isolatedKeyOutliers, enclosedKeyPixelsRemoved: enclosed,
        boundaryBandPixels: boundaryPixels, decontaminatedEdgePixels: decontaminated, projectedGreenEdgePixels: projectedGreen,
        projectedUpperRGBEdgePixels: projectedUpper, lowCoverageSpillPixelsRemoved: lowCoverageRemoved,
        fringePolicy: trimReservedPixelFringe ? "reserved-color-hard-edge-16px" : "strict-unmix",
        reservedFringePixelsRemoved: reservedFringeRemoved, maximumReservedFringeDistance: maximumReservedDistance,
        interiorHueCandidatesPreserved: interiorHuePreserved,
        unresolvedCandidatePixels: unresolved, unresolvedReasons: unresolvedReasons, maximumReconstructionError: maximumError,
        nativeAlphaPassthrough: removed == 0 && nativeAlpha, issues: issues,
        sourceRGBAHash: source.digest, isolatedRGBAHash: output.digest)
    return (output, record)
}

func clearBoundedNeutralFringe(_ source: Raster, conservative: Raster,
                               floor: Int, spread: Int, depthLimit: Int = 2) -> Raster {
    var output = conservative
    var depth = [UInt8](repeating: 255, count: source.width * source.height)
    var queue: [Int] = []
    for index in depth.indices where conservative.bytes[index * 4 + 3] == 0 {
        depth[index] = 0
        queue.append(index)
    }
    func enqueue(_ index: Int, from previous: Int) {
        if depth[index] != 255 || Int(depth[previous]) >= depthLimit { return }
        let o = index * 4
        let rgb = [Int(source.bytes[o]), Int(source.bytes[o + 1]), Int(source.bytes[o + 2])]
        let minimum = rgb.min()!, difference = rgb.max()! - minimum
        // Bright pixels retained by the conservative mask are protected fur or
        // interior detail. Refinement must never open an unbounded route into it.
        if minimum >= 220 && difference <= 18 { return }
        if minimum < floor || difference > spread { return }
        depth[index] = depth[previous] + 1
        queue.append(index)
    }
    var cursor = 0
    while cursor < queue.count {
        let index = queue[cursor]; cursor += 1
        let x = index % source.width, y = index / source.width
        if x > 0 { enqueue(index - 1, from: index) }
        if x + 1 < source.width { enqueue(index + 1, from: index) }
        if y > 0 { enqueue(index - source.width, from: index) }
        if y + 1 < source.height { enqueue(index + source.width, from: index) }
    }
    for index in queue where conservative.bytes[index * 4 + 3] > 0 {
        for channel in 0..<4 { output.bytes[index * 4 + channel] = 0 }
    }
    return output
}

func components(_ image: Raster) -> [[Int]] {
    var visited = [Bool](repeating: false, count: image.width * image.height)
    var groups: [[Int]] = []
    for start in visited.indices where !visited[start] && image.bytes[start * 4 + 3] > 0 {
        var queue = [start]
        visited[start] = true
        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]; cursor += 1
            let x = index % image.width, y = index / image.width
            for dy in -1...1 {
                for dx in -1...1 where dx != 0 || dy != 0 {
                    let nx = x + dx, ny = y + dy
                    if nx < 0 || ny < 0 || nx >= image.width || ny >= image.height { continue }
                    let next = ny * image.width + nx
                    if !visited[next] && image.bytes[next * 4 + 3] > 0 {
                        visited[next] = true; queue.append(next)
                    }
                }
            }
        }
        groups.append(queue)
    }
    return groups.sorted { $0.count > $1.count }
}

func zeroTransparentRGB(_ image: inout Raster) {
    for o in stride(from: 0, to: image.bytes.count, by: 4) where image.bytes[o + 3] == 0 {
        image.bytes[o] = 0; image.bytes[o + 1] = 0; image.bytes[o + 2] = 0
    }
}

func removeUnanchoredTraceAlpha(_ source: Raster) -> (Raster, Int, Int, Int) {
    var image = source
    var removedPixels = 0, removedComponents = 0, maximumRemovedAlpha = 0
    for component in components(source) {
        let maximumAlpha = component.map { Int(source.bytes[$0 * 4 + 3]) }.max() ?? 0
        // Keep all alpha values of every component with even6.3% coverage.
        // Only disconnected, near-invisible noise without a visible anchor goes.
        if maximumAlpha >= 16 { continue }
        removedComponents += 1
        removedPixels += component.count
        maximumRemovedAlpha = max(maximumRemovedAlpha, maximumAlpha)
        for index in component { for channel in 0..<4 { image.bytes[index * 4 + channel] = 0 } }
    }
    return (image, removedPixels, removedComponents, maximumRemovedAlpha)
}

func renderLogical(_ cell: Raster, content: Bounds, scale: Double, baseline: Double) -> (Raster, Int) {
    var logical = Raster(width: 64, height: 64)
    for y in 0..<64 {
        for x in 0..<64 {
            let sourceX = Int(floor((Double(x) + 0.5 - 32) / scale + content.centerX))
            let sourceY = Int(floor((Double(y) + 0.5 - baseline) / scale + Double(content.bottom)))
            if sourceX < 0 || sourceY < 0 || sourceX >= cell.width || sourceY >= cell.height { continue }
            let src = cell.offset(sourceX, sourceY), dst = logical.offset(x, y)
            if cell.bytes[src + 3] < 128 { continue }
            for channel in 0..<3 { logical.bytes[dst + channel] = cell.bytes[src + channel] }
            logical.bytes[dst + 3] = 255
        }
    }
    // Remove only disconnected one-logical-pixel debris; every deletion is counted.
    let debris = components(logical).filter { $0.count == 1 }
    for component in debris { for index in component { for channel in 0..<4 { logical.bytes[index * 4 + channel] = 0 } } }
    var output = Raster(width: 128, height: 128)
    for y in 0..<128 {
        for x in 0..<128 {
            let src = logical.offset(x / 2, y / 2), dst = output.offset(x, y)
            for channel in 0..<4 { output.bytes[dst + channel] = logical.bytes[src + channel] }
        }
    }
    return (output, debris.count)
}

// Interpolate associated (premultiplied) RGB and alpha together, then unassociate.
// Transparent RGB never contributes color to a partially covered output pixel.
func samplePremultiplied(_ image: Raster, x: Double, y: Double) -> [UInt8] {
    let left = Int(floor(x)), top = Int(floor(y))
    let dx = x - Double(left), dy = y - Double(top)
    var alpha = 0.0, red = 0.0, green = 0.0, blue = 0.0
    for row in 0...1 {
        for column in 0...1 {
            let sx = left + column, sy = top + row
            if sx < 0 || sy < 0 || sx >= image.width || sy >= image.height { continue }
            let weight = (column == 0 ? 1 - dx : dx) * (row == 0 ? 1 - dy : dy)
            let o = image.offset(sx, sy)
            let coverage = Double(image.bytes[o + 3]) / 255
            let associatedWeight = weight * coverage
            alpha += associatedWeight
            red += Double(image.bytes[o]) * associatedWeight
            green += Double(image.bytes[o + 1]) * associatedWeight
            blue += Double(image.bytes[o + 2]) * associatedWeight
        }
    }
    let quantizedAlpha = UInt8(clamping: Int((alpha * 255).rounded()))
    if quantizedAlpha == 0 || alpha == 0 { return [0, 0, 0, 0] }
    return [UInt8(clamping: Int((red / alpha).rounded())),
            UInt8(clamping: Int((green / alpha).rounded())),
            UInt8(clamping: Int((blue / alpha).rounded())), quantizedAlpha]
}

func resizedPremultiplied(_ image: Raster, width: Int, height: Int) -> Raster {
    var output = Raster(width: width, height: height)
    for y in 0..<height {
        for x in 0..<width {
            let sx = (Double(x) + 0.5) * Double(image.width) / Double(width) - 0.5
            let sy = (Double(y) + 0.5) * Double(image.height) / Double(height) - 0.5
            let pixel = samplePremultiplied(image, x: sx, y: sy)
            let o = output.offset(x, y)
            for channel in 0..<4 { output.bytes[o + channel] = pixel[channel] }
        }
    }
    return output
}

func renderHighResolution(_ cell: Raster, content: Bounds, scale: Double,
                          baseline: Double, alignsGround: Bool, canvasSize: Int = 256) -> (Raster, Int) {
    var output = Raster(width: canvasSize, height: canvasSize)
    let samplingBaseline = baseline - max(0, (scale - 1) / 2)
    for y in 0..<canvasSize {
        for x in 0..<canvasSize {
            // Raster indices describe pixel centers; subtract0.5 after mapping
            // the output pixel center into the source-cell coordinate system.
            let sx = (Double(x) + 0.5 - Double(canvasSize) / 2) / scale + content.centerX - 0.5
            let sy = (Double(y) + 0.5 - samplingBaseline) / scale + Double(content.bottom) - 0.5
            let pixel = samplePremultiplied(cell, x: sx, y: sy)
            let o = output.offset(x, y)
            for channel in 0..<4 { output.bytes[o + channel] = pixel[channel] }
        }
    }
    // Bilinear coverage can extend one pixel beyond the mathematical source box.
    // Use a whole-pixel translation to align the actual soft-alpha ground edge;
    // the shared scale stays unchanged and no edge pixels are painted or keyed.
    let shift = alignsGround ? Int(baseline.rounded()) - (bounds(output)?.bottom ?? Int(baseline)) : 0
    if shift != 0 {
        var aligned = Raster(width: canvasSize, height: canvasSize)
        for y in 0..<canvasSize {
            let sourceY = y - shift
            if sourceY < 0 || sourceY >= canvasSize { continue }
            let start = output.offset(0, sourceY)
            aligned.bytes.replaceSubrange(y * canvasSize * 4..<(y + 1) * canvasSize * 4,
                                          with: output.bytes[start..<start + canvasSize * 4])
        }
        output = aligned
    }
    return (output, shift)
}

func samplingScale(mode: ImportMode, artLimit: Double, width: Int, height: Int) -> Double {
    if mode == .pixel64 { return min(artLimit / Double(width), artLimit / Double(height)) }
    // Keep a2px output guard for downsampling and the full one-source-pixel
    // bilinear footprint when upsampling. Both constraints must fit the canvas.
    return min((artLimit - 2) / Double(width), (artLimit - 2) / Double(height),
               artLimit / Double(width + 1), artLimit / Double(height + 1))
}

struct FrameMetrics: Codable {
    let mode: String
    let file: String
    let width: Int
    let height: Int
    let pngBitDepth: Int
    let pngColorType: Int
    let alphaBounds: Bounds?
    let minimumPadding: Int
    let opaquePixels: Int
    let nonbinaryAlphaPixels: Int
    let hiddenRGBPixels: Int
    let latticeMismatches: Int
    let componentAreas8: [Int]
    let componentMaximumAlpha8: [Int]
    let componentEquivalentOpaqueAreas8: [Double]
    let logicalSinglePixelIslands: Int
    let centroidX: Double?
    let centroidY: Double?
    let rgbaSHA256: String
    let issues: [String]
}

func inspect(_ image: Raster, file: URL, mode: ImportMode = .pixel64) throws -> FrameMetrics {
    let data = try Data(contentsOf: file)
    let bitDepth = data.count > 25 ? Int(data[24]) : -1
    let colorType = data.count > 25 ? Int(data[25]) : -1
    let box = bounds(image)
    let padding = box.map { min($0.x, $0.y, image.width - $0.right, image.height - $0.bottom) } ?? min(image.width, image.height)
    var opaque = 0, nonbinary = 0, hiddenRGB = 0, lattice = 0
    var totalX = 0.0, totalY = 0.0
    for y in 0..<image.height {
        for x in 0..<image.width {
            let o = image.offset(x, y), alpha = image.bytes[o + 3]
            if alpha != 0 && alpha != 255 { nonbinary += 1 }
            if alpha == 0 && image.bytes[o..<o + 3].contains(where: { $0 != 0 }) { hiddenRGB += 1 }
            if alpha > 0 { opaque += 1; totalX += Double(x) + 0.5; totalY += Double(y) + 0.5 }
            let anchor = image.offset(x - x % 2, y - y % 2)
            if image.bytes[o..<o + 4] != image.bytes[anchor..<anchor + 4] { lattice += 1 }
        }
    }
    let groups = components(image)
    let areas = groups.map(\.count)
    let componentMaximumAlpha = groups.map { component in component.map { Int(image.bytes[$0 * 4 + 3]) }.max() ?? 0 }
    let componentAlphaMass = groups.map { component in
        component.reduce(0.0) { $0 + Double(image.bytes[$1 * 4 + 3]) / 255 }
    }
    let logicalIslands = lattice == 0 ? areas.filter { $0 == 4 }.count : 0
    var issues: [String] = []
    if image.width != mode.canvasSize || image.height != mode.canvasSize { issues.append("invalidDimensions") }
    if bitDepth != 8 || colorType != 6 { issues.append("not8BitRGBA") }
    if opaque == 0 { issues.append("emptyFrame") }
    if padding < mode.padding { issues.append("paddingBelow\(mode.padding)") }
    if mode == .pixel64 && nonbinary > 0 { issues.append("nonbinaryAlpha") }
    if hiddenRGB > 0 { issues.append("hiddenRGB") }
    if mode == .pixel64 && lattice > 0 { issues.append("not64LogicalPixelLattice") }
    if mode == .pixel64 && (areas.contains(1) || logicalIslands > 0) { issues.append("singlePixelDebris") }
    return FrameMetrics(mode: mode.rawValue, file: file.path, width: image.width, height: image.height,
        pngBitDepth: bitDepth, pngColorType: colorType, alphaBounds: box, minimumPadding: padding,
        opaquePixels: opaque, nonbinaryAlphaPixels: nonbinary, hiddenRGBPixels: hiddenRGB,
        latticeMismatches: lattice, componentAreas8: areas, componentMaximumAlpha8: componentMaximumAlpha,
        componentEquivalentOpaqueAreas8: componentAlphaMass, logicalSinglePixelIslands: logicalIslands,
        centroidX: opaque > 0 ? totalX / Double(opaque) : nil,
        centroidY: opaque > 0 ? totalY / Double(opaque) : nil, rgbaSHA256: image.digest, issues: issues)
}

struct CellMap: Codable {
    let state: String
    let frame: Int
    let sourceFile: String
    let sourceSHA256: String
    let sourceCanvasOffsetY: Int
    let cell: Bounds
    let sourceContent: Bounds
    let sourceScalePolicy: String
    let requestedSourceToOutputScale: Double
    let nativeFitLimited: Bool
    let sourceToOutputScale: Double
    let sourcePixelsPerOutputPixel: Double
    let upscalesSource: Bool
    let outputArtLimit: Double
    let outputBaseline: Double
    let logicalScale: Double?
    let logicalArtLimit: Double?
    let logicalBaseline: Double?
    let groundAlignmentTranslationY: Int
    let backgroundMethod: String
    let backgroundPixelsRemoved: Int
    let detachedSourcePixelsRemoved: Int
    let logicalDebrisPixelsRemoved: Int
    let output: String
}

struct ImportReport: Encodable {
    let schemaVersion = 1
    let mode: String
    let outputCanvasSize: Int
    let displayHeight: Int
    let resampling: String
    let sourceLayout: String
    let sourceScalePolicy: String
    let sources: [SourceRecord]
    let source: String
    let sourceSHA256: String
    let sourceWidth: Int
    let sourceHeight: Int
    let sourceTransparentPixels: Int
    let sourcePartialAlphaPixels: Int
    let sourceLowAlphaPixelsDiscarded: Int
    let sourceAdditionalNeutralEdgePixelsRemoved: Int
    let sourceEnclosedBrightPixelsLost: Int
    let sourceDisconnectedTraceAlphaPixelsRemoved: Int
    let sourceDisconnectedTraceAlphaComponentsRemoved: Int
    let sourceMaximumDiscardedTraceAlpha: Int
    let columns: Int
    let rows: Int
    let states: [String]
    let poseExceptions: [String]
    let cells: [CellMap]
    let metrics: [FrameMetrics]
    let valid: Bool
}

struct SourceRecord: Codable {
    let file: String
    let sha256: String
    let width: Int
    let height: Int
    let transparentPixels: Int
    let partialAlphaPixels: Int
    let lowAlphaPixelsDiscarded: Int
    let additionalNeutralEdgePixelsRemoved: Int
    let enclosedBrightPixelsLost: Int
    let disconnectedTraceAlphaPixelsRemoved: Int
    let disconnectedTraceAlphaComponentsRemoved: Int
    let maximumDiscardedTraceAlpha: Int
    let backgroundMethod: String
    let chromaMagenta: ChromaMagentaRecord?
    let originalAlphaBounds: Bounds?
    let isolatedAlphaBounds: Bounds?
    let sourceEdgeContacts: [String: Int]?
    let sourceMeaningfulEdgeContacts: [String: Int]?
    let isolatedEdgeContacts: [String: Int]?
    let isolatedMeaningfulEdgeContacts: [String: Int]?
}

struct PreparedSource {
    let record: SourceRecord
    let original: Raster
    let flooded: Raster
    let normalized: Raster
}

func writeJSON<T: Encodable>(_ value: T, _ url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoder.encode(value).write(to: url, options: .atomic)
}

func options(_ arguments: [String]) throws -> [String: String] {
    if !arguments.count.isMultiple(of: 2) { throw Failure("Options must be --key value pairs") }
    var result: [String: String] = [:]
    for i in stride(from: 0, to: arguments.count, by: 2) {
        if !arguments[i].hasPrefix("--") { throw Failure("Invalid option \(arguments[i])") }
        result[arguments[i]] = arguments[i + 1]
    }
    return result
}

func required(_ key: String, _ options: [String: String]) throws -> String {
    guard let value = options[key], !value.isEmpty else { throw Failure("Missing \(key)") }
    return value
}

func limits(_ value: String?, maximum: Double = 52) throws -> [String: Double] {
    var result: [String: Double] = [:]
    for item in (value ?? "").split(separator: ",") {
        let parts = item.split(separator: ":")
        guard parts.count == 2, let limit = Double(parts[1]), limit > 2, limit <= maximum else {
            throw Failure("State limits use state:pixels (greater than 2, at most \(maximum)), comma-separated")
        }
        result[String(parts[0])] = limit
    }
    return result
}

// Generated sheets often have four rows without mathematically equal cells.
// Cut through the nearest entirely transparent gutter, never through an ear/prop.
func gutterCuts(length: Int, count: Int, empty: (Int) -> Bool) throws -> [Int] {
    var runs: [Range<Int>] = []
    var start: Int?
    for index in 0...length {
        if index < length && empty(index) {
            if start == nil { start = index }
        } else if let begin = start {
            if index - begin >= 3 { runs.append(begin..<index) }
            start = nil
        }
    }
    var cuts = [0]
    for index in 1..<count {
        let nominal = index * length / count
        let candidates = runs.map { ($0.lowerBound + $0.upperBound) / 2 }.filter {
            $0 > cuts.last! && $0 < length && abs($0 - nominal) <= length / count / 2
        }
        guard let cut = candidates.min(by: { abs($0 - nominal) < abs($1 - nominal) }) else {
            throw Failure("No transparent gutter near grid boundary \(index)/\(count); inspect source layout")
        }
        cuts.append(cut)
    }
    cuts.append(length)
    return cuts
}

func prepareSource(_ url: URL, mode: ImportMode, background: String,
                   neutralFloor: Int, neutralSpread: Int) throws -> PreparedSource {
    // Couple pixels and provenance to the same immutable byte snapshot while
    // generation workers may be replacing another version of a source file.
    let sourceData = try Data(contentsOf: url)
    let source = try Raster.decode(sourceData, sourceDescription: url.path)
    let transparent = source.transparentCount
    let partial = stride(from: 3, to: source.bytes.count, by: 4).filter {
        source.bytes[$0] > 0 && source.bytes[$0] < 255
    }.count
    // Any native nonopaque alpha is meaningful, including a source whose
    // almost-transparent background has no fully zero-alpha pixels yet.
    let removeBackground = background == "neutral-edge" || (background == "auto" && transparent == 0 && partial == 0)
    var flooded = source
    var chromaMagenta: ChromaMagentaRecord?
    var additionalEdgePixels = 0, enclosedBrightLost = 0
    let usesMagenta = background == "chroma-magenta" || background == "chroma-magenta-pixel"
    if usesMagenta {
        (flooded, chromaMagenta) = clearChromaMagenta(source, trimReservedPixelFringe: background == "chroma-magenta-pixel")
        for o in stride(from: 0, to: source.bytes.count, by: 4)
            where source.bytes[o + 3] > 0 && flooded.bytes[o + 3] == 0 {
            let rgb = [Int(source.bytes[o]), Int(source.bytes[o + 1]), Int(source.bytes[o + 2])]
            if rgb.min()! >= 220 && rgb.max()! - rgb.min()! <= 18 { enclosedBrightLost += 1 }
        }
    } else if removeBackground {
        let conservative = clearNeutralEdge(source).0
        if mode.isHighResolution && (neutralFloor != 220 || neutralSpread != 18) {
            flooded = clearBoundedNeutralFringe(source, conservative: conservative,
                                                floor: neutralFloor, spread: neutralSpread)
        } else { flooded = clearNeutralEdge(source, floor: neutralFloor, spread: neutralSpread).0 }
        if neutralFloor != 220 || neutralSpread != 18 {
            for o in stride(from: 0, to: source.bytes.count, by: 4)
                where conservative.bytes[o + 3] > 0 && flooded.bytes[o + 3] == 0 {
                additionalEdgePixels += 1
                let rgb = [Int(source.bytes[o]), Int(source.bytes[o + 1]), Int(source.bytes[o + 2])]
                if rgb.min()! >= 220 && rgb.max()! - rgb.min()! <= 18 { enclosedBrightLost += 1 }
            }
        }
    }
    var tracePixels = 0, traceComponents = 0, maximumTraceAlpha = 0
    if mode.isHighResolution && !removeBackground && !usesMagenta {
        (flooded, tracePixels, traceComponents, maximumTraceAlpha) = removeUnanchoredTraceAlpha(source)
    }
    var normalized = flooded
    var discardedAlpha = 0
    if mode == .pixel64 {
        for o in stride(from: 0, to: normalized.bytes.count, by: 4) {
            let alpha = normalized.bytes[o + 3]
            if alpha < 128 {
                if alpha > 0 { discardedAlpha += 1 }
                for channel in 0..<4 { normalized.bytes[o + channel] = 0 }
            } else { normalized.bytes[o + 3] = 255 }
        }
    }
    zeroTransparentRGB(&normalized)
    let method = usesMagenta
        ? (chromaMagenta?.nativeAlphaPassthrough == true
           ? "\(background)(native-alpha-passthrough)"
           : "\(background)(global-saturated-key + \(chromaMagenta?.fringePolicy ?? "strict-unmix"))")
        : removeBackground
        ? (mode.isHighResolution && (neutralFloor != 220 || neutralSpread != 18)
           ? "conservative-neutral-edge(220/18) + bounded-neutral-fringe(maxDepth=2,minRGB=\(neutralFloor),spread<=\(neutralSpread),protectedBrightFur=true)"
           : "four-connected-neutral-edge(minRGB=\(neutralFloor),spread<=\(neutralSpread))")
        : (mode.isHighResolution
           ? "original-alpha + disconnected-trace-component-cleanup(maxAlpha<16)"
           : "original-alpha-threshold128")
    let record = SourceRecord(file: url.path,
        sha256: SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined(),
        width: source.width, height: source.height, transparentPixels: transparent,
        partialAlphaPixels: partial, lowAlphaPixelsDiscarded: discardedAlpha,
        additionalNeutralEdgePixelsRemoved: additionalEdgePixels, enclosedBrightPixelsLost: enclosedBrightLost,
        disconnectedTraceAlphaPixelsRemoved: tracePixels, disconnectedTraceAlphaComponentsRemoved: traceComponents,
        maximumDiscardedTraceAlpha: maximumTraceAlpha, backgroundMethod: method, chromaMagenta: chromaMagenta,
        originalAlphaBounds: bounds(source), isolatedAlphaBounds: bounds(normalized),
        sourceEdgeContacts: edgeContacts(source), sourceMeaningfulEdgeContacts: edgeContacts(source, minimumAlpha: 16),
        isolatedEdgeContacts: edgeContacts(normalized), isolatedMeaningfulEdgeContacts: edgeContacts(normalized, minimumAlpha: 16))
    return PreparedSource(record: record, original: source, flooded: flooded, normalized: normalized)
}

func sourceInfo(_ values: [String: String]) throws {
    let mode = try importMode(values)
    let background = values["--background"] ?? "auto"
    let floor = Int(values["--neutral-floor"] ?? "160") ?? -1
    let spread = Int(values["--neutral-spread"] ?? "36") ?? -1
    guard ["auto", "alpha", "neutral-edge", "chroma-magenta", "chroma-magenta-pixel"].contains(background), (0...255).contains(floor), (0...255).contains(spread) else {
        throw Failure("Source inspection needs a valid background method and neutral byte thresholds")
    }
    let source = try prepareSource(URL(fileURLWithPath: required("--sheet", values)), mode: mode,
        background: background, neutralFloor: floor, neutralSpread: spread)
    try writeJSON(source.record, URL(fileURLWithPath: required("--report", values)))
    print("Native source \(source.record.width)x\(source.record.height); isolated edge contacts \(source.record.isolatedEdgeContacts ?? [:]); report saved")
}

func resolvedScale(mode: ImportMode, requested: Double, policy: String) throws -> Double {
    let outputMultiplier = mode == .pixel64 ? 2.0 : 1.0
    switch policy {
    case "fit": return requested
    case "no-upscale": return min(requested, 1 / outputMultiplier)
    case "require-native-fit":
        guard requested * outputMultiplier <= 1 else {
            throw Failure("Source artwork is too small for native output fit (would require \(requested * outputMultiplier)x enlargement); supply larger native frames or choose no-upscale to retain their actual size")
        }
        return requested
    default: throw Failure("--scale-policy must be no-upscale, require-native-fit, or fit")
    }
}

@discardableResult
func importSheet(_ values: [String: String], separateFrames: [URL]? = nil) throws -> ImportReport {
    let mode = try importMode(values)
    let output = URL(fileURLWithPath: try required("--output-dir", values), isDirectory: true)
    let states = try required("--states", values).split(separator: ",").map(String.init)
    let individual = separateFrames != nil
    let columns = individual ? (separateFrames?.count ?? 0) : (Int(values["--columns"] ?? "4") ?? 0)
    let rows = individual ? 1 : (Int(values["--rows"] ?? String(states.count)) ?? 0)
    let singleStateGrid = individual || values["--single-state-grid"] == "true"
    let frameStart = Int(values["--frame-start"] ?? "0") ?? -1
    let frameCount = Int(values["--frame-count"] ?? String(separateFrames?.count ?? 4)) ?? 0
    guard [4, 8].contains(frameCount) else { throw Failure("--frame-count must be 4 or 8") }
    guard columns > 0, rows > 0, !states.isEmpty, states.count <= rows else {
        throw Failure("States map to the first grid rows; their count must not exceed --rows")
    }
    if singleStateGrid && states.count != 1 { throw Failure("A single-state source group requires exactly one state") }
    if individual && separateFrames?.count != frameCount { throw Failure("Separate-frame state groups must match --frame-count") }
    let framesPerState = singleStateGrid ? columns * rows : columns
    guard frameStart >= 0, frameStart + framesPerState <= frameCount else {
        throw Failure("Frame numbering must remain within 0...\(frameCount - 1); --frame-start supports partial single-frame samples")
    }
    let sourceURLs = try separateFrames ?? [URL(fileURLWithPath: required("--sheet", values))]
    let stateLimits = try limits(values["--state-limits"], maximum: mode.maximumArtSpan)
    let exceptions = (values["--pose-exceptions"] ?? "jump,dragging").split(separator: ",").map(String.init)
    let mainBodyStates = (values["--keep-main-body-states"] ?? "").split(separator: ",").map(String.init)
    let background = values["--background"] ?? "auto"
    guard ["auto", "alpha", "neutral-edge", "chroma-magenta", "chroma-magenta-pixel"].contains(background) else { throw Failure("Background must be auto, alpha, neutral-edge, chroma-magenta, or chroma-magenta-pixel") }
    let neutralFloor = Int(values["--neutral-floor"] ?? "220") ?? -1
    let neutralSpread = Int(values["--neutral-spread"] ?? "18") ?? -1
    guard (0...255).contains(neutralFloor), (0...255).contains(neutralSpread) else {
        throw Failure("Neutral floor and spread must be byte values 0...255")
    }
    let scalePolicy = values["--scale-policy"] ?? (mode == .highres1024 ? "no-upscale" : "fit")
    guard ["fit", "no-upscale", "require-native-fit"].contains(scalePolicy) else {
        throw Failure("--scale-policy must be no-upscale, require-native-fit, or fit")
    }
    let fixedOutputScale: Double?
    if let raw = values["--source-scale"] {
        guard let value = Double(raw), value.isFinite, value > 0 else {
            throw Failure("--source-scale must be a finite positive source-to-output ratio")
        }
        fixedOutputScale = value
    } else { fixedOutputScale = nil }
    let sources = try sourceURLs.map { try prepareSource($0, mode: mode, background: background,
                                                        neutralFloor: neutralFloor, neutralSpread: neutralSpread) }
    let first = sources[0]
    let sharedSourceHeight = sources.map { $0.record.height }.max()!
    let rowCuts = individual ? [0, first.normalized.height] : try gutterCuts(length: first.normalized.height, count: rows) { y in
        (0..<first.normalized.width).allSatisfy { first.normalized.bytes[first.normalized.offset($0, y) + 3] == 0 }
    }
    var maps: [CellMap] = [], metrics: [FrameMetrics] = []
    var previewRows: [[URL]] = []
    for row in 0..<states.count {
        var cells: [(raster: Raster, content: Bounds, cell: Bounds, cleared: Int, detached: Int, sourceIndex: Int)] = []
        func appendCell(sourceIndex: Int, box: Bounds) throws {
            let source = sources[sourceIndex]
            var cell = source.normalized.crop(x: box.x, y: box.y, width: box.width, height: box.height)
            let original = source.original.crop(x: box.x, y: box.y, width: box.width, height: box.height)
            let flooded = source.flooded.crop(x: box.x, y: box.y, width: box.width, height: box.height)
            var detached = 0
            if mainBodyStates.contains(states[row]) {
                for component in components(cell).dropFirst() {
                    detached += component.count
                    for index in component { for channel in 0..<4 { cell.bytes[index * 4 + channel] = 0 } }
                }
            }
            guard let content = bounds(cell) else { throw Failure("Empty source cell for \(states[row]) in \(source.record.file)") }
            if min(content.x, content.y, cell.width - content.right, cell.height - content.bottom) == 0 {
                let traceOnly = permitsTraceOnlyEdgeContact(cell, mode: mode)
                if !traceOnly {
                    throw Failure("Source cell for \(states[row]) has meaningful edge contact after isolation; regenerate clipped content in \(source.record.file)")
                }
            }
            cells.append((cell, content, box, flooded.transparentCount - original.transparentCount, detached, sourceIndex))
        }
        if individual {
            for index in sources.indices {
                try appendCell(sourceIndex: index, box: Bounds(x: 0, y: 0,
                    width: sources[index].normalized.width, height: sources[index].normalized.height))
            }
        } else {
            let sourceRows = singleStateGrid ? Array(0..<rows) : [row]
            for sourceRow in sourceRows {
                let y = rowCuts[sourceRow], nextY = rowCuts[sourceRow + 1]
                let columnCuts = try gutterCuts(length: first.normalized.width, count: columns) { x in
                    (y..<nextY).allSatisfy { first.normalized.bytes[first.normalized.offset(x, $0) + 3] == 0 }
                }
                for col in 0..<columns {
                    try appendCell(sourceIndex: 0, box: Bounds(x: columnCuts[col], y: y,
                        width: columnCuts[col + 1] - columnCuts[col], height: nextY - y))
                }
            }
        }
        let largestWidth = cells.map { $0.content.width }.max()!
        let largestHeight = cells.map { $0.content.height }.max()!
        // Native generators can return different canvas dimensions per frame.
        // Align those coordinate systems by their bottom edge using translation;
        // source pixels keep their original size and the state scale stays shared.
        func sourceYOffset(_ cell: (raster: Raster, content: Bounds, cell: Bounds, cleared: Int, detached: Int, sourceIndex: Int)) -> Int {
            individual ? sharedSourceHeight - sources[cell.sourceIndex].record.height : 0
        }
        let maxBottom = cells.map { $0.content.bottom + sourceYOffset($0) }.max()!
        let minTop = cells.map { $0.content.y + sourceYOffset($0) }.min()!
        let artLimit = stateLimits[states[row]] ?? (states[row] == "jump" ? mode.jumpArtSpan : mode.maximumArtSpan)
        let floating = exceptions.contains(states[row])
        let height = floating ? maxBottom - minTop : largestHeight
        let fitScale = samplingScale(mode: mode, artLimit: artLimit, width: largestWidth, height: height)
        let outputMultiplier = mode == .pixel64 ? 2.0 : 1.0
        let requestedScale = fixedOutputScale.map { $0 / outputMultiplier } ?? fitScale
        guard requestedScale <= fitScale + 1e-9 else {
            throw Failure("Fixed source scale would exceed the state art limit; review the new pose bounds or increase artLimit within the canvas limit")
        }
        let scale = try resolvedScale(mode: mode, requested: requestedScale, policy: scalePolicy)
        var previewRow: [URL] = []
        for (index, cell) in cells.enumerated() {
            let frame = index + frameStart
            let baseline = floating ? mode.baseline - Double(maxBottom - cell.content.bottom - sourceYOffset(cell)) * scale : mode.baseline
            let image: Raster
            let debris: Int
            let alignmentShift: Int
            if mode.isHighResolution {
                (image, alignmentShift) = renderHighResolution(cell.raster, content: cell.content, scale: scale,
                    baseline: baseline, alignsGround: !floating, canvasSize: mode.canvasSize)
                debris = 0
            } else {
                (image, debris) = renderLogical(cell.raster, content: cell.content, scale: scale, baseline: baseline)
                alignmentShift = 0
            }
            let destination = output.appendingPathComponent("\(states[row])_\(frame).png")
            try image.write(destination)
            metrics.append(try inspect(image, file: destination, mode: mode))
            let record = sources[cell.sourceIndex].record
            let outputScale = scale * outputMultiplier
            maps.append(CellMap(state: states[row], frame: frame, sourceFile: record.file, sourceSHA256: record.sha256,
                sourceCanvasOffsetY: sourceYOffset(cell),
                cell: cell.cell, sourceContent: cell.content, sourceScalePolicy: scalePolicy,
                requestedSourceToOutputScale: requestedScale * outputMultiplier, nativeFitLimited: scale < requestedScale,
                sourceToOutputScale: outputScale, sourcePixelsPerOutputPixel: 1 / outputScale,
                upscalesSource: outputScale > 1, outputArtLimit: artLimit * outputMultiplier,
                outputBaseline: baseline * outputMultiplier,
                logicalScale: mode == .pixel64 ? scale : nil,
                logicalArtLimit: mode == .pixel64 ? artLimit : nil,
                logicalBaseline: mode == .pixel64 ? baseline : nil,
                groundAlignmentTranslationY: alignmentShift,
                backgroundMethod: record.backgroundMethod + (individual ? " + separate-full-frame" : " + transparent-gutter-grid"),
                backgroundPixelsRemoved: cell.cleared, detachedSourcePixelsRemoved: cell.detached,
                logicalDebrisPixelsRemoved: debris, output: destination.path))
            previewRow.append(destination)
        }
        previewRows.append(previewRow)
    }
    let records = sources.map(\.record)
    let enclosedBrightLost = records.reduce(0) { $0 + $1.enclosedBrightPixelsLost }
    let report = ImportReport(mode: mode.rawValue, outputCanvasSize: mode.canvasSize,
        displayHeight: mode.displayHeight, resampling: mode.resampling,
        sourceLayout: individual ? "separate-frames" : "sheet", sourceScalePolicy: scalePolicy, sources: records,
        source: first.record.file, sourceSHA256: first.record.sha256,
        sourceWidth: first.record.width, sourceHeight: first.record.height,
        sourceTransparentPixels: records.reduce(0) { $0 + $1.transparentPixels },
        sourcePartialAlphaPixels: records.reduce(0) { $0 + $1.partialAlphaPixels },
        sourceLowAlphaPixelsDiscarded: records.reduce(0) { $0 + $1.lowAlphaPixelsDiscarded },
        sourceAdditionalNeutralEdgePixelsRemoved: records.reduce(0) { $0 + $1.additionalNeutralEdgePixelsRemoved },
        sourceEnclosedBrightPixelsLost: enclosedBrightLost,
        sourceDisconnectedTraceAlphaPixelsRemoved: records.reduce(0) { $0 + $1.disconnectedTraceAlphaPixelsRemoved },
        sourceDisconnectedTraceAlphaComponentsRemoved: records.reduce(0) { $0 + $1.disconnectedTraceAlphaComponentsRemoved },
        sourceMaximumDiscardedTraceAlpha: records.map(\.maximumDiscardedTraceAlpha).max() ?? 0,
        columns: columns, rows: rows, states: states, poseExceptions: exceptions,
        cells: maps, metrics: metrics,
        valid: metrics.allSatisfy { $0.issues.isEmpty } && (!mode.isHighResolution || enclosedBrightLost == 0)
            && records.allSatisfy { $0.chromaMagenta?.issues.isEmpty ?? true })
    let reportURL = URL(fileURLWithPath: values["--report"] ?? output.appendingPathComponent("import-report.json").path)
    try writeJSON(report, reportURL)
    if let preview = values["--preview"] {
        try contactSheet(rows: previewRows, labels: states, destination: URL(fileURLWithPath: preview), mode: mode)
    }
    let fitLimited = maps.filter(\.nativeFitLimited).count
    print("Imported \(metrics.count) \(mode.canvasSize)px frames; QA \(report.valid ? "PASS" : "FAIL"); native-fit limited \(fitLimited); report: \(reportURL.path)")
    if !report.valid { throw Failure("Import has pixel QA, protected-white source loss, or unresolved chroma isolation; inspect the report. Staged output is not production-approved.") }
    return report
}

struct SourceManifestEntry: Decodable {
    let skin: String
    let state: String
    let sheet: String?
    let frames: [String]?
    let columns: Int?
    let rows: Int?
    let artLimit: Double?
    let sourceScale: Double?
    let keepMainBody: Bool?
    let preserveAltitude: Bool?
    let background: String?
    let scalePolicy: String?
    var key: String { "\(skin)/\(state)" }
}

struct SourceManifest: Decodable {
    let version: Int
    let mode: String?
    let scalePolicy: String?
    let background: String?
    let neutralFloor: Int?
    let neutralSpread: Int?
    let entries: [SourceManifestEntry]
}

struct SourceReportIndexEntry: Codable {
    let skin: String
    let state: String
    let report: String
}

struct SourceReportIndex: Codable {
    let version: Int
    let mode: String
    let sourceManifest: String
    let sourceManifestSHA256: String
    let entries: [SourceReportIndexEntry]
}

func resolveSourcePath(_ path: String, manifestURL: URL) -> URL {
    path.hasPrefix("/") ? URL(fileURLWithPath: path)
        : manifestURL.deletingLastPathComponent().appendingPathComponent(path).standardizedFileURL
}

@discardableResult
func importManifest(_ values: [String: String]) throws -> SourceReportIndex {
    let manifestURL = URL(fileURLWithPath: try required("--source-manifest", values))
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(SourceManifest.self, from: manifestData)
    guard manifest.version == 1, !manifest.entries.isEmpty else { throw Failure("Source manifest needs version1 and at least one entry") }
    let mode = try importMode(["--mode": values["--mode"] ?? manifest.mode ?? "highres1024"])
    let output = URL(fileURLWithPath: try required("--output-dir", values), isDirectory: true)
    let allowedName = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    var keys: Set<String> = []
    for entry in manifest.entries {
        guard !entry.skin.isEmpty, !entry.state.isEmpty,
              entry.skin.unicodeScalars.allSatisfy({ allowedName.contains($0) }),
              entry.state.unicodeScalars.allSatisfy({ allowedName.contains($0) }) else {
            throw Failure("Skin/state names must contain only letters, numbers, underscores, or hyphens")
        }
        guard keys.insert(entry.key).inserted else { throw Failure("Duplicate source entry: \(entry.key)") }
        guard (entry.sheet != nil) != (entry.frames != nil) else { throw Failure("\(entry.key) needs exactly one of sheet or frames") }
        if let frames = entry.frames {
            guard [4, 8].contains(frames.count), Set(frames).count == frames.count else {
                throw Failure("\(entry.key) needs four or eight distinct, ordered native frame files")
            }
        } else {
            guard (entry.columns ?? 2) > 0, (entry.rows ?? 2) > 0,
                  [4, 8].contains((entry.columns ?? 2) * (entry.rows ?? 2)) else {
                throw Failure("\(entry.key) sheet must contain exactly four or eight cells")
            }
        }
    }
    let selected = Set((values["--only"] ?? "").split(separator: ",").map(String.init))
    guard selected.isSubset(of: keys) else { throw Failure("--only contains a skin/state absent from the source manifest") }
    let entries = manifest.entries.filter { selected.isEmpty || selected.contains($0.key) }
    // Check source presence before staging anything. --only supports approved
    // sample groups while the remaining native images are still being generated.
    for entry in entries {
        for path in entry.frames ?? [entry.sheet!] {
            let url = resolveSourcePath(path, manifestURL: manifestURL)
            guard FileManager.default.fileExists(atPath: url.path) else { throw Failure("Missing source for \(entry.key): \(url.path)") }
        }
    }
    let manifestDigest = SHA256.hash(data: manifestData).map { String(format: "%02x", $0) }.joined()
    let indexURL = output.appendingPathComponent("source-import-index.json")
    var indexEntries: [SourceReportIndexEntry] = []
    if values["--append"] == "true" && FileManager.default.fileExists(atPath: indexURL.path) {
        let previous = try JSONDecoder().decode(SourceReportIndex.self, from: Data(contentsOf: indexURL))
        guard previous.version == 1, previous.mode == mode.rawValue,
              previous.sourceManifest == manifestURL.path, previous.sourceManifestSHA256 == manifestDigest else {
            throw Failure("Progressive staging requires the same mode and unchanged source manifest; use a fresh staging directory or reimport the complete manifest after a configuration change")
        }
        indexEntries = previous.entries
    }
    var frameCount = 0, fitLimited = 0, upscaled = 0
    for entry in entries {
        let reportName = "reports/\(entry.skin)-\(entry.state)-import.json"
        var options: [String: String] = [
            "--mode": mode.rawValue, "--output-dir": output.appendingPathComponent(entry.skin).path,
            "--states": entry.state, "--columns": String(entry.columns ?? 2), "--rows": String(entry.rows ?? 2),
            "--frame-count": String(entry.frames?.count ?? ((entry.columns ?? 2) * (entry.rows ?? 2))),
            "--single-state-grid": "true", "--report": output.appendingPathComponent(reportName).path,
            "--background": entry.background ?? values["--background"] ?? manifest.background ?? "auto",
            "--neutral-floor": values["--neutral-floor"] ?? String(manifest.neutralFloor ?? 160),
            "--neutral-spread": values["--neutral-spread"] ?? String(manifest.neutralSpread ?? 36),
            "--scale-policy": entry.scalePolicy ?? values["--scale-policy"] ?? manifest.scalePolicy
                ?? (mode == .highres1024 ? "no-upscale" : "fit"),
        ]
        if let limit = entry.artLimit { options["--state-limits"] = "\(entry.state):\(limit)" }
        if let scale = entry.sourceScale { options["--source-scale"] = String(scale) }
        if entry.keepMainBody == true { options["--keep-main-body-states"] = entry.state }
        if let preserve = entry.preserveAltitude { options["--pose-exceptions"] = preserve ? entry.state : "" }
        if values["--previews"] != "false" {
            options["--preview"] = output.appendingPathComponent("contact-sheets/\(entry.skin)-\(entry.state).png").path
        }
        let report: ImportReport
        if let frames = entry.frames {
            report = try importSheet(options, separateFrames: frames.map { resolveSourcePath($0, manifestURL: manifestURL) })
        } else {
            options["--sheet"] = resolveSourcePath(entry.sheet!, manifestURL: manifestURL).path
            report = try importSheet(options)
        }
        frameCount += report.metrics.count
        fitLimited += report.cells.filter(\.nativeFitLimited).count
        upscaled += report.cells.filter(\.upscalesSource).count
        indexEntries.removeAll { $0.skin == entry.skin && $0.state == entry.state }
        indexEntries.append(SourceReportIndexEntry(skin: entry.skin, state: entry.state, report: reportName))
    }
    let manifestOrder = Dictionary(uniqueKeysWithValues: manifest.entries.enumerated().map { ($0.element.key, $0.offset) })
    indexEntries.sort { (manifestOrder["\($0.skin)/\($0.state)"] ?? Int.max) < (manifestOrder["\($1.skin)/\($1.state)"] ?? Int.max) }
    let index = SourceReportIndex(version: 1, mode: mode.rawValue, sourceManifest: manifestURL.path,
        sourceManifestSHA256: manifestDigest, entries: indexEntries)
    try writeJSON(index, indexURL)
    print("Imported \(entries.count) source groups / \(frameCount) frames; upscaled \(upscaled); native-fit limited \(fitLimited). Index tracks \(indexEntries.count) groups. Staged only; installation requires final art review.")
    return index
}

// A contact sheet is QA compositing, not new character artwork.
func contactSheet(rows: [[URL]], labels: [String], destination: URL, mode: ImportMode = .pixel64) throws {
    let cell = 280, labelWidth = 148, rowHeight = 300
    let width = labelWidth + (rows.map(\.count).max() ?? 0) * cell, height = rows.count * rowHeight
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    let context = NSGraphicsContext.current!
    context.imageInterpolation = .none
    NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    for (row, urls) in rows.enumerated() {
        let baseY = height - (row + 1) * rowHeight
        (labels[row] as NSString).draw(at: NSPoint(x: 14, y: baseY + 142), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.white])
        for (column, url) in urls.enumerated() {
            let baseX = labelWidth + column * cell + 12
            for y in stride(from: 0, to: 256, by: 16) {
                for x in stride(from: 0, to: 256, by: 16) {
                    NSColor(calibratedWhite: (x / 16 + y / 16).isMultiple(of: 2) ? 0.30 : 0.35, alpha: 1).setFill()
                    NSRect(x: baseX + x, y: baseY + 32 + y, width: 16, height: 16).fill()
                }
            }
            let frame: NSImage
            if mode.isHighResolution {
                let resized = resizedPremultiplied(try Raster.read(url), width: 256, height: 256)
                guard let cg = try resized.bitmapRepresentation().cgImage else { throw Failure("Cannot render contact frame") }
                frame = NSImage(cgImage: cg, size: NSSize(width: 256, height: 256))
            } else {
                guard let original = NSImage(contentsOf: url) else { throw Failure("Missing contact frame: \(url.path)") }
                frame = original
            }
            frame.draw(in: NSRect(x: baseX, y: baseY + 32, width: 256, height: 256))
            (url.lastPathComponent as NSString).draw(at: NSPoint(x: baseX + 8, y: baseY + 8), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor.white])
        }
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else { throw Failure("Cannot encode contact sheet") }
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: destination, options: .atomic)
}

struct LoopMetrics: Codable {
    let skin: String
    let state: String
    let frameCount: Int
    let distinctFrames: Int
    let poseException: Bool
    let baselineRange: [Int]
    let widthRange: [Int]
    let heightRange: [Int]
    let centroidXRange: [Double]
    let centroidYRange: [Double]
    let relativeAreaRange: Double
    let warnings: [String]
}

func intRange(_ values: [Int]) -> [Int] { values.isEmpty ? [] : [values.min()!, values.max()!] }
func doubleRange(_ values: [Double]) -> [Double] { values.isEmpty ? [] : [values.min()!, values.max()!] }

func loopMetrics(skin: String, state: String, frames: [FrameMetrics]) -> LoopMetrics {
    let boxes = frames.compactMap(\.alphaBounds)
    let baseline = intRange(boxes.map(\.bottom))
    let areas = frames.map(\.opaquePixels)
    let areaRange = areas.isEmpty || areas.max() == 0 ? 0 : Double(areas.max()! - areas.min()!) / Double(areas.max()!)
    let exception = ["jump", "dragging"].contains(state)
    let distinct = Set(frames.map(\.rgbaSHA256)).count
    var warnings: [String] = []
    if distinct < frames.count { warnings.append("duplicateWholeFrames") }
    if !exception && baseline.count == 2 && baseline[1] - baseline[0] > 2 { warnings.append("groundedBaselineRangeAbove2px") }
    if !exception && areaRange > 0.15 { warnings.append("opaqueAreaRangeAbove15Percent") }
    return LoopMetrics(skin: skin, state: state, frameCount: frames.count, distinctFrames: distinct,
        poseException: exception, baselineRange: baseline, widthRange: intRange(boxes.map(\.width)),
        heightRange: intRange(boxes.map(\.height)), centroidXRange: doubleRange(frames.compactMap(\.centroidX)),
        centroidYRange: doubleRange(frames.compactMap(\.centroidY)), relativeAreaRange: areaRange, warnings: warnings)
}

struct ImportedFrameEvidence: Decodable {
    let file: String
    let rgbaSHA256: String
}

struct SourceImportEvidence: Decodable {
    let mode: String
    let sourceScalePolicy: String?
    let sourceEnclosedBrightPixelsLost: Int?
    let sources: [SourceRecord]?
    let cells: [SourceScaleEvidence]?
    let metrics: [ImportedFrameEvidence]
    let valid: Bool
}

struct SourceScaleEvidence: Decodable {
    let sourceToOutputScale: Double
    let upscalesSource: Bool?
    let nativeFitLimited: Bool?
}

struct SourceProtectionAudit: Encodable {
    let status: String
    let reportDirectory: String
    let expectedReports: Int
    let checkedReports: Int
    let verifiedOutputFrames: Int
    let verifiedSourceFiles: Int
    let sourceToOutputScaleRange: [Double]
    let upscaledSourceFrames: Int
    let nativeFitLimitedFrames: Int
    let sourceEnclosedBrightPixelsLost: Int?
    let issues: [String]
}

func sourceProtectionAudit(directory: URL, explicitlyRequired: Bool, skins: [String],
                           includeEffects: Bool, mode: ImportMode,
                           frames: [String: FrameMetrics]) -> SourceProtectionAudit {
    var expected = skins.flatMap { skin in ["a", "b", "c", "d"].map { (skin, "\(skin)-\($0)-import.json") } }
    if includeEffects { expected.append(("effects", "effects-punch-import.json")) }
    var indexIssues: [String] = []
    let indexURL = directory.appendingPathComponent("source-import-index.json")
    let hasIndex = FileManager.default.fileExists(atPath: indexURL.path)
    if hasIndex {
        do {
            let index = try JSONDecoder().decode(SourceReportIndex.self, from: Data(contentsOf: indexURL))
            if index.version != 1 || index.mode != mode.rawValue { indexIssues.append("Source index version/mode mismatch") }
            let uniqueKeys = Set(index.entries.map { "\($0.skin)/\($0.state)" })
            if uniqueKeys.count != index.entries.count { indexIssues.append("Source index contains duplicate state groups") }
            let filtered = index.entries.filter { skins.contains($0.skin) || ($0.skin == "effects" && includeEffects) }
            expected = filtered.map { ($0.skin, $0.report) }
            if expected.contains(where: { $0.1.hasPrefix("/") || $0.1.split(separator: "/").contains("..") }) {
                indexIssues.append("Source index report paths must stay inside the report directory")
                expected = []
            }
            let data = try Data(contentsOf: URL(fileURLWithPath: index.sourceManifest))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if digest != index.sourceManifestSHA256 { indexIssues.append("Source manifest changed after import") }
        } catch {
            indexIssues.append("Cannot verify source import index: \(error.localizedDescription)")
        }
    }
    let exists = expected.contains { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.1).path) }
    guard mode.isHighResolution && (exists || explicitlyRequired || hasIndex || !indexIssues.isEmpty) else {
        return SourceProtectionAudit(status: mode.isHighResolution ? "unavailable" : "not-required-for-pixel64",
            reportDirectory: directory.path, expectedReports: expected.count, checkedReports: 0,
            verifiedOutputFrames: 0, verifiedSourceFiles: 0, sourceToOutputScaleRange: [],
            upscaledSourceFrames: 0, nativeFitLimitedFrames: 0,
            sourceEnclosedBrightPixelsLost: nil, issues: [])
    }
    var checked = 0, lost = 0, verified: Set<String> = [], verifiedSources: Set<String> = []
    var issues = indexIssues
    var scales: [Double] = [], upscaled = 0, fitLimited = 0
    for (skin, name) in expected {
        let reportURL = directory.appendingPathComponent(name)
        do {
            let evidence = try JSONDecoder().decode(SourceImportEvidence.self, from: Data(contentsOf: reportURL))
            checked += 1
            if evidence.mode != mode.rawValue { issues.append("\(name): import mode mismatch") }
            if !evidence.valid { issues.append("\(name): import report is invalid") }
            if let count = evidence.sourceEnclosedBrightPixelsLost {
                lost += count
                if count != 0 { issues.append("\(name): lost \(count) protected white source pixels") }
            } else { issues.append("\(name): missing protected-white source evidence") }
            if mode == .highres1024 && (evidence.sources == nil || evidence.cells == nil) {
                issues.append("\(name): missing native source/scale evidence for1024 mode")
            }
            for source in evidence.sources ?? [] where !verifiedSources.contains(source.file) {
                let data = try Data(contentsOf: URL(fileURLWithPath: source.file))
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                if digest != source.sha256 { issues.append("\(name): source file changed after import: \(source.file)") }
                else { verifiedSources.insert(source.file) }
                if mode == .highres1024 && (source.isolatedMeaningfulEdgeContacts?.values.contains(where: { $0 > 0 }) ?? false) {
                    issues.append("\(name): source has meaningful canvas-edge contact: \(source.file)")
                }
                if let chroma = source.chromaMagenta, !chroma.issues.isEmpty || chroma.unresolvedCandidatePixels > 0 {
                    issues.append("\(name): unresolved chroma isolation: \(source.file)")
                }
            }
            for cell in evidence.cells ?? [] {
                scales.append(cell.sourceToOutputScale)
                if cell.sourceToOutputScale <= 0 { issues.append("\(name): invalid nonpositive source scale") }
                if cell.sourceToOutputScale > 1 { upscaled += 1 }
                if evidence.sourceScalePolicy == "no-upscale" && cell.sourceToOutputScale > 1 {
                    issues.append("\(name): no-upscale policy was violated")
                }
                if cell.nativeFitLimited == true { fitLimited += 1 }
                if let flag = cell.upscalesSource, flag != (cell.sourceToOutputScale > 1) {
                    issues.append("\(name): inconsistent source-upscale evidence")
                }
            }
            for frame in evidence.metrics {
                let key = "\(skin)/\(URL(fileURLWithPath: frame.file).lastPathComponent)"
                guard let actual = frames[key] else { issues.append("\(name): missing audited output \(key)"); continue }
                if actual.rgbaSHA256 != frame.rgbaSHA256 { issues.append("\(name): output digest mismatch for \(key)") }
                else { verified.insert(key) }
            }
        } catch { issues.append("\(name): cannot read complete import evidence (\(error.localizedDescription))") }
    }
    for key in frames.keys.sorted() where !verified.contains(key) {
        issues.append("No matching import evidence for \(key)")
    }
    return SourceProtectionAudit(status: issues.isEmpty ? "passed" : "failed", reportDirectory: directory.path,
        expectedReports: expected.count, checkedReports: checked, verifiedOutputFrames: verified.count,
        verifiedSourceFiles: verifiedSources.count, sourceToOutputScaleRange: doubleRange(scales),
        upscaledSourceFrames: upscaled, nativeFitLimitedFrames: fitLimited,
        sourceEnclosedBrightPixelsLost: lost, issues: issues)
}

struct AuditReport: Encodable {
    let schemaVersion = 1
    let mode: String
    let outputCanvasSize: Int
    let displayHeight: Int
    let sprites: String
    let manifest: String
    let manifestStates: [String]
    let framesPerState: [String: Int]
    let framesPerStateBySkin: [String: [String: Int]]
    let displayHeightsBySkin: [String: Int]
    let skins: [String]
    let expectedCharacterFrames: Int
    let actualCharacterFrames: Int
    let countsBySkin: [String: Int]
    let expectedEffectFrames: Int
    let actualEffectFrames: Int
    let missingFiles: [String]
    let unexpectedCharacterFiles: [String]
    let unexpectedEffectFiles: [String]
    let issueCounts: [String: Int]
    let effectIssueCounts: [String: Int]
    let frames: [FrameMetrics]
    let loops: [LoopMetrics]
    let effects: [FrameMetrics]
    let effectLoop: LoopMetrics?
    let silhouetteMismatchPixels: [String: Int]
    let sourceProtection: SourceProtectionAudit
    let charactersValid: Bool
    let effectsValid: Bool
    let valid: Bool
    let note = "Pixel QA is strict; pose/area/duplicate observations are separate warnings. Source protection checks import evidence and exact output hashes when reports are available; unavailable evidence does not certify white-fur preservation. Effects are separate from the manifest character count. Visual outline quality still requires reviewing the contact sheet."
}

func audit(_ values: [String: String]) throws {
    let mode = try importMode(values)
    let root = URL(fileURLWithPath: try required("--sprites", values), isDirectory: true)
    let manifestURL = URL(fileURLWithPath: values["--manifest"] ?? root.appendingPathComponent("manifest.json").path)
    let manifest = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: manifestURL))
    let skins = (values["--skins"] ?? "default,black,calico,orange,pink").split(separator: ",").map(String.init)
    let stateOrder = ["idle", "hover", "click", "coding", "typing", "thinking", "lunch", "yawn", "nap", "success", "error", "dragging", "walk", "jump"]
    let states = stateOrder.filter { manifest[$0] != nil } + manifest.keys.filter { !stateOrder.contains($0) }.sorted()
    var frames: [FrameMetrics] = [], effects: [FrameMetrics] = [], loops: [LoopMetrics] = []
    var counts: [String: Int] = [:], missing: [String] = [], unexpected: [String] = []
    var framesPerStateBySkin: [String: [String: Int]] = [:]
    var displayHeightsBySkin: [String: Int] = [:]
    var expected = 0
    var canonicalAlpha: [String: [UInt8]] = [:], silhouettes: [String: Int] = [:]
    var evidenceFrames: [String: FrameMetrics] = [:]
    let fm = FileManager.default
    for skin in skins {
        let nested = root.appendingPathComponent(skin, isDirectory: true)
        let directory = skin == "default" && !fm.fileExists(atPath: nested.path) ? root : nested
        let localManifestURL = directory.appendingPathComponent("manifest.json")
        let skinManifest = fm.fileExists(atPath: localManifestURL.path)
            ? try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: localManifestURL))
            : manifest
        let skinStates = stateOrder.filter { skinManifest[$0] != nil }
            + skinManifest.keys.filter { !stateOrder.contains($0) }.sorted()
        let names = Set(skinManifest.values.flatMap { $0 })
        expected += names.count
        framesPerStateBySkin[skin] = skinManifest.mapValues(\.count)
        let infoURL = directory.appendingPathComponent("render-info.json")
        let info = (try? Data(contentsOf: infoURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        displayHeightsBySkin[skin] = info?["displayHeight"] as? Int ?? mode.displayHeight
        let pngs = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension.lowercased() == "png" }
        counts[skin] = pngs.count
        unexpected += pngs.filter { !names.contains($0.lastPathComponent) }.map(\.path)
        for state in skinStates {
            var group: [FrameMetrics] = []
            for name in skinManifest[state]! {
                let url = directory.appendingPathComponent(name)
                if !fm.fileExists(atPath: url.path) { missing.append(url.path); continue }
                let raster = try Raster.read(url)
                let metric = try inspect(raster, file: url, mode: mode)
                frames.append(metric); group.append(metric)
                evidenceFrames["\(skin)/\(name)"] = metric
                let alpha = stride(from: 3, to: raster.bytes.count, by: 4).map { raster.bytes[$0] }
                if skin == "default" { canonicalAlpha[name] = alpha }
                else if let reference = canonicalAlpha[name] {
                    silhouettes["\(skin)/\(name)"] = reference.count == alpha.count
                        ? zip(reference, alpha).filter { $0 != $1 }.count : max(reference.count, alpha.count)
                }
            }
            loops.append(loopMetrics(skin: skin, state: state, frames: group))
        }
    }
    let effectsDirectory = URL(fileURLWithPath: values["--effects-dir"] ?? root.appendingPathComponent("effects").path)
    let includeEffects = values["--effects"] != "false"
    var actualEffects = 0
    var unexpectedEffects: [String] = []
    if includeEffects {
        let effectPNGs = ((try? fm.contentsOfDirectory(at: effectsDirectory, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension.lowercased() == "png" }
        actualEffects = effectPNGs.count
        let expectedNames = Set((0..<4).map { "nyang_punch_\($0).png" })
        unexpectedEffects = effectPNGs.filter { !expectedNames.contains($0.lastPathComponent) }.map(\.path)
        for i in 0..<4 {
            let url = effectsDirectory.appendingPathComponent("nyang_punch_\(i).png")
            if !fm.fileExists(atPath: url.path) { missing.append(url.path); continue }
            let metric = try inspect(Raster.read(url), file: url, mode: mode)
            effects.append(metric)
            evidenceFrames["effects/\(url.lastPathComponent)"] = metric
        }
    }
    var issues: [String: Int] = [:]
    for metric in frames { for issue in metric.issues { issues[issue, default: 0] += 1 } }
    var effectIssues: [String: Int] = [:]
    for metric in effects { for issue in metric.issues { effectIssues[issue, default: 0] += 1 } }
    let charactersValid = unexpected.isEmpty && issues.isEmpty && frames.count == expected
    let effectsValid = !includeEffects || (actualEffects == 4 && effects.count == 4 && unexpectedEffects.isEmpty && effectIssues.isEmpty)
    let sourceProtection = sourceProtectionAudit(
        directory: URL(fileURLWithPath: values["--source-reports"] ?? root.path, isDirectory: true),
        explicitlyRequired: values["--source-reports"] != nil, skins: skins,
        includeEffects: includeEffects, mode: mode, frames: evidenceFrames)
    let report = AuditReport(mode: mode.rawValue, outputCanvasSize: mode.canvasSize, displayHeight: mode.displayHeight,
        sprites: root.path, manifest: manifestURL.path, manifestStates: states,
        framesPerState: manifest.mapValues(\.count), framesPerStateBySkin: framesPerStateBySkin,
        displayHeightsBySkin: displayHeightsBySkin, skins: skins, expectedCharacterFrames: expected,
        actualCharacterFrames: counts.values.reduce(0, +), countsBySkin: counts,
        expectedEffectFrames: includeEffects ? 4 : 0, actualEffectFrames: actualEffects,
        missingFiles: missing, unexpectedCharacterFiles: unexpected.sorted(), unexpectedEffectFiles: unexpectedEffects.sorted(),
        issueCounts: issues, effectIssueCounts: effectIssues, frames: frames, loops: loops, effects: effects,
        effectLoop: includeEffects ? loopMetrics(skin: "effects", state: "nyang_punch", frames: effects) : nil,
        silhouetteMismatchPixels: silhouettes, sourceProtection: sourceProtection,
        charactersValid: charactersValid, effectsValid: effectsValid,
        valid: missing.isEmpty && charactersValid && effectsValid && sourceProtection.status != "failed")
    let reportURL = URL(fileURLWithPath: try required("--report", values))
    try writeJSON(report, reportURL)
    print("Character frames \(report.actualCharacterFrames)/\(expected); effects \(actualEffects)/\(report.expectedEffectFrames); bundle QA \(report.valid ? "PASS" : "FAIL"); source protection \(sourceProtection.status); report: \(reportURL.path)")
    if !report.valid { throw Failure("Audit found \(issues.values.reduce(0, +)) character pixel issues, \(effectIssues.values.reduce(0, +)) effect pixel issues, \(sourceProtection.issues.count) source-evidence issues, and \(missing.count) missing files") }
}

func preview(_ values: [String: String]) throws {
    let directory = URL(fileURLWithPath: try required("--sprites", values), isDirectory: true)
    let states = try required("--states", values).split(separator: ",").map(String.init)
    let frameCount = Int(values["--frame-count"] ?? "4") ?? 0
    guard [4, 8].contains(frameCount) else { throw Failure("--frame-count must be 4 or 8") }
    let rows = states.map { state in (0..<frameCount).map { directory.appendingPathComponent("\(state)_\($0).png") } }
    try contactSheet(rows: rows, labels: states, destination: URL(fileURLWithPath: try required("--output", values)), mode: try importMode(values))
}

struct RenderInfo: Encodable {
    let version = 1
    let canvasHeight: Int
    let bottomInset: Int
    let dragTopInset: Int?
    let displayHeight: Int?
    let filtering: String?
    let punchFacing: String?
    init(mode: ImportMode, dragTopInset: Int? = nil, punchFacing: String? = nil, displayHeight: Int = 128) {
        canvasHeight = mode.canvasSize
        bottomInset = mode.padding
        self.dragTopInset = dragTopInset
        self.displayHeight = mode.isHighResolution ? displayHeight : nil
        filtering = mode.isHighResolution ? "linear" : nil
        self.punchFacing = punchFacing
    }
}

func metadata(_ values: [String: String]) throws {
    let mode = try importMode(values)
    let allowPartial = values["--allow-partial"] == "true"
    let displayHeight = Int(values["--display-height"] ?? "128") ?? 0
    guard (32...512).contains(displayHeight) else { throw Failure("--display-height must be between 32 and 512 points") }
    let root = URL(fileURLWithPath: try required("--sprites", values), isDirectory: true)
    let skins = (values["--skins"] ?? "default,black,calico,orange,pink").split(separator: ",").map(String.init)
    let manifestURL = URL(fileURLWithPath: try required("--manifest", values))
    let manifest = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: manifestURL))
    for skin in skins {
        let directory = root.appendingPathComponent(skin, isDirectory: true)
        let localManifestURL = directory.appendingPathComponent("manifest.json")
        let skinManifest = FileManager.default.fileExists(atPath: localManifestURL.path)
            ? try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: localManifestURL))
            : manifest
        var insets: Set<Int> = [], dragTop: [Int] = []
        for (state, names) in skinManifest {
            for name in names {
                let file = directory.appendingPathComponent(name)
                if allowPartial && !FileManager.default.fileExists(atPath: file.path) { continue }
                let image = try Raster.read(file)
                guard image.width == mode.canvasSize, image.height == mode.canvasSize, let box = bounds(image) else {
                    throw Failure("Invalid frame for runtime metadata: \(skin)/\(name)")
                }
                if !["jump", "dragging"].contains(state) { insets.insert(image.height - box.bottom) }
                if state == "dragging" { dragTop.append(box.y) }
            }
        }
        guard insets == [mode.padding], allowPartial || !dragTop.isEmpty else {
            throw Failure("Runtime metadata needs a stable \(mode.padding)px grounded inset and dragging bounds: \(skin) has \(insets.sorted())")
        }
        let top = dragTop.min()
        try writeJSON(RenderInfo(mode: mode, dragTopInset: top, displayHeight: displayHeight), directory.appendingPathComponent("render-info.json"))
        print("\(skin): canvas \(mode.canvasSize), display \(displayHeight), bottomInset \(mode.padding), measured dragTopInset \(top.map(String.init) ?? "not available in partial import")")
    }
}

func effectMetadata(_ values: [String: String]) throws {
    let mode = try importMode(values)
    let punchFacing = values["--punch-facing"]
    guard punchFacing == nil || ["left", "right"].contains(punchFacing!) else {
        throw Failure("--punch-facing must be left or right")
    }
    let directory = URL(fileURLWithPath: try required("--sprites", values), isDirectory: true)
    for frame in 0..<4 {
        let url = directory.appendingPathComponent("nyang_punch_\(frame).png")
        let image = try Raster.read(url)
        let metric = try inspect(image, file: url, mode: mode)
        guard metric.issues.isEmpty, metric.alphaBounds?.bottom == mode.canvasSize - mode.padding else {
            throw Failure("Effect metadata needs passing pixel QA and an actual \(mode.padding)px bottom inset: \(url.path)")
        }
    }
    try writeJSON(RenderInfo(mode: mode, punchFacing: punchFacing), directory.appendingPathComponent("render-info.json"))
    print("effects: canvas \(mode.canvasSize), display 128, bottomInset \(mode.padding) measured across all four frames")
}

func backgroundPreview(_ values: [String: String]) throws {
    let mode = try importMode(values)
    let root = URL(fileURLWithPath: try required("--sprites", values), isDirectory: true)
    let output = URL(fileURLWithPath: try required("--output-dir", values), isDirectory: true)
    let skins = (values["--skins"] ?? "default,black,calico,orange,pink").split(separator: ",").map(String.init)
    let names = (values["--samples"] ?? "idle_0,click_0,nap_0,dragging_0,walk_1,jump_2").split(separator: ",").map(String.init)
    let backgrounds: [(String, NSColor, NSColor)] = [
        ("light", NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1), .black),
        ("dark", NSColor(calibratedRed: 0.045, green: 0.055, blue: 0.085, alpha: 1), .white),
        ("blue", NSColor(calibratedRed: 0.30, green: 0.47, blue: 0.77, alpha: 1), .white),
    ]
    let selectedBackgrounds = (values["--backgrounds"] ?? "light,dark,blue").split(separator: ",").map(String.init)
    let sizes = (values["--sizes"] ?? "128,256").split(separator: ",").compactMap { Int($0) }
    guard !sizes.isEmpty, sizes.allSatisfy({ $0 > 0 && $0 <= 1024 }) else { throw Failure("Preview sizes must be1...1024") }
    var previewCount = 0
    for size in sizes {
        let cellWidth = size + 24, rowHeight = size + 40, labelWidth = 120, titleHeight = 48
        let width = labelWidth + cellWidth * names.count, height = titleHeight + rowHeight * skins.count
        for (name, fill, textColor) in backgrounds where selectedBackgrounds.contains(name) {
            let image = NSImage(size: NSSize(width: width, height: height))
            image.lockFocus()
            NSGraphicsContext.current!.imageInterpolation = .none
            fill.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
            let samplingName = mode.isHighResolution ? "premultiplied bilinear sampling" : "nearest sampling"
            ("Actual \(size)×\(size) pixels · \(name) background · \(samplingName)" as NSString).draw(at: NSPoint(x: 14, y: height - 32), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .medium), .foregroundColor: textColor])
            for (row, skin) in skins.enumerated() {
                let baseY = height - titleHeight - (row + 1) * rowHeight
                (skin as NSString).draw(at: NSPoint(x: 14, y: baseY + rowHeight / 2), withAttributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .medium), .foregroundColor: textColor])
                for (column, sample) in names.enumerated() {
                    let url = root.appendingPathComponent(skin).appendingPathComponent(sample + ".png")
                    let frame: NSImage
                    if mode.isHighResolution {
                        let scaled = resizedPremultiplied(try Raster.read(url), width: size, height: size)
                        guard let cg = try scaled.bitmapRepresentation().cgImage else { throw Failure("Cannot render preview frame") }
                        frame = NSImage(cgImage: cg, size: NSSize(width: size, height: size))
                    } else {
                        guard let original = NSImage(contentsOf: url) else { throw Failure("Missing preview frame: \(url.path)") }
                        frame = original
                    }
                    let x = labelWidth + column * cellWidth
                    frame.draw(in: NSRect(x: x, y: baseY + 28, width: size, height: size))
                    (sample as NSString).draw(at: NSPoint(x: x + 4, y: baseY + 7), withAttributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: textColor])
                }
            }
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else { throw Failure("Cannot encode background preview") }
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try data.write(to: output.appendingPathComponent("background-\(name)-\(size).png"), options: .atomic)
            previewCount += 1
        }
    }
    print("Wrote \(previewCount) background previews using \(mode.resampling)")
}

func selfTest() throws {
    func expect(_ condition: Bool, _ message: String) throws { if !condition { throw Failure("Self-test failed: \(message)") } }
    var image = Raster(width: 32, height: 32, bytes: Array(repeating: 255, count: 32 * 32 * 4))
    for y in 6..<26 {
        for x in 8..<24 where y == 6 || y == 25 || x == 8 || x == 23 {
            let o = image.offset(x, y)
            image.bytes[o] = 20; image.bytes[o + 1] = 24; image.bytes[o + 2] = 32
        }
    }
    let (cleared, removed) = clearNeutralEdge(image)
    try expect(removed == 32 * 32 - 16 * 20, "only edge-connected background should be removed")
    try expect(cleared.bytes[cleared.offset(16, 16) + 3] == 255, "enclosed white fur must survive")
    try expect(cleared.bytes[0..<4].allSatisfy { $0 == 0 }, "removed pixels must have zero RGBA")
    let refined = clearNeutralEdge(image, floor: 160, spread: 36).0
    try expect(refined.bytes[refined.offset(16, 16) + 3] == 255, "refined neutral-edge extraction must preserve enclosed white fur")
    var weakGap = image
    for channel in 0..<3 { weakGap.bytes[weakGap.offset(16, 6) + channel] = 180 }
    let protectedBase = clearNeutralEdge(weakGap).0
    let bounded = clearBoundedNeutralFringe(weakGap, conservative: protectedBase, floor: 160, spread: 36)
    try expect(clearNeutralEdge(weakGap, floor: 160, spread: 36).0.bytes[weakGap.offset(16, 16) + 3] == 0,
               "weak-gap fixture must reproduce the old unrestricted belly-hole failure")
    for o in stride(from: 0, to: protectedBase.bytes.count, by: 4) where protectedBase.bytes[o + 3] > 0 {
        if protectedBase.bytes[o..<o + 3].allSatisfy({ $0 == 255 }) {
            try expect(bounded.bytes[o + 3] == 255, "bounded refinement must retain every protected white body pixel")
        }
    }
    var chromaFixture = Raster(width: 48, height: 48)
    let matteRGB = [243, 5, 246], outlineRGB = [45, 30, 25]
    func paintFixturePixel(_ raster: inout Raster, x: Int, y: Int, rgb: [Int], alpha: UInt8 = 255) {
        let o = raster.offset(x, y)
        for channel in 0..<3 { raster.bytes[o + channel] = UInt8(rgb[channel]) }
        raster.bytes[o + 3] = alpha
    }
    for y in 0..<48 { for x in 0..<48 { paintFixturePixel(&chromaFixture, x: x, y: y, rgb: matteRGB) } }
    for y in 8..<40 {
        for x in 10..<38 {
            let outline = x == 10 || x == 37 || y == 8 || y == 39
            paintFixturePixel(&chromaFixture, x: x, y: y, rgb: outline ? outlineRGB : [253, 253, 249])
        }
    }
    let palette = [[245, 140, 160], [255, 180, 150], [80, 150, 30], [253, 253, 249]]
    for (index, rgb) in palette.enumerated() { paintFixturePixel(&chromaFixture, x: 14 + index * 6, y: 15, rgb: rgb) }
    for y in 24..<31 { for x in 28..<34 { paintFixturePixel(&chromaFixture, x: x, y: y, rgb: matteRGB) } }
    let (keyedFixture, keyEvidence) = clearChromaMagenta(chromaFixture)
    try expect(keyEvidence.keyPixelsRemoved == 48 * 48 - 28 * 32 + 42 && keyEvidence.enclosedKeyPixelsRemoved == 42,
               "explicit magenta extraction must remove both exterior matte and a fully enclosed hole")
    try expect(keyEvidence.issues.isEmpty && keyEvidence.measuredKeyColorRGB == matteRGB,
               "measured non-exact magenta must key without uncertain foreground")
    for (index, rgb) in palette.enumerated() {
        let o = keyedFixture.offset(14 + index * 6, 15)
        try expect(Array(keyedFixture.bytes[o..<o + 4]) == rgb.map { UInt8($0) } + [255],
                   "pink ears, peach cheeks, green eyes and white coat must retain exact source RGBA")
    }
    try expect(Array(keyedFixture.bytes[keyedFixture.offset(10, 20)..<keyedFixture.offset(10, 20) + 4]) == [45, 30, 25, 255],
               "intact dark outline pixels must not be desaturated or recolored")
    var fringeFixture = chromaFixture
    for (row, coverage) in [(16, 0.5), (17, 0.35), (18, 0.12)] {
        let composite = (0..<3).map { Int((Double(outlineRGB[$0]) * coverage + Double(matteRGB[$0]) * (1 - coverage)).rounded()) }
        paintFixturePixel(&fringeFixture, x: 9, y: row, rgb: composite)
    }
    let (unmixedFixture, fringeEvidence) = clearChromaMagenta(fringeFixture)
    try expect(fringeEvidence.issues.isEmpty && fringeEvidence.decontaminatedEdgePixels == 2
        && fringeEvidence.lowCoverageSpillPixelsRemoved == 1, "bounded matting must retain real coverage and remove only a low-coverage key trace")
    for (row, expectedAlpha) in [(16, 128), (17, 89)] {
        let o = unmixedFixture.offset(9, row)
        try expect((0..<3).allSatisfy { abs(Int(unmixedFixture.bytes[o + $0]) - outlineRGB[$0]) <= 2 }
            && abs(Int(unmixedFixture.bytes[o + 3]) - expectedAlpha) <= 1,
            "known magenta/outline mixtures must recover source ink color and soft alpha without a magenta halo")
    }
    var zeroGreenFixture = chromaFixture
    paintFixturePixel(&zeroGreenFixture, x: 10, y: 16, rgb: [0, 0, 0])
    paintFixturePixel(&zeroGreenFixture, x: 9, y: 16, rgb: [49, 0, 49])
    let (projectedBlack, zeroGreenEvidence) = clearChromaMagenta(zeroGreenFixture)
    let blackOffset = projectedBlack.offset(9, 16)
    try expect(zeroGreenEvidence.issues.isEmpty && zeroGreenEvidence.projectedGreenEdgePixels == 1
        && zeroGreenEvidence.maximumReconstructionError <= 1.1
        && (0..<3).allSatisfy { projectedBlack.bytes[blackOffset + $0] <= 1 }
        && abs(Int(projectedBlack.bytes[blackOffset + 3]) - 204) <= 1,
        "a clipped source green channel may project to physical zero only with a measured small recomposition residual")
    var cornerNoiseFixture = chromaFixture
    for (x, y, rgb) in [(0, 0, [234, 25, 223]), (47, 0, [229, 40, 218]), (47, 47, [231, 37, 223])] {
        paintFixturePixel(&cornerNoiseFixture, x: x, y: y, rgb: rgb)
    }
    let (cleanCorners, cornerEvidence) = clearChromaMagenta(cornerNoiseFixture)
    try expect(cornerEvidence.isolatedKeyOutliersRemoved == 3 && cornerEvidence.issues.isEmpty
        && edgeContacts(cleanCorners).values.allSatisfy { $0 == 0 },
        "isolated near-key corner noise surrounded entirely by actual key must not imply clipped anatomy")
    var connectedSpillFixture = chromaFixture
    for y in 19...23 { for x in 10...28 { paintFixturePixel(&connectedSpillFixture, x: x, y: y, rgb: outlineRGB) } }
    let halfMix = (0..<3).map { Int((Double(outlineRGB[$0] + matteRGB[$0]) / 2).rounded()) }
    for x in 10..<20 { paintFixturePixel(&connectedSpillFixture, x: x, y: 21, rgb: halfMix) }
    let (cleanSpill, connectedEvidence) = clearChromaMagenta(connectedSpillFixture)
    try expect(connectedEvidence.issues.isEmpty && connectedEvidence.decontaminatedEdgePixels == 10
        && abs(Int(cleanSpill.bytes[cleanSpill.offset(19, 21) + 3]) - 128) <= 1,
        "a connected ten-pixel dark matte intrusion must use existing outline and retain recovered coverage")
    var lightPatchFixture = connectedSpillFixture
    for x in 10..<20 { paintFixturePixel(&lightPatchFixture, x: x, y: 21, rgb: [206, 138, 197]) }
    let (protectedPatch, lightPatchEvidence) = clearChromaMagenta(lightPatchFixture)
    let patchOffset = lightPatchFixture.offset(19, 21)
    try expect((lightPatchEvidence.unresolvedReasons["unsupportedLightChromaPatch"] ?? 0) > 0
        && lightPatchFixture.bytes[patchOffset..<patchOffset + 4].elementsEqual(protectedPatch.bytes[patchOffset..<patchOffset + 4]),
        "light lavender/checker fragments beyond the initial boundary must fail and remain unchanged")
    var deepSpillFixture = connectedSpillFixture
    for x in 20..<27 { paintFixturePixel(&deepSpillFixture, x: x, y: 21, rgb: halfMix) }
    let (protectedDeepSpill, deepEvidence) = clearChromaMagenta(deepSpillFixture)
    let deepOffset = deepSpillFixture.offset(26, 21)
    try expect((deepEvidence.unresolvedReasons["outsideConnectedMatteBand"] ?? 0) > 0
        && deepSpillFixture.bytes[deepOffset..<deepOffset + 4].elementsEqual(protectedDeepSpill.bytes[deepOffset..<deepOffset + 4]),
        "a matte intrusion deeper than twelve source pixels must fail without extending the edit band")
    var ambiguousFixture = chromaFixture
    paintFixturePixel(&ambiguousFixture, x: 18, y: 20, rgb: [150, 50, 145])
    let (unmodifiedAmbiguity, ambiguityEvidence) = clearChromaMagenta(ambiguousFixture)
    let ambiguousOffset = ambiguousFixture.offset(18, 20)
    try expect(ambiguityEvidence.unresolvedCandidatePixels == 1 && !ambiguityEvidence.issues.isEmpty
        && ambiguousFixture.bytes[ambiguousOffset..<ambiguousOffset + 4].elementsEqual(unmodifiedAmbiguity.bytes[ambiguousOffset..<ambiguousOffset + 4]),
        "out-of-band uncertain foreground must fail and remain unchanged, never be repainted")
    var nativeChromaFixture = Raster(width: 16, height: 16)
    paintFixturePixel(&nativeChromaFixture, x: 8, y: 8, rgb: [200, 80, 180], alpha: 128)
    paintFixturePixel(&nativeChromaFixture, x: 1, y: 1, rgb: [255, 0, 255], alpha: 1)
    let (nativePassthrough, nativeChromaEvidence) = clearChromaMagenta(nativeChromaFixture)
    try expect(nativePassthrough.bytes == nativeChromaFixture.bytes && nativeChromaEvidence.nativeAlphaPassthrough
        && nativeChromaEvidence.keyPixelsRemoved == 0 && nativeChromaEvidence.issues.isEmpty,
        "native alpha including colored trace pixels must take precedence and pass through unchanged")
    let opaqueWithoutKey = Raster(width: 8, height: 8, bytes: Array(repeating: 255, count: 8 * 8 * 4))
    try expect(clearChromaMagenta(opaqueWithoutKey).1.issues == ["noMagentaKeyInOpaqueSource"],
               "opaque checker/white sources without the reserved key must be rejected")
    let (trimmedPixelPatch, pixelPatchEvidence) = clearChromaMagenta(lightPatchFixture, trimReservedPixelFringe: true)
    try expect(pixelPatchEvidence.issues.isEmpty && (pixelPatchEvidence.reservedFringePixelsRemoved ?? 0) > 0
        && (pixelPatchEvidence.maximumReservedFringeDistance ?? 99) <= 16
        && trimmedPixelPatch.bytes[patchOffset + 3] == 0,
        "explicit pixel policy must trim unsupported reserved hue only inside the measured spatial boundary")
    let (pixelPalette, pixelPaletteEvidence) = clearChromaMagenta(chromaFixture, trimReservedPixelFringe: true)
    try expect(pixelPaletteEvidence.issues.isEmpty && pixelPalette.bytes == keyedFixture.bytes,
        "pixel fringe policy must preserve pink ears, peach cheeks, green eyes, white coat and intact outline exactly")
    let (pixelNative, pixelNativeEvidence) = clearChromaMagenta(nativeChromaFixture, trimReservedPixelFringe: true)
    try expect(pixelNative.bytes == nativeChromaFixture.bytes && pixelNativeEvidence.nativeAlphaPassthrough,
        "explicit pixel fringe policy must never reinterpret existing native alpha")
    var distantPixelFixture = Raster(width: 80, height: 80)
    for y in 0..<80 { for x in 0..<80 {
        paintFixturePixel(&distantPixelFixture, x: x, y: y,
            rgb: (8..<72).contains(x) && (8..<72).contains(y) ? outlineRGB : matteRGB)
    } }
    paintFixturePixel(&distantPixelFixture, x: 40, y: 40, rgb: [206, 138, 197])
    let (protectedPixelInterior, distantPixelEvidence) = clearChromaMagenta(distantPixelFixture, trimReservedPixelFringe: true)
    let distantOffset = distantPixelFixture.offset(40, 40)
    try expect(distantPixelEvidence.interiorHueCandidatesPreserved == 1 && distantPixelEvidence.issues.isEmpty
        && distantPixelFixture.bytes[distantOffset..<distantOffset + 4].elementsEqual(protectedPixelInterior.bytes[distantOffset..<distantOffset + 4]),
        "pixel fringe policy must preserve and record interior low-chroma colors without altering the foreground")
    var protectedBrightFixture = chromaFixture
    paintFixturePixel(&protectedBrightFixture, x: 10, y: 20, rgb: [255, 237, 253])
    let (pixelBright, pixelBrightEvidence) = clearChromaMagenta(protectedBrightFixture, trimReservedPixelFringe: true)
    let brightOffset = pixelBright.offset(10, 20)
    try expect(pixelBrightEvidence.issues.isEmpty
        && Array(pixelBright.bytes[brightOffset..<brightOffset + 4]) == [255, 237, 253, 255],
        "pixel fringe keying must preserve neutral bright fur even at the character boundary")
    var variableMatteFixture = chromaFixture
    for y in 0..<48 { for x in 0..<48 where chromaFixture.bytes[chromaFixture.offset(x, y)] == UInt8(matteRGB[0]) {
        paintFixturePixel(&variableMatteFixture, x: x, y: y, rgb: [220, 22, 212])
    } }
    let (pixelVariableMatte, variableMatteEvidence) = clearChromaMagenta(variableMatteFixture, trimReservedPixelFringe: true)
    try expect(variableMatteEvidence.issues.isEmpty && pixelVariableMatte.bytes == keyedFixture.bytes,
        "pixel keying must remove darker generated magenta without treating background variation as character fringe")
    let cuts = try gutterCuts(length: 120, count: 2) { (65..<75).contains($0) }
    try expect(cuts == [0, 70, 120], "off-center grid cuts must use transparent gutter center")
    do {
        _ = try gutterCuts(length: 120, count: 2) { _ in false }
        throw Failure("Self-test failed: a missing gutter must fail instead of clipping")
    } catch let error as Failure {
        try expect(error.description.contains("No transparent gutter"), "missing gutters must be explicit failures")
    }
    var diagonal = Raster(width: 3, height: 3)
    diagonal.bytes[3] = 255; diagonal.bytes[diagonal.offset(1, 1) + 3] = 255
    try expect(components(diagonal).count == 1, "diagonal outline pixels use 8-connectivity")
    let (rendered, _) = renderLogical(cleared, content: bounds(cleared)!, scale: 52.0 / 20, baseline: 58)
    let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("openneko-sprite-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: testRoot) }
    let chromaFixtureURL = testRoot.appendingPathComponent("synthetic-magenta.png")
    try chromaFixture.write(chromaFixtureURL)
    let chromaSourceData = try Data(contentsOf: chromaFixtureURL)
    let autoChroma = try prepareSource(chromaFixtureURL, mode: .highres1024, background: "auto", neutralFloor: 160, neutralSpread: 36)
    try expect(autoChroma.normalized.bytes == chromaFixture.bytes && autoChroma.record.chromaMagenta == nil,
               "auto mode must never silently key a magenta source")
    let explicitChroma = try prepareSource(chromaFixtureURL, mode: .highres1024, background: "chroma-magenta", neutralFloor: 160, neutralSpread: 36)
    try expect(explicitChroma.normalized.bytes == keyedFixture.bytes && explicitChroma.record.chromaMagenta?.enclosedKeyPixelsRemoved == 42
        && (try Data(contentsOf: chromaFixtureURL)) == chromaSourceData,
        "explicit chroma mode must expose isolation evidence and leave native source bytes unchanged")
    let file = testRoot.appendingPathComponent("fixture.png")
    try rendered.write(file)
    let roundTrip = try Raster.read(file)
    let metric = try inspect(roundTrip, file: file)
    try expect(metric.issues.isEmpty, "RGBA round-trip, binary alpha, lattice, padding and debris invariants")
    try expect(metric.alphaBounds?.bottom == 116, "ground baseline must leave exactly 12px bottom inset")
    try expect(roundTrip.bytes == rendered.bytes, "PNG round trip must preserve exact RGBA bytes")
    var translucent = cleared
    let o = translucent.offset(16, 16)
    translucent.bytes[o + 3] = 100
    let (binary, _) = renderLogical(translucent, content: bounds(translucent)!, scale: 2, baseline: 58)
    try expect(stride(from: 3, to: binary.bytes.count, by: 4).allSatisfy { [0, 255].contains(binary.bytes[$0]) }, "partial input alpha must be thresholded")
    let sharedScale = 52.0 / 20
    let (raised, _) = renderLogical(cleared, content: bounds(cleared)!, scale: sharedScale, baseline: 54)
    try expect(bounds(raised)?.bottom == 108, "explicit floating baseline must be preserved")
    var atlas = Raster(width: 200, height: 200)
    for frame in 0..<4 {
        let startX = (frame % 2) * 100 + 30, startY = (frame / 2) * 100 + 30
        for y in startY..<startY + 26 {
            for x in startX..<startX + 22 + frame * 4 {
                let o = atlas.offset(x, y)
                atlas.bytes[o] = UInt8(100 + frame * 30)
                atlas.bytes[o + 1] = 60; atlas.bytes[o + 2] = 30; atlas.bytes[o + 3] = 255
            }
        }
    }
    let atlasURL = testRoot.appendingPathComponent("single-state-atlas.png")
    let atlasReport = testRoot.appendingPathComponent("single-state-report.json")
    let atlasOutput = testRoot.appendingPathComponent("single-state")
    try atlas.write(atlasURL)
    try importSheet(["--sheet": atlasURL.path, "--output-dir": atlasOutput.path,
        "--mode": "pixel64",
        "--states": "nyang_punch", "--columns": "2", "--rows": "2", "--single-state-grid": "true",
        "--report": atlasReport.path])
    let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: atlasReport)) as! [String: Any]
    let cells = payload["cells"] as! [[String: Any]]
    try expect(cells.count == 4, "single-state grid must import all four cells")
    try expect(Set(cells.map { $0["logicalScale"] as! Double }).count == 1, "single-state cells must share one scale")
    for frame in 0..<4 {
        try expect(FileManager.default.fileExists(atPath: atlasOutput.appendingPathComponent("nyang_punch_\(frame).png").path), "single-state output must be row-major")
    }
    let edge = Raster(width: 2, height: 1, bytes: [255, 0, 0, 255, 0, 0, 255, 0])
    try expect(samplePremultiplied(edge, x: 0.5, y: 0) == [255, 0, 0, 128], "transparent blue must not tint a resampled red edge")
    let soft = Raster(width: 1, height: 1, bytes: [80, 170, 230, 128])
    try expect(samplePremultiplied(soft, x: 0, y: 0) == soft.bytes, "native partial alpha and straight RGB must survive identity sampling")
    let invisible = Raster(width: 2, height: 1, bytes: [255, 0, 0, 0, 0, 255, 0, 0])
    try expect(samplePremultiplied(invisible, x: 0.5, y: 0) == [0, 0, 0, 0], "fully transparent samples must produce zero RGB")
    var traceFixture = Raster(width: 5, height: 3)
    traceFixture.bytes[traceFixture.offset(0, 0) + 3] = 255
    traceFixture.bytes[traceFixture.offset(1, 0) + 3] = 1
    traceFixture.bytes[traceFixture.offset(4, 2) + 3] = 9
    let (traceCleaned, traceCount, traceComponents, traceMaximum) = removeUnanchoredTraceAlpha(traceFixture)
    try expect(traceCount == 1 && traceComponents == 1 && traceMaximum == 9, "only disconnected trace components should be discarded")
    try expect(traceCleaned.bytes[traceFixture.offset(1, 0) + 3] == 1, "a native soft-edge alpha1 pixel connected to the sprite must survive")
    var edgeFixture = Raster(width: 3, height: 3)
    edgeFixture.bytes[edgeFixture.offset(1, 1) + 3] = 255
    edgeFixture.bytes[edgeFixture.offset(1, 0) + 3] = 1
    try expect(permitsTraceOnlyEdgeContact(edgeFixture, mode: .highres1024), "native1024 may pad a connected alpha1 edge trace")
    try expect(!permitsTraceOnlyEdgeContact(edgeFixture, mode: .highres), "legacy256 edge policy remains unchanged")
    edgeFixture.bytes[edgeFixture.offset(1, 0) + 3] = 16
    try expect(!permitsTraceOnlyEdgeContact(edgeFixture, mode: .highres1024), "meaningful clipped edge content must be rejected")
    let quarterEdge = samplePremultiplied(edge, x: 0.25, y: 0)
    try expect(quarterEdge == [255, 0, 0, 191], "partial edge coverage must keep its full red color instead of a dark halo")
    let highresScale = samplingScale(mode: .highres, artLimit: 208, width: 16, height: 20)
    let (highres, _) = renderHighResolution(translucent, content: bounds(translucent)!, scale: highresScale,
                                           baseline: 232, alignsGround: true)
    let highresURL = testRoot.appendingPathComponent("highres-soft-alpha.png")
    try highres.write(highresURL)
    let highresRoundTrip = try Raster.read(highresURL)
    let highresMetric = try inspect(highresRoundTrip, file: highresURL, mode: .highres)
    try expect(highresMetric.issues.isEmpty && highresMetric.alphaBounds?.bottom == 232, "highres padding and measured baseline must pass")
    try expect(highresMetric.nonbinaryAlphaPixels > 0 && highresMetric.latticeMismatches > 0,
               "highres QA must allow soft alpha and individual source pixels")
    try expect(highresRoundTrip.bytes == highres.bytes, "soft-alpha PNG round trip must preserve straight RGBA")
    let sourceEvidenceRoot = testRoot.appendingPathComponent("source-evidence")
    try FileManager.default.createDirectory(at: sourceEvidenceRoot, withIntermediateDirectories: true)
    func fixtureEvidence(_ sheet: String, lost: Int = 0, digest: String? = nil) throws {
        let importedFrames: [[String: String]] = sheet == "a"
            ? [["file": highresURL.path, "rgbaSHA256": digest ?? highresMetric.rgbaSHA256]] : []
        let evidence: [String: Any] = ["mode": "highres", "valid": true,
            "sourceEnclosedBrightPixelsLost": lost, "metrics": importedFrames]
        try JSONSerialization.data(withJSONObject: evidence).write(to:
            sourceEvidenceRoot.appendingPathComponent("default-\(sheet)-import.json"))
    }
    for sheet in ["a", "b", "c", "d"] { try fixtureEvidence(sheet) }
    func checkEvidence() -> SourceProtectionAudit {
        sourceProtectionAudit(directory: sourceEvidenceRoot, explicitlyRequired: true,
            skins: ["default"], includeEffects: false, mode: .highres,
            frames: ["default/\(highresURL.lastPathComponent)": highresMetric])
    }
    try expect(checkEvidence().status == "passed", "complete zero-loss evidence must verify current output hashes")
    try fixtureEvidence("a", lost: 1)
    try expect(checkEvidence().status == "failed", "a white-body source hole must fail even when output pixel QA passes")
    try fixtureEvidence("a", digest: "stale-digest")
    try expect(checkEvidence().status == "failed", "stale source evidence must not certify changed output bytes")
    try fixtureEvidence("a")
    try FileManager.default.removeItem(at: sourceEvidenceRoot.appendingPathComponent("default-d-import.json"))
    try expect(checkEvidence().status == "failed", "missing required source evidence must fail")

    try expect(ImportMode.highres1024.canvasSize == 1024 && ImportMode.highres1024.padding == 96
        && ImportMode.highres1024.baseline == 928 && ImportMode.highres1024.maximumArtSpan == 832
        && ImportMode.highres1024.jumpArtSpan == 800, "1024 profile geometry must scale proportionally")
    try expect(try resolvedScale(mode: .highres1024, requested: 4, policy: "no-upscale") == 1,
               "1024 output must not enlarge a small source under its default policy")
    do {
        _ = try resolvedScale(mode: .highres1024, requested: 1.01, policy: "require-native-fit")
        throw Failure("Self-test failed: insufficient native detail was accepted")
    } catch let error as Failure {
        try expect(error.description.contains("too small"), "native-fit rejection must explain the source-size shortfall")
    }
    let nativeSourceRoot = testRoot.appendingPathComponent("native-sources")
    let nativeOutput = testRoot.appendingPathComponent("native-output")
    var nativePaths: [URL] = []
    for frame in 0..<4 {
        // Rectangular test fixtures only: native generator canvas dimensions vary
        // independently of artwork size. These are never production cat assets.
        var native = Raster(width: 1223 + frame * 3, height: 1286 + frame * 7)
        let x = 150, y = 120 + frame * 4
        for row in y..<y + 1000 - frame * 8 {
            for col in x..<x + 900 + frame * 12 {
                let o = native.offset(col, row)
                native.bytes[o] = UInt8(90 + frame * 20)
                native.bytes[o + 1] = 120; native.bytes[o + 2] = 200
                native.bytes[o + 3] = col == x ? 128 : 255
            }
        }
        let url = nativeSourceRoot.appendingPathComponent("native-\(frame).png")
        try native.write(url); nativePaths.append(url)
    }
    let nativeManifestURL = nativeSourceRoot.appendingPathComponent("sources.json")
    let nativeManifest: [String: Any] = ["version": 1, "mode": "highres1024", "entries": [
        ["skin": "default", "state": "idle", "frames": nativePaths.map(\.lastPathComponent)],
        ["skin": "effects", "state": "nyang_punch", "sheet": atlasURL.path, "columns": 2, "rows": 2],
    ]]
    try JSONSerialization.data(withJSONObject: nativeManifest).write(to: nativeManifestURL)
    let firstNativeIndex = try importManifest(["--source-manifest": nativeManifestURL.path,
        "--output-dir": nativeOutput.path, "--only": "default/idle", "--previews": "false"])
    try expect(firstNativeIndex.entries.count == 1, "a selected source group must create a partial index")
    let nativeIndex = try importManifest(["--source-manifest": nativeManifestURL.path,
        "--output-dir": nativeOutput.path, "--only": "effects/nyang_punch", "--append": "true", "--previews": "false"])
    try expect(nativeIndex.entries.count == 2, "mixed native-frame and sheet manifests must index both groups")
    var nativeMetrics: [String: FrameMetrics] = [:]
    for entry in nativeIndex.entries {
        for frame in 0..<4 {
            let name = "\(entry.state)_\(frame).png"
            let url = nativeOutput.appendingPathComponent(entry.skin).appendingPathComponent(name)
            let raster = try Raster.read(url)
            let metric = try inspect(raster, file: url, mode: .highres1024)
            try expect(metric.width == 1024 && metric.height == 1024 && metric.issues.isEmpty
                && metric.alphaBounds?.bottom == 928, "native1024 PNGs must keep the96px grounded inset")
            nativeMetrics["\(entry.skin)/\(name)"] = metric
        }
    }
    let nativeReportData = try Data(contentsOf: nativeOutput.appendingPathComponent("reports/default-idle-import.json"))
    let nativeReportJSON = try JSONSerialization.jsonObject(with: nativeReportData) as! [String: Any]
    let nativeCells = nativeReportJSON["cells"] as! [[String: Any]]
    try expect(Set(nativeCells.map { $0["sourceToOutputScale"] as! Double }).count == 1,
               "separate native state frames must use one shared scale")
    try expect(nativeCells.allSatisfy { ($0["sourceToOutputScale"] as! Double) < 1 },
               "large native fixtures must be downsampled without enlargement")
    try expect((nativeCells.first!["sourceCanvasOffsetY"] as! Int) == 21
        && (nativeCells.last!["sourceCanvasOffsetY"] as! Int) == 0,
        "unequal native canvases must align by translation instead of source resampling")
    func checkNativeEvidence() -> SourceProtectionAudit {
        sourceProtectionAudit(directory: nativeOutput, explicitlyRequired: true, skins: ["default"],
            includeEffects: true, mode: .highres1024, frames: nativeMetrics)
    }
    let nativeProtection = checkNativeEvidence()
    try expect(nativeProtection.status == "passed" && nativeProtection.expectedReports == 2
        && nativeProtection.verifiedOutputFrames == 8 && nativeProtection.verifiedSourceFiles == 5
        && nativeProtection.upscaledSourceFrames == 0 && nativeProtection.nativeFitLimitedFrames == 4,
        "manifest audit must verify native sources and report preserved-size small sheet cells honestly")
    let nativeManifestOriginalData = try Data(contentsOf: nativeManifestURL)
    var changedManifest = nativeManifestOriginalData; changedManifest.append(32)
    try changedManifest.write(to: nativeManifestURL)
    do {
        _ = try importManifest(["--source-manifest": nativeManifestURL.path, "--output-dir": nativeOutput.path,
            "--only": "effects/nyang_punch", "--append": "true", "--previews": "false"])
        throw Failure("Self-test failed: changed source manifest was appended")
    } catch let error as Failure {
        try expect(error.description.contains("unchanged source manifest"), "progressive staging must reject a changed manifest")
    }
    try nativeManifestOriginalData.write(to: nativeManifestURL)
    let nativeOriginalData = try Data(contentsOf: nativePaths[0])
    var changedSource = nativeOriginalData; changedSource.append(0)
    try changedSource.write(to: nativePaths[0])
    try expect(checkNativeEvidence().status == "failed", "source file changes after import must invalidate native provenance")
    try nativeOriginalData.write(to: nativePaths[0])
    let runtimeManifestURL = testRoot.appendingPathComponent("native-runtime-manifest.json")
    try writeJSON(["idle": (0..<4).map { "idle_\($0).png" }], runtimeManifestURL)
    try metadata(["--mode": "highres1024", "--skins": "default", "--sprites": nativeOutput.path,
        "--manifest": runtimeManifestURL.path, "--allow-partial": "true"])
    try effectMetadata(["--mode": "highres1024", "--sprites": nativeOutput.appendingPathComponent("effects").path])
    let effectInfoURL = nativeOutput.appendingPathComponent("effects/render-info.json")
    let legacyEffectInfo = try JSONSerialization.jsonObject(with: Data(contentsOf: effectInfoURL)) as! [String: Any]
    try expect(legacyEffectInfo["punchFacing"] == nil, "unspecified effect facing must preserve legacy playback")
    try effectMetadata(["--mode": "highres1024", "--sprites": nativeOutput.appendingPathComponent("effects").path,
        "--punch-facing": "right"])
    let rightFacingEffectInfo = try JSONSerialization.jsonObject(with: Data(contentsOf: effectInfoURL)) as! [String: Any]
    try expect(rightFacingEffectInfo["punchFacing"] as? String == "right", "effect metadata must retain explicit artwork facing")
    do {
        try effectMetadata(["--mode": "highres1024", "--sprites": nativeOutput.appendingPathComponent("effects").path,
            "--punch-facing": "up"])
        throw Failure("Self-test failed: invalid effect facing was accepted")
    } catch let error as Failure {
        try expect(error.description.contains("must be left or right"), "invalid effect facing must fail before metadata is written")
    }
    let runtimeInfo = try JSONSerialization.jsonObject(with: Data(contentsOf:
        nativeOutput.appendingPathComponent("default/render-info.json"))) as! [String: Any]
    try expect((runtimeInfo["canvasHeight"] as! Int) == 1024 && (runtimeInfo["bottomInset"] as! Int) == 96
        && (runtimeInfo["displayHeight"] as! Int) == 128 && (runtimeInfo["filtering"] as! String) == "linear",
        "1024 artwork must remain a128-point runtime canvas with linear filtering")
    let jumpSource = try Raster.read(nativePaths[0])
    let jumpBounds = bounds(jumpSource)!
    let jumpScale = samplingScale(mode: .highres1024, artLimit: 800, width: jumpBounds.width, height: jumpBounds.height)
    let (jump1024, _) = renderHighResolution(jumpSource, content: jumpBounds, scale: jumpScale,
        baseline: 928, alignsGround: false, canvasSize: 1024)
    try expect(bounds(jump1024)!.y >= 128, "1024 jump sprites must reserve headroom for runtime lift")

    // New frames may extend a loop without changing the established scale of
    // its approved anchors. Four-frame coats must still audit independently.
    var eightNativePaths = nativePaths
    for frame in 4..<8 {
        var fixture = try Raster.read(nativePaths[frame - 4])
        fixture.bytes[fixture.offset(200, 200)] = UInt8(10 + frame)
        let url = nativeSourceRoot.appendingPathComponent("native-\(frame).png")
        try fixture.write(url); eightNativePaths.append(url)
    }
    let fixedFourOutput = testRoot.appendingPathComponent("fixed-four")
    let fixedFour = try importSheet(["--mode": "highres1024", "--states": "idle",
        "--output-dir": fixedFourOutput.path, "--source-scale": "0.5",
        "--scale-policy": "require-native-fit"], separateFrames: nativePaths)
    let mixedOutput = testRoot.appendingPathComponent("mixed-eight-four")
    let mixedManifestURL = nativeSourceRoot.appendingPathComponent("mixed-eight-sources.json")
    let mixedManifest: [String: Any] = ["version": 1, "mode": "highres1024",
        "scalePolicy": "require-native-fit", "entries": [
            ["skin": "default", "state": "idle", "frames": eightNativePaths.map(\.lastPathComponent), "sourceScale": 0.5],
            ["skin": "black", "state": "idle", "frames": nativePaths.map(\.lastPathComponent), "sourceScale": 0.5],
        ]]
    try JSONSerialization.data(withJSONObject: mixedManifest).write(to: mixedManifestURL)
    _ = try importManifest(["--source-manifest": mixedManifestURL.path,
        "--output-dir": mixedOutput.path, "--previews": "false"])
    let mixedReport = try JSONSerialization.jsonObject(with: Data(contentsOf:
        mixedOutput.appendingPathComponent("reports/default-idle-import.json"))) as! [String: Any]
    let mixedCells = mixedReport["cells"] as! [[String: Any]]
    try expect(mixedCells.count == 8 && mixedCells.allSatisfy { ($0["sourceToOutputScale"] as! Double) == 0.5 },
               "all eight frames must retain the requested shared source scale")
    for frame in 0..<4 {
        let enlargedLoopAnchor = try Raster.read(mixedOutput.appendingPathComponent("default/idle_\(frame).png"))
        let approvedAnchor = try Raster.read(fixedFourOutput.appendingPathComponent("idle_\(frame).png"))
        try expect(enlargedLoopAnchor.bytes == approvedAnchor.bytes,
                   "adding animation phases must not resize or alter approved anchors")
    }
    try expect(fixedFour.cells.allSatisfy { !$0.nativeFitLimited && !$0.upscalesSource },
               "an intentional smaller source scale is not a native-fit shortfall")
    let mixedRuntimeManifest = mixedOutput.appendingPathComponent("manifest.json")
    try writeJSON(["idle": (0..<8).map { "idle_\($0).png" }], mixedRuntimeManifest)
    try writeJSON(["idle": (0..<4).map { "idle_\($0).png" }], mixedOutput.appendingPathComponent("black/manifest.json"))
    try metadata(["--mode": "highres1024", "--skins": "default", "--sprites": mixedOutput.path,
        "--manifest": mixedRuntimeManifest.path, "--display-height": "160", "--allow-partial": "true"])
    try metadata(["--mode": "highres1024", "--skins": "black", "--sprites": mixedOutput.path,
        "--manifest": mixedRuntimeManifest.path, "--allow-partial": "true"])
    let mixedAuditURL = testRoot.appendingPathComponent("mixed-eight-audit.json")
    try audit(["--mode": "highres1024", "--sprites": mixedOutput.path,
        "--skins": "default,black", "--effects": "false", "--source-reports": mixedOutput.path,
        "--report": mixedAuditURL.path])
    let mixedAudit = try JSONSerialization.jsonObject(with: Data(contentsOf: mixedAuditURL)) as! [String: Any]
    let mixedCounts = mixedAudit["framesPerStateBySkin"] as! [String: [String: Int]]
    let mixedHeights = mixedAudit["displayHeightsBySkin"] as! [String: Int]
    try expect((mixedAudit["valid"] as! Bool) && (mixedAudit["expectedCharacterFrames"] as! Int) == 12
        && mixedCounts["default"]?["idle"] == 8 && mixedCounts["black"]?["idle"] == 4
        && mixedHeights["default"] == 160 && mixedHeights["black"] == 128,
        "mixed coats must use their own frame manifests and display heights")
    for invalidScale in ["0", "-1", "nan", "2"] {
        do {
            _ = try importSheet(["--mode": "highres1024", "--states": "idle",
                "--output-dir": testRoot.appendingPathComponent("invalid-fixed-scale").path,
                "--source-scale": invalidScale], separateFrames: eightNativePaths)
            throw Failure("Self-test failed: invalid fixed source scale was accepted")
        } catch let error as Failure {
            try expect(error.description.contains("source-scale") || error.description.contains("Fixed source scale"),
                       "unsafe fixed scales must fail before writing frames")
        }
    }
    print("PASS: eight-frame native imports, fixed-scale anchor preservation, mixed per-skin manifests, 160/128 metadata and invalid-scale rejection")
    print("PASS: bounded white-fur protection, weak outline gaps, explicit magenta/enclosed-hole isolation, exact palette preservation, bounded chroma unmix, uncertain-source rejection, native-alpha passthrough, legacy pixel64/highres256, native soft alpha, clipped-edge rejection, 1024 geometry, shared state scale, unequal native canvases, no-upscale policy, progressive mixed source manifests, source/output provenance, metadata and jump headroom")
}

let usage = """
Mechanical sprite import/QA (Swift + AppKit; no image generation/recoloring):
  swift scripts/sprite-production.swift import-manifest --source-manifest SOURCES.json --output-dir STAGED_ROOT
  swift scripts/sprite-production.swift source-info --mode highres1024 --sheet SOURCE.png --report SOURCE_INFO.json
  swift scripts/sprite-production.swift import --sheet SHEET.png --output-dir DIR --states idle,hover,click,coding --columns 4 --rows 4 --report REPORT.json --preview PREVIEW.png
  swift scripts/sprite-production.swift audit --sprites App/Resources/sprites --report REPORT.json
  swift scripts/sprite-production.swift preview --sprites DIR --states idle,hover,click,coding --output PREVIEW.png
  swift scripts/sprite-production.swift background-preview --sprites STAGED_ROOT --output-dir PREVIEW_DIR
  swift scripts/sprite-production.swift metadata --sprites STAGED_ROOT --manifest App/Resources/sprites/manifest.json
  swift scripts/sprite-production.swift effect-metadata --sprites STAGED_ROOT/effects [--punch-facing left|right]
  swift scripts/sprite-production.swift self-test
Optional import options:
  --mode highres1024|highres|pixel64         1024px/256px/128px outputs, default display 128 points
  --scale-policy no-upscale|require-native-fit|fit  highres1024 defaults to no-upscale; older modes to fit
  --background auto|alpha|neutral-edge|chroma-magenta|chroma-magenta-pixel  magenta keying is explicit; pixel adds bounded reserved-hue trim
  --neutral-floor 160 --neutral-spread 36    highres bounded fringe after conservative 220/18 flood; depth 2
  --state-limits idle:832,jump:800           1024 art spans; highres256 uses208/200, pixel64 uses52/50 logical
  --frame-count 4|8                         complete state length; inferred for separate native frames
  --frame-start 1                           preserve a single review frame's intended index
  --source-scale 0.5                        fixed source-to-output ratio, bounded by artLimit and scale policy
  --pose-exceptions jump,dragging             preserve source relative altitude for these states
  --keep-main-body-states nap,success         explicitly remove detached source marks (counted in report)
  --single-state-grid true                   use one state across every cell in row-major order
With fewer --states than --rows, only the first named rows are imported.
Manifest defaults to highres1024 and accepts four or eight native frame paths or sheet cells per skin/state.
An entry's sourceScale fixes its established source-to-output ratio while adding phases.
Manifest options: --only default/idle,calico/idle --append true --previews false.
Append preserves earlier groups only when the source manifest and mode are unchanged.
Audit and metadata prefer each skin's own manifest over the common fallback. Optional: --manifest PATH --skins default,black --effects false.
Metadata accepts --display-height 160 for an explicit display size; source canvas and insets stay in pixels.
Use --source-reports STAGING_DIR to require source white-fur evidence, native source hashes, and exact output hashes.
High-resolution modes preserve soft alpha and use premultiplied bilinear sampling. Pixel64 is explicit legacy compatibility.
Compile once for batch imports: swiftc -O -module-cache-path /tmp/openneko-sprite-module-cache scripts/sprite-production.swift -o /tmp/openneko-sprite-production
"""

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else { print(usage); exit(0) }
    let values = try options(Array(args.dropFirst()))
    switch command {
    case "import": try importSheet(values)
    case "import-manifest": try importManifest(values)
    case "source-info": try sourceInfo(values)
    case "audit": try audit(values)
    case "preview": try preview(values)
    case "background-preview": try backgroundPreview(values)
    case "metadata": try metadata(values)
    case "effect-metadata": try effectMetadata(values)
    case "self-test": try selfTest()
    case "help", "--help": print(usage)
    default: throw Failure("Unknown command: \(command)\n\(usage)")
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
