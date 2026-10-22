import AppKit
import Foundation

public struct SpriteFrameMetrics: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let alphaBounds: CGRect?
    public let minimumPadding: Int
    public let opaquePixelCount: Int
    public let transparentRGBPixelCount: Int
    public let connectedComponentAreas: [Int]
    public let foreheadCyanLuminance: Double
    public let hasAlpha: Bool

    public init(
        width: Int,
        height: Int,
        alphaBounds: CGRect?,
        minimumPadding: Int,
        opaquePixelCount: Int,
        transparentRGBPixelCount: Int,
        connectedComponentAreas: [Int],
        foreheadCyanLuminance: Double,
        hasAlpha: Bool = true
    ) {
        self.width = width
        self.height = height
        self.alphaBounds = alphaBounds
        self.minimumPadding = minimumPadding
        self.opaquePixelCount = opaquePixelCount
        self.transparentRGBPixelCount = transparentRGBPixelCount
        self.connectedComponentAreas = connectedComponentAreas
        self.foreheadCyanLuminance = foreheadCyanLuminance
        self.hasAlpha = hasAlpha
    }
}

public struct SpriteFrameDescriptor: Equatable, Sendable {
    public let skinID: String
    public let state: String
    public let frameIndex: Int
    public let url: URL

    public init(skinID: String, state: String, frameIndex: Int, url: URL) {
        self.skinID = skinID
        self.state = state
        self.frameIndex = frameIndex
        self.url = url
    }
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

public struct SpriteQualityIssue: Equatable, Sendable {
    public let code: SpriteQualityIssueCode
    public let message: String
    public let frame: SpriteFrameDescriptor?

    public init(code: SpriteQualityIssueCode, message: String, frame: SpriteFrameDescriptor? = nil) {
        self.code = code
        self.message = message
        self.frame = frame
    }
}

public struct SpriteQualityReport: Equatable, Sendable {
    public let issues: [SpriteQualityIssue]

    public init(issues: [SpriteQualityIssue]) {
        self.issues = issues
    }

    public var isValid: Bool { issues.isEmpty }
}

public enum SpriteAssetQualityError: Error, Equatable {
    case unreadablePNG(URL)
}

public enum SpriteAssetQuality {
    private static let alphaThreshold = 2
    private static let foreheadRegion = CGRect(x: 38, y: 8, width: 54, height: 52)
    private static let foreheadGlowRegion = CGRect(x: 48, y: 10, width: 32, height: 42)
    private static let requiredSize = 128
    private static let requiredPadding = 12

    public static func inspectPNG(at url: URL) throws -> SpriteFrameMetrics {
        guard let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data) else {
            throw SpriteAssetQualityError.unreadablePNG(url)
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        var occupied = Array(repeating: false, count: width * height)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        var opaquePixelCount = 0
        var transparentRGBPixelCount = 0
        var sigilPixelCount = 0
        var foreheadLightTotal = 0.0
        var samples = Array(repeating: 0, count: max(bitmap.samplesPerPixel, 4))

        for y in 0..<height {
            for x in 0..<width {
                bitmap.getPixel(&samples, atX: x, y: y)
                let red = samples[0]
                let green = samples.count > 1 ? samples[1] : red
                let blue = samples.count > 2 ? samples[2] : red
                let alpha = bitmap.hasAlpha && samples.count > 3 ? samples[3] : 255

                if alpha > alphaThreshold {
                    occupied[y * width + x] = true
                    opaquePixelCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                } else if alpha == 0 && (red > 0 || green > 0 || blue > 0) {
                    transparentRGBPixelCount += 1
                }

                let point = CGPoint(x: x, y: y)
                if foreheadRegion.contains(point), alpha > alphaThreshold {
                    if Double(green) >= Double(red) * 1.3,
                       Double(blue) >= Double(red) * 1.3,
                       min(green, blue) >= 20 {
                        sigilPixelCount += 1
                    }
                }
                if foreheadGlowRegion.contains(point), alpha > alphaThreshold {
                    let cyanEnergy = max(0, Double(min(green, blue)) - Double(red)) / 255.0
                    let warmEnergy: Double
                    if red >= 190, green >= 170, blue < green {
                        warmEnergy = max(0, (Double(red) + Double(green)) / 2 - Double(blue)) / 255.0
                    } else {
                        warmEnergy = 0
                    }
                    foreheadLightTotal += (cyanEnergy + warmEnergy * 0.75) * Double(alpha) / 255.0
                }
            }
        }

        let alphaBounds: CGRect?
        let minimumPadding: Int
        if maxX >= minX, maxY >= minY {
            alphaBounds = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX + 1,
                height: maxY - minY + 1
            )
            minimumPadding = min(minX, minY, width - maxX - 1, height - maxY - 1)
        } else {
            alphaBounds = nil
            minimumPadding = min(width, height)
        }

        return SpriteFrameMetrics(
            width: width,
            height: height,
            alphaBounds: alphaBounds,
            minimumPadding: minimumPadding,
            opaquePixelCount: opaquePixelCount,
            transparentRGBPixelCount: transparentRGBPixelCount,
            connectedComponentAreas: componentAreas(in: occupied, width: width, height: height),
            foreheadCyanLuminance: sigilPixelCount == 0
                ? 0
                : foreheadLightTotal / Double(Int(foreheadGlowRegion.width * foreheadGlowRegion.height)),
            hasAlpha: bitmap.hasAlpha
        )
    }

