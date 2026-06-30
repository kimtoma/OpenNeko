#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the OpenNeko DMG installer window background.
// The Finder item labels carry the text; the background stays quiet and only
// leaves a centered paw trail from OpenNeko.app to Applications.
//
// Usage: generate-dmg-background.swift <output.png> [unused-font.ttf]

let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
    fputs("usage: generate-dmg-background.swift <output.png> [unused-font.ttf]\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let canvasW: CGFloat = 880
let canvasH: CGFloat = 560
let iconCenterY: CGFloat = 312

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasW),
    pixelsHigh: Int(canvasH),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap context\n", stderr)
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func pt(_ xFromLeft: CGFloat, _ yFromTop: CGFloat) -> NSPoint {
    NSPoint(x: xFromLeft, y: canvasH - yFromTop)
}

func drawPawPrint(center: NSPoint, scale: CGFloat, rotation: CGFloat, fill: NSColor) {
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    transform.scale(by: scale)

    NSGraphicsContext.saveGraphicsState()
    transform.concat()
    fill.setFill()

    NSBezierPath(ovalIn: NSRect(x: -8, y: -9, width: 16, height: 13)).fill()
    for toe in [
        NSRect(x: -13, y: 4, width: 8, height: 10),
        NSRect(x: -4, y: 8, width: 8, height: 11),
        NSRect(x: 6, y: 7, width: 8, height: 10),
        NSRect(x: 13, y: 1, width: 7, height: 9)
    ] {
        NSBezierPath(ovalIn: toe).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

let canvas = NSRect(origin: .zero, size: NSSize(width: canvasW, height: canvasH))
color(248, 250, 252).setFill()
canvas.fill()

let pawColor = color(71, 82, 102, 0.30)
let pawTrail: [(NSPoint, CGFloat, CGFloat)] = [
    (pt(336, iconCenterY + 24), 0.60, -16),
    (pt(378, iconCenterY + 2), 0.68, 12),
    (pt(420, iconCenterY + 14), 0.74, -8),
    (pt(462, iconCenterY - 6), 0.70, 16),
    (pt(503, iconCenterY + 6), 0.62, -12)
]

for (center, scale, rotation) in pawTrail {
    drawPawPrint(center: center, scale: scale, rotation: rotation, fill: pawColor)
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.95]) else {
    fputs("failed to render DMG background\n", stderr)
    exit(1)
}

try png.write(to: outputURL, options: .atomic)
fputs("wrote DMG background \(Int(canvasW))x\(Int(canvasH)) to \(outputURL.path)\n", stderr)
