import AppKit
import Foundation

enum SpriteContactSheet {
    private static let tileSize = CGSize(width: 128, height: 128)
    private static let labelWidth: CGFloat = 104

    static func generate(options: ContactSheetOptions) throws {
        try FileManager.default.createDirectory(
            at: options.outputDirectory,
            withIntermediateDirectories: true
        )
        for skin in SpriteBundleValidator.skins {
            let output = options.outputDirectory.appendingPathComponent("\(skin)-contact-sheet.png")
            try writeSkinSheet(skin: skin, sprites: options.spritesDirectory, output: output)
            print(output.path)
        }
        for state in SpriteBundleValidator.states {
            let output = options.outputDirectory.appendingPathComponent("state-\(state).png")
            try writeStateSheet(state: state, sprites: options.spritesDirectory, output: output)
            print(output.path)
        }
    }

    private static func writeSkinSheet(skin: String, sprites: URL, output: URL) throws {
        let rows = SpriteBundleValidator.states.count
        let size = CGSize(width: labelWidth + tileSize.width * 4, height: tileSize.height * CGFloat(rows))
        try render(size: size, output: output) {
            for (row, state) in SpriteBundleValidator.states.enumerated() {
                drawLabel(state, row: row, totalRows: rows)
                for frame in 0..<4 {
                    let url = sprites
                        .appendingPathComponent(skin, isDirectory: true)
                        .appendingPathComponent("\(state)_\(frame).png")
                    try drawSprite(url, column: frame, row: row, totalRows: rows)
                }
            }
        }
    }

    private static func writeStateSheet(state: String, sprites: URL, output: URL) throws {
        let rows = SpriteBundleValidator.skins.count
        let size = CGSize(width: labelWidth + tileSize.width * 4, height: tileSize.height * CGFloat(rows))
        try render(size: size, output: output) {
            for (row, skin) in SpriteBundleValidator.skins.enumerated() {
                drawLabel(skin, row: row, totalRows: rows)
                for frame in 0..<4 {
                    let url = sprites
                        .appendingPathComponent(skin, isDirectory: true)
                        .appendingPathComponent("\(state)_\(frame).png")
                    try drawSprite(url, column: frame, row: row, totalRows: rows)
                }
            }
        }
    }

    private static func render(size: CGSize, output: URL, drawing: () throws -> Void) throws {
        let image = NSImage(size: size)
        image.lockFocus()
        do {
            NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            NSGraphicsContext.current?.imageInterpolation = .none
            try drawing()
            image.unlockFocus()
        } catch {
            image.unlockFocus()
            throw error
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            throw PipelineError.pngEncodingFailed(0)
        }
        try png.write(to: output, options: .atomic)
    }

    private static func drawSprite(_ url: URL, column: Int, row: Int, totalRows: Int) throws {
        guard let image = NSImage(contentsOf: url) else { throw PipelineError.missingFile(url) }
        let rect = CGRect(
            x: labelWidth + CGFloat(column) * tileSize.width,
            y: CGFloat(totalRows - row - 1) * tileSize.height,
            width: tileSize.width,
            height: tileSize.height
        )
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawLabel(_ label: String, row: Int, totalRows: Int) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
            .paragraphStyle: paragraph,
        ]
        let rect = CGRect(
            x: 8,
            y: CGFloat(totalRows - row - 1) * tileSize.height + 54,
            width: labelWidth - 16,
            height: 24
        )
        label.draw(in: rect, withAttributes: attributes)
    }
}
