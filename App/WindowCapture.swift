import AppKit
import Darwin

struct WindowCaptureItem {
    let frame: NSRect
    let image: NSImage
}

enum WindowCapture {
    static func pngData(items: [WindowCaptureItem]) -> Data? {
        let visibleItems = items.filter {
            !$0.frame.isEmpty && $0.image.size.width > 0 && $0.image.size.height > 0
        }
        guard let first = visibleItems.first else { return nil }

        let captureFrame = visibleItems
            .dropFirst()
            .reduce(first.frame) { $0.union($1.frame) }
            .integral
        guard captureFrame.width > 0, captureFrame.height > 0 else { return nil }

        let pixelSize = NSSize(
            width: ceil(captureFrame.width),
            height: ceil(captureFrame.height)
        )
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmap.size = captureFrame.size

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }

        context.imageInterpolation = .none
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: captureFrame.size).fill()
        for item in visibleItems {
            let drawRect = NSRect(
                x: item.frame.minX - captureFrame.minX,
                y: item.frame.minY - captureFrame.minY,
                width: item.frame.width,
                height: item.frame.height
            )
            item.image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

extension NSWindow {
    func openNekoCaptureItem() -> WindowCaptureItem? {
        guard isVisible, let contentView else { return nil }
        displayIfNeeded()
        contentView.displayIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        let bounds = contentView.bounds
        let scale = max(backingScaleFactor, 1)
        guard
            bounds.width > 0,
            bounds.height > 0
        else {
            return nil
        }

        if let cgImage = LegacyWindowImageCapture.capture(windowNumber: windowNumber),
           !WindowCapture.looksBlankOrBlack(cgImage) {
            let image = NSImage(cgImage: cgImage, size: frame.size)
            return WindowCaptureItem(frame: frame, image: image)
        }

        let pdfData = contentView.dataWithPDF(inside: bounds)
        if let image = NSImage(data: pdfData), image.size.width > 0, image.size.height > 0 {
            image.size = bounds.size
            return WindowCaptureItem(frame: frame, image: image)
        }

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(ceil(bounds.width * scale)),
                pixelsHigh: Int(ceil(bounds.height * scale)),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }
        bitmap.size = bounds.size

        if let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap),
           let layer = contentView.layer {
            let cgContext = graphicsContext.cgContext
            cgContext.clear(CGRect(origin: .zero, size: CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)))
            cgContext.saveGState()
            cgContext.scaleBy(x: scale, y: scale)
            layer.render(in: cgContext)
            cgContext.restoreGState()
        } else {
            contentView.cacheDisplay(in: bounds, to: bitmap)
        }

        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmap)
        return WindowCaptureItem(frame: frame, image: image)
    }
}

private enum LegacyWindowImageCapture {
    private typealias CaptureFunction = @convention(c) (
        CGRect,
        UInt32,
        UInt32,
        UInt32
    ) -> Unmanaged<CGImage>?

    private static let captureFunction: CaptureFunction? = {
        guard let handle = dlopen(
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
            RTLD_LAZY
        ) else {
            return nil
        }
        guard let symbol = dlsym(handle, "CGWindowListCreateImage") else {
            return nil
        }
        return unsafeBitCast(symbol, to: CaptureFunction.self)
    }()

    static func capture(windowNumber: Int) -> CGImage? {
        guard let captureFunction else { return nil }
        let listOption = CGWindowListOption.optionIncludingWindow.rawValue
        let imageOption = CGWindowImageOption.boundsIgnoreFraming.rawValue
            | CGWindowImageOption.bestResolution.rawValue
        return captureFunction(
            .null,
            listOption,
            CGWindowID(windowNumber),
            imageOption
        )?.takeRetainedValue()
    }
}

private extension WindowCapture {
    static func looksBlankOrBlack(_ image: CGImage) -> Bool {
        let sampleSize = 24
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        guard let context = CGContext(
            data: &pixels,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        var visibleNonBlack = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            let alpha = Int(pixels[index + 3])
            if alpha > 12, red + green + blue > 36 {
                visibleNonBlack += 1
                if visibleNonBlack > 8 {
                    return false
                }
            }
        }
        return true
    }
}
