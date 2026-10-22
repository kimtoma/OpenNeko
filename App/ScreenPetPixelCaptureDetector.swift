import AppKit
import Darwin
import OpenNekoKit

enum ScreenPetPixelCaptureDetector {
    static func displayFrames() -> [CGRect] {
        NSScreen.screens.map(displayFrame(for:))
    }

    static func candidates(
        displayFrames: [CGRect],
        excludingFrames: [CGRect]
    ) -> [ScreenPetCandidate] {
        displayFrames.flatMap { displayFrame in
            candidates(in: displayFrame, excludingFrames: excludingFrames)
        }
    }

    private static func candidates(
        in displayFrame: CGRect,
        excludingFrames: [CGRect]
    ) -> [ScreenPetCandidate] {
        guard
            let image = ScreenImageCapture.capture(rect: displayFrame),
            let sample = PixelSample(cgImage: image, displayFrame: displayFrame)
        else {
            return []
        }

        return ScreenPetPixelDetector.candidates(
            imageWidth: sample.width,
            imageHeight: sample.height,
            imageFrame: displayFrame,
            pixelsPerPoint: sample.pixelsPerPoint,
            excludedFrames: excludingFrames,
            pixelAt: sample.pixelAt(x:y:)
        )
    }

    private static func displayFrame(for screen: NSScreen) -> CGRect {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return screen.frame
        }
        let bounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        return CGRect(x: bounds.minX, y: 0, width: bounds.width, height: bounds.height)
    }
}

private struct PixelSample {
    let width: Int
    let height: Int
    let pixelsPerPoint: CGFloat
    private let rgba: [UInt8]

    init?(cgImage: CGImage, displayFrame: CGRect) {
        let targetWidth = max(1, Int(displayFrame.width.rounded(.toNearestOrAwayFromZero)))
        let targetHeight = max(1, Int(displayFrame.height.rounded(.toNearestOrAwayFromZero)))
        var buffer = [UInt8](repeating: 0, count: targetWidth * targetHeight * 4)
        guard let context = CGContext(
            data: &buffer,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        self.width = targetWidth
        self.height = targetHeight
        self.pixelsPerPoint = CGFloat(targetWidth) / max(displayFrame.width, 1)
        self.rgba = buffer
    }

    func pixelAt(x: Int, y: Int) -> ScreenPetPixel {
        let index = (y * width + x) * 4
        return ScreenPetPixel(
            red: rgba[index],
            green: rgba[index + 1],
            blue: rgba[index + 2],
            alpha: rgba[index + 3]
        )
    }
}

private enum ScreenImageCapture {
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

    static func capture(rect: CGRect) -> CGImage? {
        guard let captureFunction else { return nil }
        let listOption = CGWindowListOption.optionOnScreenOnly.rawValue
        let imageOption = CGWindowImageOption.boundsIgnoreFraming.rawValue
            | CGWindowImageOption.bestResolution.rawValue
        return captureFunction(
            rect,
            listOption,
            kCGNullWindowID,
            imageOption
        )?.takeRetainedValue()
    }
}
