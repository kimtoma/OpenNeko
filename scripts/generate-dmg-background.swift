#!/usr/bin/env swift
import AppKit
import CoreText
import Foundation

// Renders the OpenNeko DMG installer window background.
// Finder item labels carry the install targets; the background adds only a
// compact OpenNeko title and a centered paw trail from the app to Applications.
//
// Usage: generate-dmg-background.swift <output.png> [title-font.woff2]

let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
    fputs("usage: generate-dmg-background.swift <output.png> [unused-font.ttf]\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let titleFontURL = arguments.count == 3 ? URL(fileURLWithPath: arguments[2]) : nil
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let canvasW: CGFloat = 760
let canvasH: CGFloat = 400
let iconCenterY: CGFloat = 245

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

func drawCentered(_ string: String, center: NSPoint, font: NSFont, fill: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributed = NSAttributedString(
        string: string,
        attributes: [
            .font: font,
            .foregroundColor: fill,
            .paragraphStyle: paragraph,
            .kern: 0.4
        ]
    )
    let size = attributed.size()
    attributed.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
}

func registerFont(at url: URL?) {
    guard let url else {
        return
    }
    var error: Unmanaged<CFError>?
    if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
       let errorDescription = error?.takeRetainedValue().localizedDescription {
        fputs("warning: failed to register title font: \(errorDescription)\n", stderr)
    }
}

func makeTitleFont(size: CGFloat) -> NSFont {
    registerFont(at: titleFontURL)
    return NSFont(name: "Geist Pixel", size: size)
        ?? NSFont(name: "GeistPixel-Square", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

let canvas = NSRect(origin: .zero, size: NSSize(width: canvasW, height: canvasH))
color(248, 250, 252).setFill()
canvas.fill()

let titleFont = makeTitleFont(size: 60)
NSGraphicsContext.current?.shouldAntialias = false
drawCentered("OpenNeko", center: pt(canvasW / 2, 112), font: titleFont, fill: color(17, 19, 24))
NSGraphicsContext.current?.shouldAntialias = true

let pawColor = color(71, 82, 102, 0.30)
let pawTrail: [(NSPoint, CGFloat, CGFloat)] = [
    (pt(316, iconCenterY + 16), 0.58, -16),
    (pt(354, iconCenterY - 4), 0.66, 12),
    (pt(392, iconCenterY + 10), 0.70, -8),
    (pt(430, iconCenterY - 8), 0.66, 16),
    (pt(468, iconCenterY + 5), 0.58, -12)
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