    public static func validate(frames: [SpriteFrameDescriptor]) -> SpriteQualityReport {
        var issues: [SpriteQualityIssue] = []
        let inspected: [(SpriteFrameDescriptor, SpriteFrameMetrics)] = frames.compactMap { frame in
            do {
                return (frame, try inspectPNG(at: frame.url))
            } catch {
                issues.append(SpriteQualityIssue(code: .unreadablePNG, message: "Cannot read \(frame.url.lastPathComponent)", frame: frame))
                return nil
            }
        }

        for (frame, metrics) in inspected {
            if metrics.width != requiredSize || metrics.height != requiredSize {
                issues.append(SpriteQualityIssue(
                    code: .invalidDimensions,
                    message: "Expected 128x128, got \(metrics.width)x\(metrics.height)",
                    frame: frame
                ))
            }
            if !metrics.hasAlpha {
                issues.append(SpriteQualityIssue(code: .missingAlpha, message: "PNG has no alpha channel", frame: frame))
            }
            if metrics.minimumPadding == 0 {
                issues.append(SpriteQualityIssue(code: .alphaTouchesCanvasEdge, message: "Alpha touches the canvas edge", frame: frame))
            } else if metrics.minimumPadding < requiredPadding {
                issues.append(SpriteQualityIssue(
                    code: .insufficientPadding,
                    message: "Minimum padding is \(metrics.minimumPadding)px; expected at least 12px",
                    frame: frame
                ))
            }
            if metrics.transparentRGBPixelCount > 0 {
                issues.append(SpriteQualityIssue(
                    code: .transparentRGBContamination,
                    message: "\(metrics.transparentRGBPixelCount) transparent pixels contain RGB data",
                    frame: frame
                ))
            }
        }

        let byStateFrame = Dictionary(grouping: frames) { "\($0.state)#\($0.frameIndex)" }
        for group in byStateFrame.values {
            guard let canonical = group.first(where: { $0.skinID == "default" }),
                  let canonicalAlpha = alphaBytes(at: canonical.url)
            else { continue }
            for variant in group where variant.skinID != "default" {
                guard let variantAlpha = alphaBytes(at: variant.url), variantAlpha == canonicalAlpha else {
                    issues.append(SpriteQualityIssue(
                        code: .silhouetteMismatch,
                        message: "Alpha silhouette differs from default",
                        frame: variant
                    ))
                    continue
                }
            }
        }

        for (frame, metrics) in inspected where metrics.foreheadCyanLuminance == 0 {
            issues.append(SpriteQualityIssue(code: .missingAISigil, message: "AI forehead sigil is missing", frame: frame))
        }

        let thinkingGroups = Dictionary(grouping: inspected.filter { $0.0.state == "thinking" }) { $0.0.skinID }
        for (skinID, group) in thinkingGroups {
            let sorted = group.sorted { $0.0.frameIndex < $1.0.frameIndex }
            let values: [Double]
            if sorted.count == 4, let baseline = rgbaBytes(at: sorted[0].0.url) {
                values = sorted.compactMap { item in
                    rgbaBytes(at: item.0.url).map { foreheadDifference(from: baseline, to: $0) }
                }
            } else {
                values = []
            }
            guard values.count == 4,
                  values[1] > 0,
                  values[2] > values[1],
                  values[3] < values[2] else {
                issues.append(SpriteQualityIssue(
                    code: .invalidThinkingSigilSequence,
                    message: "Thinking sigil luminance is invalid for \(skinID): \(values)"
                ))
                continue
            }
        }

        return SpriteQualityReport(issues: issues)
    }

    private static func alphaBytes(at url: URL) -> [UInt8]? {
        rgbaBytes(at: url).map { bytes in
            stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        }
    }

    private static func rgbaBytes(at url: URL) -> [UInt8]? {
        guard let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data) else { return nil }
        var result = Array(repeating: UInt8(0), count: bitmap.pixelsWide * bitmap.pixelsHigh * 4)
        var samples = Array(repeating: 0, count: max(bitmap.samplesPerPixel, 4))
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                bitmap.getPixel(&samples, atX: x, y: y)
                let offset = (y * bitmap.pixelsWide + x) * 4
                result[offset] = UInt8(clamping: samples[0])
                result[offset + 1] = UInt8(clamping: samples.count > 1 ? samples[1] : samples[0])
                result[offset + 2] = UInt8(clamping: samples.count > 2 ? samples[2] : samples[0])
                result[offset + 3] = UInt8(clamping: bitmap.hasAlpha && samples.count > 3 ? samples[3] : 255)
            }
        }
        return result
    }

    private static func foreheadDifference(from baseline: [UInt8], to candidate: [UInt8]) -> Double {
        guard baseline.count == candidate.count else { return 0 }
        var total = 0.0
        var samples = 0
        for y in Int(foreheadGlowRegion.minY)..<Int(foreheadGlowRegion.maxY) {
            for x in Int(foreheadGlowRegion.minX)..<Int(foreheadGlowRegion.maxX) {
                let offset = (y * requiredSize + x) * 4
                for channel in 0..<3 {
                    total += abs(Double(candidate[offset + channel]) - Double(baseline[offset + channel])) / 255.0
                    samples += 1
                }
            }
        }
        return samples == 0 ? 0 : total / Double(samples)
    }

    private static func componentAreas(in occupied: [Bool], width: Int, height: Int) -> [Int] {
        var visited = Array(repeating: false, count: occupied.count)
        var areas: [Int] = []

        for start in occupied.indices where occupied[start] && !visited[start] {
            var stack = [start]
            var area = 0
            visited[start] = true

            while let index = stack.popLast() {
                area += 1
                let x = index % width
                let y = index / width
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < width ? index + 1 : -1,
                    y > 0 ? index - width : -1,
                    y + 1 < height ? index + width : -1,
                ]
                for neighbor in neighbors where neighbor >= 0 && occupied[neighbor] && !visited[neighbor] {
                    visited[neighbor] = true
                    stack.append(neighbor)
                }
            }
            areas.append(area)
        }

        return areas.sorted(by: >)
    }
}
