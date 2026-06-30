#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the OpenNeko DMG volume icon: a macOS-style external-disk cartridge
// with a very subtle OpenNeko bar-icon cat silhouette pressed into its face.
// Usage: generate-volume-icon.swift <cat-template.png> <output.iconset>

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: generate-volume-icon.swift <cat-template.png> <output.iconset>\n", stderr)
    exit(2)
}

let catURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let catImage = NSImage(contentsOf: catURL) else {
    fputs("failed to load cat template: \(catURL.path)\n", stderr)
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

// Recolour the source alpha into a flat tint. Very low alpha is discarded so
// sprite export noise does not become a visible square on the disk face.
func tintedMask(_ source: NSImage, _ tint: NSColor, _ side: CGFloat, cutoff: UInt8 = 48) -> NSImage {
    let pixels = max(1, Int(side.rounded()))
    guard let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return NSImage(size: NSSize(width: side, height: side))
    }

    let bytesPerRow = pixels * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        .union(.byteOrder32Big)
    var pixelsRGBA = [UInt8](repeating: 0, count: pixels * pixels * 4)
    guard let context = CGContext(
        data: &pixelsRGBA,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        return NSImage(size: NSSize(width: side, height: side))
    }

    context.interpolationQuality = .high
    context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.draw(cgSource, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let resolved = tint.usingColorSpace(.deviceRGB) ?? tint
    let red = resolved.redComponent
    let green = resolved.greenComponent
    let blue = resolved.blueComponent
    let tintAlpha = resolved.alphaComponent

    for offset in stride(from: 0, to: pixelsRGBA.count, by: 4) {
        let sourceAlpha = pixelsRGBA[offset + 3]
        if sourceAlpha < cutoff {
            pixelsRGBA[offset + 0] = 0
            pixelsRGBA[offset + 1] = 0
            pixelsRGBA[offset + 2] = 0
            pixelsRGBA[offset + 3] = 0
        } else {
            let finalAlpha = UInt8(clamping: Int((CGFloat(sourceAlpha) * tintAlpha).rounded()))
            pixelsRGBA[offset + 0] = UInt8(clamping: Int((red * CGFloat(finalAlpha)).rounded()))
            pixelsRGBA[offset + 1] = UInt8(clamping: Int((green * CGFloat(finalAlpha)).rounded()))
            pixelsRGBA[offset + 2] = UInt8(clamping: Int((blue * CGFloat(finalAlpha)).rounded()))
            pixelsRGBA[offset + 3] = finalAlpha
        }
    }

    let data = Data(pixelsRGBA)
    guard
        let provider = CGDataProvider(data: data as CFData),
        let cgImage = CGImage(
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    else {
        return NSImage(size: NSSize(width: side, height: side))
    }

    return NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
}

let master: CGFloat = 1024

func renderMaster() -> NSBitmapImageRep {
    let s = master
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fputs("failed to allocate master bitmap\n", stderr); exit(1) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    // External-disk cartridge body, close to the default macOS disk silhouette.
    let bodyW = s * 0.58
    let bodyH = s * 0.60
    let body = NSRect(x: (s - bodyW) / 2, y: s * 0.245, width: bodyW, height: bodyH)
    let radius = s * 0.064

    // Soft ground shadow beneath the standing cartridge.
    NSGraphicsContext.saveGraphicsState()
    let ground = NSBezierPath(ovalIn: NSRect(
        x: body.midX - s * 0.29, y: s * 0.122,
        width: s * 0.58, height: s * 0.080))
    let groundShadow = NSShadow()
    groundShadow.shadowOffset = .zero
    groundShadow.shadowBlurRadius = s * 0.035
    groundShadow.shadowColor = color(34, 40, 50, 0.42)
    groundShadow.set()
    color(34, 40, 50, 0.5).setFill()
    ground.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Rounded bottom foot.
    let stand = NSRect(x: body.minX, y: s * 0.150, width: body.width, height: s * 0.120)
    let standPath = NSBezierPath(roundedRect: stand, xRadius: s * 0.056, yRadius: s * 0.056)
    NSGradient(colors: [color(178, 183, 188), color(125, 130, 134)])?
        .draw(in: stand, angle: -90)
    color(70, 74, 78, 0.55).setStroke()
    standPath.lineWidth = s * 0.005
    standPath.stroke()

    // Drop shadow for the body itself.
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow()
    bodyShadow.shadowOffset = NSSize(width: 0, height: -s * 0.014)
    bodyShadow.shadowBlurRadius = s * 0.035
    bodyShadow.shadowColor = color(28, 34, 44, 0.34)
    bodyShadow.set()
    color(220, 224, 228).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Brushed-metal face: vertical gradient with side highlights.
    NSGraphicsContext.saveGraphicsState()
    bodyPath.setClip()
    NSGradient(colors: [
        color(236, 238, 240),
        color(202, 206, 210),
        color(174, 179, 184)
    ], atLocations: [0.0, 0.52, 1.0], colorSpace: .deviceRGB)?.draw(in: body, angle: -90)

    // Gentle brushed-metal vertical bands.
    let bandCount = 16
    for index in 0..<bandCount {
        let t = CGFloat(index) / CGFloat(max(1, bandCount - 1))
        let x = body.minX + body.width * t
        let width = body.width / CGFloat(bandCount) * 1.35
        let alpha = index % 2 == 0 ? 0.06 : 0.035
        color(255, 255, 255, alpha).setFill()
        NSRect(x: x, y: body.minY, width: width, height: body.height).fill()
    }

    // Rounded top cap highlight (light catching the domed top edge).
    NSGradient(colors: [color(255, 255, 255, 1.0), color(255, 255, 255, 0.0)])?
        .draw(in: NSRect(x: body.minX, y: body.maxY - body.height * 0.26,
                         width: body.width, height: body.height * 0.26), angle: -90)

    // Bottom shaded lip where the cartridge meets its base.
    NSGradient(colors: [color(132, 138, 144, 0.0), color(92, 98, 104, 0.42)])?
        .draw(in: NSRect(x: body.minX, y: body.minY,
                         width: body.width, height: body.height * 0.18), angle: -90)

    // Side bevels — bright vertical metal reflections on each edge.
    let bevelW = body.width * 0.12
    NSGradient(colors: [color(255, 255, 255, 0.75), color(255, 255, 255, 0.0)])?
        .draw(in: NSRect(x: body.minX, y: body.minY, width: bevelW, height: body.height), angle: 0)
    NSGradient(colors: [color(255, 255, 255, 0.0), color(255, 255, 255, 0.70)])?
        .draw(in: NSRect(x: body.maxX - bevelW, y: body.minY, width: bevelW, height: body.height), angle: 0)
    NSGraphicsContext.restoreGraphicsState()

    // Crisp inner rim.
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: s * 0.004, dy: s * 0.004),
                           xRadius: radius * 0.95, yRadius: radius * 0.95)
    color(255, 255, 255, 0.7).setStroke()
    rim.lineWidth = s * 0.005
    rim.stroke()

    // Subtle pressed-in OpenNeko bar-icon silhouette. Keep it low contrast so it
    // reads like the Apple logo on a default disk, not a black decal.
    let glyph = s * 0.34
    let glyphRect = NSRect(x: body.midX - glyph / 2,
                           y: body.midY - glyph / 2 + s * 0.005,
                           width: glyph, height: glyph)
    NSGraphicsContext.current?.imageInterpolation = .high
    tintedMask(catImage, color(255, 255, 255, 0.26), glyph)
        .draw(in: glyphRect.offsetBy(dx: 0, dy: -s * 0.010), from: .zero,
              operation: .sourceOver, fraction: 1)
    tintedMask(catImage, color(66, 70, 74, 0.20), glyph)
        .draw(in: glyphRect.offsetBy(dx: 0, dy: s * 0.008), from: .zero,
              operation: .sourceOver, fraction: 1)
    tintedMask(catImage, color(105, 110, 116, 0.28), glyph)
        .draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let masterRep = renderMaster()
let masterImage = NSImage(size: NSSize(width: master, height: master))
masterImage.addRepresentation(masterRep)

func renderSize(_ pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw NSError(domain: "openNekoVolumeIcon", code: 1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
    masterImage.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
                     from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "openNekoVolumeIcon", code: 2)
    }
    return png
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (filename, pixelSize) in outputs {
    try renderSize(pixelSize).write(to: outputURL.appendingPathComponent(filename), options: .atomic)
}
fputs("wrote \(outputs.count) volume-icon sizes to \(outputURL.path)\n", stderr)
