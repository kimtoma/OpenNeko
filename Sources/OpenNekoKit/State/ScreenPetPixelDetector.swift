import CoreGraphics
import Foundation

public struct ScreenPetPixel: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public enum ScreenPetPixelDetector {
    public static let minimumBluePixelCount = 900

    public static func candidates(
        imageWidth: Int,
        imageHeight: Int,
        imageFrame: CGRect,
        pixelsPerPoint: CGFloat = 1,
        excludedFrames: [CGRect] = [],
        pixelAt: (Int, Int) -> ScreenPetPixel
    ) -> [ScreenPetCandidate] {
        guard imageWidth > 0, imageHeight > 0, pixelsPerPoint > 0 else { return [] }

        var visited = Array(repeating: false, count: imageWidth * imageHeight)
        var candidates: [(candidate: ScreenPetCandidate, pixelCount: Int)] = []

        for y in 0..<imageHeight {
            for x in 0..<imageWidth {
                let index = y * imageWidth + x
                guard !visited[index] else { continue }
                visited[index] = true
                guard isCodexPetBlue(pixelAt(x, y)) else { continue }

                let component = collectComponent(
                    startX: x,
                    startY: y,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    visited: &visited,
                    pixelAt: pixelAt
                )
                guard component.pixelCount >= minimumBluePixelCount else { continue }

                let frame = screenFrame(
                    component: component,
                    imageFrame: imageFrame,
                    pixelsPerPoint: pixelsPerPoint
                )
                guard isPixelPetSized(frame), !excludedFrames.contains(where: { $0.intersects(frame) }) else {
                    continue
                }

                let candidate = ScreenPetCandidate(
                    id: "screen-pixels-\(candidates.count)",
                    ownerName: "Screen Capture",
                    windowName: "Codex Pet Pixels",
                    frame: frame
                )
                candidates.append((candidate, component.pixelCount))
            }
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.pixelCount == rhs.pixelCount {
                    return lhs.candidate.frame.minX < rhs.candidate.frame.minX
                }
                return lhs.pixelCount > rhs.pixelCount
            }
            .map(\.candidate)
    }

    public static func isCodexPetBlue(_ pixel: ScreenPetPixel) -> Bool {
        let red = Int(pixel.red)
        let green = Int(pixel.green)
        let blue = Int(pixel.blue)
        let alpha = Int(pixel.alpha)
        return alpha > 80
            && blue >= 120
            && green >= 70
            && red <= 150
            && blue > red + 35
            && blue >= green + 10
    }

    private struct Component {
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
        let pixelCount: Int
    }

    private static func collectComponent(
        startX: Int,
        startY: Int,
        imageWidth: Int,
        imageHeight: Int,
        visited: inout [Bool],
        pixelAt: (Int, Int) -> ScreenPetPixel
    ) -> Component {
        var stack = [(x: startX, y: startY)]
        var minX = startX
        var minY = startY
        var maxX = startX
        var maxY = startY
        var pixelCount = 0

        while let point = stack.popLast() {
            pixelCount += 1
            minX = Swift.min(minX, point.x)
            minY = Swift.min(minY, point.y)
            maxX = Swift.max(maxX, point.x)
            maxY = Swift.max(maxY, point.y)

            for neighbor in [
                (x: point.x + 1, y: point.y),
                (x: point.x - 1, y: point.y),
                (x: point.x, y: point.y + 1),
                (x: point.x, y: point.y - 1)
            ] {
                guard
                    neighbor.x >= 0,
                    neighbor.x < imageWidth,
                    neighbor.y >= 0,
                    neighbor.y < imageHeight
                else {
                    continue
                }

                let index = neighbor.y * imageWidth + neighbor.x
                guard !visited[index] else { continue }
                visited[index] = true
                if isCodexPetBlue(pixelAt(neighbor.x, neighbor.y)) {
                    stack.append(neighbor)
                }
            }
        }

        return Component(minX: minX, minY: minY, maxX: maxX, maxY: maxY, pixelCount: pixelCount)
    }

    private static func screenFrame(
        component: Component,
        imageFrame: CGRect,
        pixelsPerPoint: CGFloat
    ) -> CGRect {
        let x = imageFrame.minX + CGFloat(component.minX) / pixelsPerPoint
        let y = imageFrame.maxY - CGFloat(component.maxY + 1) / pixelsPerPoint
        let width = CGFloat(component.maxX - component.minX + 1) / pixelsPerPoint
        let height = CGFloat(component.maxY - component.minY + 1) / pixelsPerPoint
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func isPixelPetSized(_ frame: CGRect) -> Bool {
        frame.width >= ScreenPetEncounter.minimumPetWindowSide
            && frame.height >= ScreenPetEncounter.minimumPetWindowSide
            && frame.width <= ScreenPetEncounter.maximumPetWindowSide
            && frame.height <= ScreenPetEncounter.maximumPetWindowSide
    }
}
