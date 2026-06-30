#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the OpenNeko macOS app icon: the homepage black cat sprite on a white
// macOS-style rounded square. Usage:
//   generate-app-icon.swift <cat-art.png> <output.appiconset>

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: generate-app-icon.swift <cat-art.png> <output.appiconset>\n", stderr)
    exit(2)
}

let catURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

guard let catImage = NSImage(contentsOf: catURL) else {
    fputs("failed to load cat art: \(catURL.path)\n", stderr)
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func alphaTrimmed(_ source: NSImage, cutoff: UInt8 = 16) -> NSImage {
    guard let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return source
    }

    let width = cgSource.width
    let height = cgSource.height
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        .union(.byteOrder32Big)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        return source
    }

    context.interpolationQuality = .none
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(cgSource, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width {
            let alpha = pixels[(y * bytesPerRow) + (x * 4) + 3]
            if alpha > cutoff {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard maxX >= minX, maxY >= minY else {
        return source
    }

    let padding = 2
    let crop = CGRect(
        x: max(0, minX - padding),
        y: max(0, minY - padding),
        width: min(width, maxX + padding + 1) - max(0, minX - padding),
        height: min(height, maxY + padding + 1) - max(0, minY - padding)
    )

    guard let cropped = cgSource.cropping(to: crop) else {
        return source
    }
    return NSImage(cgImage: cropped, size: NSSize(width: crop.width, height: crop.height))
}

let centeredCatImage = alphaTrimmed(catImage)

// Master canvas rendered at 1024 then downscaled for every required size.
let master = 1024.0

func renderMaster() -> NSBitmapImageRep {
    let size = master
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("failed to allocate master bitmap\n", stderr)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    // macOS Big Sur grid: body is inset from the full bleed, corner radius
    // ~0.224 of the body edge.
    let inset = size * 0.0975
    let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = body.width * 0.2237
    let squircle = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // Soft drop shadow under the tile.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.shadowBlurRadius = size * 0.03
    shadow.shadowColor = color(11, 16, 26, 0.20)
    shadow.set()
    color(255, 255, 255).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // White tile with a light system-style bevel.
    NSGraphicsContext.saveGraphicsState()
    squircle.setClip()
    NSGradient(colors: [
        color(255, 255, 255),
        color(248, 250, 252),
        color(232, 238, 243)
    ], atLocations: [0.0, 0.62, 1.0], colorSpace: .deviceRGB)?
        .draw(in: body, angle: -90)

    // Subtle top sheen.
    NSGradient(colors: [
        color(255, 255, 255, 0.48),
        color(255, 255, 255, 0.0)
    ])?.draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)

    // Cat art (pixel-art) — keep crisp pixels with nearest-neighbour.
    NSGraphicsContext.current?.imageInterpolation = .none
    let catScale = body.width * 0.76
    let catRect = NSRect(
        x: body.midX - catScale / 2,
        y: body.midY - catScale / 2,
        width: catScale,
        height: catScale
    )
    let catShadow = NSShadow()
    catShadow.shadowOffset = NSSize(width: 0, height: -size * 0.006)
    catShadow.shadowBlurRadius = size * 0.012
    catShadow.shadowColor = color(12, 18, 28, 0.20)
    catShadow.set()
    centeredCatImage.draw(in: catRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.current?.imageInterpolation = .high

    NSGraphicsContext.restoreGraphicsState() // remove clip

    // Crisp rim light for the tile edge.
    let rim = NSBezierPath(
        roundedRect: body.insetBy(dx: size * 0.004, dy: size * 0.004),
        xRadius: radius * 0.99, yRadius: radius * 0.99
    )
    color(255, 255, 255, 0.82).setStroke()
    rim.lineWidth = size * 0.006
    rim.stroke()

    let outerRim = NSBezierPath(
        roundedRect: body.insetBy(dx: size * 0.010, dy: size * 0.010),
        xRadius: radius * 0.96, yRadius: radius * 0.96
    )
    color(124, 139, 154, 0.16).setStroke()
    outerRim.lineWidth = size * 0.004
    outerRim.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

let masterRep = renderMaster()
let masterImage = NSImage(size: NSSize(width: master, height: master))
masterImage.addRepresentation(masterRep)

func renderSize(_ pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "openNekoAppIcon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
    masterImage.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero, operation: .sourceOver, fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "openNekoAppIcon", code: 2)
    }
    return png
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, pixelSize) in outputs {
    let data = try renderSize(pixelSize)
    try data.write(to: outputURL.appendingPathComponent(filename), options: .atomic)
}

// Keep the Contents.json that already maps these filenames.
fputs("wrote \(outputs.count) icon sizes to \(outputURL.path)\n", stderr)
