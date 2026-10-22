import AppKit
import CoreGraphics
import Foundation
import OpenNekoKit

enum SpriteSheetExtractor {
    private static let outputSize = CGSize(width: 128, height: 128)

    static func extract(options: ExtractOptions) throws {
        guard let source = NSImage(contentsOf: options.sheetURL),
              let sourceImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw PipelineError.unreadableImage(options.sheetURL)
        }
        guard let normalizedSource = normalizedSourceImage(
            sourceImage,
            removesCheckerboard: options.removesCheckerboard
        ) else {
            throw PipelineError.unreadableImage(options.sheetURL)
        }
        guard containsTransparentPixel(normalizedSource) else {
            throw PipelineError.sourceIsNotTransparent(options.sheetURL)
        }

        try FileManager.default.createDirectory(
            at: options.outputDirectory,
            withIntermediateDirectories: true
        )

        let cells = SpriteSheetGeometry.gridCells(
            imageSize: CGSize(width: normalizedSource.width, height: normalizedSource.height),
            columns: options.columns,
            rows: options.rows
        )
        guard options.states.count == 1 || options.states.count == options.rows else {
            throw PipelineError.invalidLayout(
                states: options.states.count,
                columns: options.columns,
                rows: options.rows
            )
        }
        let viewports = try commonViewports(
            source: normalizedSource,
            cells: cells,
            columns: options.columns,
            statesCount: options.states.count
        )
        for (index, rect) in cells.enumerated() {
            let viewport = viewports[index]
            let sourceRect = CGRect(
                x: rect.minX + viewport.minX,
                y: rect.minY + viewport.minY,
                width: viewport.width,
                height: viewport.height
            ).integral
            guard let cropped = normalizedSource.cropping(to: sourceRect) else {
                throw PipelineError.cropFailed(index)
            }
            guard let rendered = renderNearestNeighbor(cropped) else {
                throw PipelineError.renderFailed(index)
            }
            let bitmap = NSBitmapImageRep(cgImage: rendered)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw PipelineError.pngEncodingFailed(index)
            }
            let state: String
            let frameIndex: Int
            if options.states.count == 1 {
                state = options.states[0]
                frameIndex = index
            } else {
                state = options.states[index / options.columns]
                frameIndex = index % options.columns
            }
            let url = options.outputDirectory.appendingPathComponent("\(state)_\(frameIndex).png")
            try png.write(to: url, options: .atomic)
            print(url.path)
        }
    }

    private static func normalizedSourceImage(
        _ source: CGImage,
        removesCheckerboard: Bool
    ) -> CGImage? {
        let width = source.width
        let height = source.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else {
            return nil
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        let byteCount = width * height * 4
        let pointer = data.assumingMemoryBound(to: UInt8.self)
        var image = SpriteRGBAImage(
            width: width,
            height: height,
            bytes: Array(UnsafeBufferPointer(start: pointer, count: byteCount))
        )
        if removesCheckerboard {
            image = SpriteBackgroundRemoval.clearEdgeConnectedNeutralBackground(in: image)
        }
        _ = image.bytes.withUnsafeBytes { bytes in
            memcpy(data, bytes.baseAddress!, byteCount)
        }
        return context.makeImage()
    }

    private static func commonViewports(
        source: CGImage,
        cells: [CGRect],
        columns: Int,
        statesCount: Int
    ) throws -> [CGRect] {
        let groups: [[Int]]
        if statesCount == 1 {
            groups = [Array(cells.indices)]
        } else {
            groups = stride(from: 0, to: cells.count, by: columns).map {
                Array($0..<min($0 + columns, cells.count))
            }
        }

        var viewports = Array(repeating: CGRect.zero, count: cells.count)
        for group in groups {
            var boundsByIndex: [Int: CGRect] = [:]
            for index in group {
                guard let cellImage = source.cropping(to: cells[index]),
                      let bounds = alphaBounds(in: cellImage)
                else {
                    throw PipelineError.cropFailed(index)
                }
                boundsByIndex[index] = bounds
            }
            let cellSize = cells[group[0]].size
            let maxWidth = boundsByIndex.values.map(\.width).max() ?? cellSize.width
            let maxHeight = boundsByIndex.values.map(\.height).max() ?? cellSize.height
            let padding = max(4, ceil(max(maxWidth, maxHeight) * 0.04))
            let viewportSize = CGSize(
                width: min(cellSize.width, maxWidth + padding * 2),
                height: min(cellSize.height, maxHeight + padding * 2)
            )
            for index in group {
                guard let bounds = boundsByIndex[index] else { continue }
                let maxX = cellSize.width - viewportSize.width
                let maxY = cellSize.height - viewportSize.height
                let origin = CGPoint(
                    x: min(max(0, bounds.midX - viewportSize.width / 2), maxX),
                    y: min(max(0, bounds.midY - viewportSize.height / 2), maxY)
                )
                viewports[index] = CGRect(origin: origin, size: viewportSize)
            }
        }
        return viewports
    }

    private static func alphaBounds(in image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else {
            return nil
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let byteCount = width * height * 4
        let pointer = data.assumingMemoryBound(to: UInt8.self)
        let rgba = SpriteRGBAImage(
            width: width,
            height: height,
            bytes: Array(UnsafeBufferPointer(start: pointer, count: byteCount))
        )
        return SpriteAlphaGeometry.contentBounds(
            in: rgba,
            nearbyDistance: 0
        )
    }

    private static func containsTransparentPixel(_ image: CGImage) -> Bool {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipFirst, image.alphaInfo != .noneSkipLast,
              let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data)
        else {
            return false
        }

        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        guard bytesPerPixel >= 4 else { return false }
        let alphaOffset: Int
        switch image.alphaInfo {
        case .first, .premultipliedFirst:
            alphaOffset = 0
        case .last, .premultipliedLast:
            alphaOffset = bytesPerPixel - 1
        default:
            return false
        }

        for y in 0..<image.height {
            let row = y * image.bytesPerRow
            for x in 0..<image.width where bytes[row + x * bytesPerPixel + alphaOffset] < 255 {
                return true
            }
        }
        return false
    }

    private static func renderNearestNeighbor(_ source: CGImage) -> CGImage? {
        let width = Int(outputSize.width)
        let height = Int(outputSize.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.clear(CGRect(origin: .zero, size: outputSize))
        context.interpolationQuality = .none
        let availableSize = outputSize.width - 24
        let scale = min(availableSize / CGFloat(source.width), availableSize / CGFloat(source.height))
        let drawSize = CGSize(width: CGFloat(source.width) * scale, height: CGFloat(source.height) * scale)
        let drawRect = CGRect(
            x: (outputSize.width - drawSize.width) / 2,
            y: (outputSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        context.draw(source, in: drawRect)
        return context.makeImage()
    }
}
