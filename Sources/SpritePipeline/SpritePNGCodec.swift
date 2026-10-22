import AppKit
import Foundation
import OpenNekoKit

enum SpritePNGCodec {
    static func read(_ url: URL) throws -> SpriteRGBAImage {
        guard let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data) else {
            throw PipelineError.missingFile(url)
        }
        var bytes = Array(repeating: UInt8(0), count: bitmap.pixelsWide * bitmap.pixelsHigh * 4)
        var samples = Array(repeating: 0, count: max(bitmap.samplesPerPixel, 4))
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                bitmap.getPixel(&samples, atX: x, y: y)
                let offset = (y * bitmap.pixelsWide + x) * 4
                bytes[offset] = UInt8(clamping: samples[0])
                bytes[offset + 1] = UInt8(clamping: samples.count > 1 ? samples[1] : samples[0])
                bytes[offset + 2] = UInt8(clamping: samples.count > 2 ? samples[2] : samples[0])
                bytes[offset + 3] = UInt8(clamping: bitmap.hasAlpha && samples.count > 3 ? samples[3] : 255)
            }
        }
        return SpriteRGBAImage(width: bitmap.pixelsWide, height: bitmap.pixelsHigh, bytes: bytes)
    }

    static func write(_ image: SpriteRGBAImage, to url: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: image.width,
            pixelsHigh: image.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: image.width * 4,
            bitsPerPixel: 32
        ) else {
            throw PipelineError.pngEncodingFailed(0)
        }
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = (y * image.width + x) * 4
                var pixel = image.bytes[offset..<(offset + 4)].map(Int.init)
                bitmap.setPixel(
                    &pixel,
                    atX: x,
                    y: y
                )
            }
        }
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw PipelineError.pngEncodingFailed(0)
        }
        try data.write(to: url, options: .atomic)
    }
}

enum SpriteVariantMasker {
    static func apply(options: MaskOptions) throws {
        let names = try FileManager.default.contentsOfDirectory(
            at: options.canonicalDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "png" }.map(\.lastPathComponent).sorted()

        for name in names {
            let canonicalURL = options.canonicalDirectory.appendingPathComponent(name)
            let variantURL = options.variantDirectory.appendingPathComponent(name)
            let canonical = try SpritePNGCodec.read(canonicalURL)
            let variant = try SpritePNGCodec.read(variantURL)
            guard canonical.width == variant.width, canonical.height == variant.height else {
                throw PipelineError.validationFailed(1)
            }
            let alpha = stride(from: 3, to: canonical.bytes.count, by: 4).map { canonical.bytes[$0] }
            var masked = SpriteMasking.applyCanonicalAlpha(variant: variant, canonicalAlpha: alpha)
            repairNewlyOpaquePixels(in: &masked, original: variant)
            zeroTransparentRGB(in: &masked)
            try SpritePNGCodec.write(masked, to: variantURL)
            print(variantURL.path)
        }
    }

    private static func repairNewlyOpaquePixels(
        in image: inout SpriteRGBAImage,
        original: SpriteRGBAImage
    ) {
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = (y * image.width + x) * 4
                guard image.bytes[offset + 3] > 0, original.bytes[offset + 3] == 0 else { continue }
                if let color = nearestOpaqueColor(x: x, y: y, image: original) {
                    image.bytes[offset] = color.0
                    image.bytes[offset + 1] = color.1
                    image.bytes[offset + 2] = color.2
                }
            }
        }
    }

    private static func nearestOpaqueColor(
        x: Int,
        y: Int,
        image: SpriteRGBAImage
    ) -> (UInt8, UInt8, UInt8)? {
        for radius in 1...4 {
            for candidateY in max(0, y - radius)...min(image.height - 1, y + radius) {
                for candidateX in max(0, x - radius)...min(image.width - 1, x + radius) {
                    let offset = (candidateY * image.width + candidateX) * 4
                    if image.bytes[offset + 3] > 16 {
                        return (image.bytes[offset], image.bytes[offset + 1], image.bytes[offset + 2])
                    }
                }
            }
        }
        return nil
    }

    private static func zeroTransparentRGB(in image: inout SpriteRGBAImage) {
        for offset in stride(from: 0, to: image.bytes.count, by: 4) where image.bytes[offset + 3] == 0 {
            image.bytes[offset] = 0
            image.bytes[offset + 1] = 0
            image.bytes[offset + 2] = 0
        }
    }
}
