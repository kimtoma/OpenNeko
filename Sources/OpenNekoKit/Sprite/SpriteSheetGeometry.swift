import CoreGraphics
import Foundation

public enum SpriteSheetGeometry {
    public static func cells(imageSize: CGSize) -> [CGRect] {
        gridCells(imageSize: imageSize, columns: 2, rows: 2)
    }

    public static func gridCells(
        imageSize: CGSize,
        columns: Int,
        rows: Int
    ) -> [CGRect] {
        precondition(columns > 0 && rows > 0)
        let pixelWidth = max(0, Int(imageSize.width.rounded(.down)))
        let pixelHeight = max(0, Int(imageSize.height.rounded(.down)))
        let cellWidth = pixelWidth / columns
        let cellHeight = pixelHeight / rows

        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                CGRect(
                    x: column * cellWidth,
                    y: row * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
            }
        }
    }
}

public enum SpriteBackgroundRemoval {
    public static func clearEdgeConnectedNeutralBackground(
        in image: SpriteRGBAImage
    ) -> SpriteRGBAImage {
        guard image.width > 0, image.height > 0 else { return image }
        var result = image
        var visited = Array(repeating: false, count: image.width * image.height)
        var queue: [Int] = []

        func enqueue(_ index: Int) {
            guard !visited[index], isNeutralBackgroundPixel(image.bytes, pixelIndex: index) else { return }
            visited[index] = true
            queue.append(index)
        }

        for x in 0..<image.width {
            enqueue(x)
            enqueue((image.height - 1) * image.width + x)
        }
        for y in 0..<image.height {
            enqueue(y * image.width)
            enqueue(y * image.width + image.width - 1)
        }

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let x = index % image.width
            let y = index / image.width
            if x > 0 { enqueue(index - 1) }
            if x + 1 < image.width { enqueue(index + 1) }
            if y > 0 { enqueue(index - image.width) }
            if y + 1 < image.height { enqueue(index + image.width) }
        }

        for index in queue {
            let offset = index * 4
            result.bytes[offset] = 0
            result.bytes[offset + 1] = 0
            result.bytes[offset + 2] = 0
            result.bytes[offset + 3] = 0
        }
        return result
    }

    private static func isNeutralBackgroundPixel(_ bytes: [UInt8], pixelIndex: Int) -> Bool {
        let offset = pixelIndex * 4
        guard bytes[offset + 3] > 0 else { return false }
        let red = Int(bytes[offset])
        let green = Int(bytes[offset + 1])
        let blue = Int(bytes[offset + 2])
        return min(red, green, blue) >= 220 && max(red, green, blue) - min(red, green, blue) <= 18
    }
}

public enum SpriteAlphaGeometry {
    public static func contentBounds(
        in image: SpriteRGBAImage,
        nearbyDistance: Int
    ) -> CGRect? {
        var visited = Array(repeating: false, count: image.width * image.height)
        var components: [(area: Int, bounds: CGRect)] = []

        for start in 0..<(image.width * image.height) {
            guard !visited[start], image.bytes[start * 4 + 3] > 2 else { continue }
            var queue = [start]
            var cursor = 0
            var area = 0
            var minX = image.width
            var minY = image.height
            var maxX = -1
            var maxY = -1
            visited[start] = true

            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                area += 1
                let x = index % image.width
                let y = index / image.width
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                let neighbors = [
                    x > 0 ? index - 1 : -1,
                    x + 1 < image.width ? index + 1 : -1,
                    y > 0 ? index - image.width : -1,
                    y + 1 < image.height ? index + image.width : -1,
                ]
                for neighbor in neighbors where neighbor >= 0 && !visited[neighbor] && image.bytes[neighbor * 4 + 3] > 2 {
                    visited[neighbor] = true
                    queue.append(neighbor)
                }
            }
            components.append((
                area,
                CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            ))
        }

        guard let primary = components.max(by: { $0.area < $1.area }) else { return nil }
        return components.reduce(primary.bounds) { result, component in
            guard component.area >= 1,
                  distance(between: primary.bounds, and: component.bounds) <= CGFloat(nearbyDistance)
            else {
                return result
            }
            return result.union(component.bounds)
        }
    }

    private static func distance(between first: CGRect, and second: CGRect) -> CGFloat {
        let horizontal = max(first.minX - second.maxX, second.minX - first.maxX, 0)
        let vertical = max(first.minY - second.maxY, second.minY - first.maxY, 0)
        return hypot(horizontal, vertical)
    }
}

public struct SpriteRGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var bytes: [UInt8]

    public init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(width >= 0 && height >= 0)
        precondition(bytes.count == width * height * 4)
        self.width = width
        self.height = height
        self.bytes = bytes
    }
}

public enum SpriteMasking {
    public static func applyCanonicalAlpha(
        variant: SpriteRGBAImage,
        canonicalAlpha: [UInt8]
    ) -> SpriteRGBAImage {
        precondition(canonicalAlpha.count == variant.width * variant.height)
        var result = variant
        for (pixelIndex, alpha) in canonicalAlpha.enumerated() {
            result.bytes[pixelIndex * 4 + 3] = alpha
        }
        return result
    }
}
