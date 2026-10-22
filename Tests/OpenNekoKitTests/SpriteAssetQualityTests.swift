import AppKit
import XCTest
@testable import OpenNekoKit

final class SpriteAssetQualityTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("openneko-sprite-quality-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testInspectionReportsAlphaBoundsPaddingAndConnectedComponents() throws {
        let url = try fixturePNG(
            name: "metrics",
            opaqueRect: CGRect(x: 16, y: 20, width: 80, height: 90)
        )

        let metrics = try SpriteAssetQuality.inspectPNG(at: url)

        XCTAssertEqual(metrics.width, 128)
        XCTAssertEqual(metrics.height, 128)
        XCTAssertEqual(metrics.alphaBounds, CGRect(x: 16, y: 20, width: 80, height: 90))
        XCTAssertEqual(metrics.minimumPadding, 16)
        XCTAssertEqual(metrics.opaquePixelCount, 7_200)
        XCTAssertEqual(metrics.transparentRGBPixelCount, 0)
        XCTAssertEqual(metrics.connectedComponentAreas, [7_200])
    }

    func testThinkingSigilLuminanceMustPulsePeakAndLeaveResidualGlow() throws {
        let descriptors = try [0.20, 0.55, 0.95, 0.40].enumerated().map { index, luminance in
            SpriteFrameDescriptor(
                skinID: "default",
                state: "thinking",
                frameIndex: index,
                url: try fixturePNG(name: "thinking-\(index)", sigilLuminance: luminance)
            )
        }

        let valid = SpriteAssetQuality.validate(frames: descriptors)
        XCTAssertFalse(valid.issues.contains { $0.code == .invalidThinkingSigilSequence })

        let invalidDescriptors = try [0.20, 0.95, 0.55, 0.40].enumerated().map { index, luminance in
            SpriteFrameDescriptor(
                skinID: "default",
                state: "thinking",
                frameIndex: index,
                url: try fixturePNG(name: "invalid-thinking-\(index)", sigilLuminance: luminance)
            )
        }
        let invalid = SpriteAssetQuality.validate(frames: invalidDescriptors)
        XCTAssertTrue(invalid.issues.contains { $0.code == .invalidThinkingSigilSequence })
    }

    func testValidationRejectsWrongDimensionsAndEdgeContact() throws {
        let wrongSize = try fixturePNG(
            name: "wrong-size",
            width: 96,
            height: 128,
            opaqueRect: CGRect(x: 16, y: 20, width: 64, height: 90),
            sigilLuminance: 0.6
        )
        let edgeTouching = try fixturePNG(
            name: "edge-touching",
            opaqueRect: CGRect(x: 0, y: 20, width: 96, height: 90),
            contaminatedTransparentPixel: CGPoint(x: 127, y: 127),
            sigilLuminance: 0.6
        )
        let report = SpriteAssetQuality.validate(frames: [
            SpriteFrameDescriptor(skinID: "default", state: "idle", frameIndex: 0, url: wrongSize),
            SpriteFrameDescriptor(skinID: "default", state: "idle", frameIndex: 1, url: edgeTouching),
        ])

        XCTAssertTrue(report.issues.contains { $0.code == .invalidDimensions })
        XCTAssertTrue(report.issues.contains { $0.code == .alphaTouchesCanvasEdge })
    }

    func testValidationRejectsVariantSilhouetteMismatch() throws {
        let canonical = try fixturePNG(
            name: "canonical",
            opaqueRect: CGRect(x: 24, y: 24, width: 80, height: 80),
            sigilLuminance: 0.6
        )
        let variant = try fixturePNG(
            name: "variant",
            opaqueRect: CGRect(x: 25, y: 24, width: 80, height: 80),
            sigilLuminance: 0.6
        )
        let report = SpriteAssetQuality.validate(frames: [
            SpriteFrameDescriptor(skinID: "default", state: "idle", frameIndex: 0, url: canonical),
            SpriteFrameDescriptor(skinID: "black", state: "idle", frameIndex: 0, url: variant),
        ])

        XCTAssertTrue(report.issues.contains { $0.code == .silhouetteMismatch })
    }

    private func fixturePNG(
        name: String,
        width: Int = 128,
        height: Int = 128,
        opaqueRect: CGRect = CGRect(x: 24, y: 24, width: 80, height: 80),
        contaminatedTransparentPixel: CGPoint? = nil,
        sigilLuminance: Double? = nil
    ) throws -> URL {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let data = bitmap.bitmapData else {
            throw FixtureError.cannotCreateBitmap
        }

        memset(data, 0, bitmap.bytesPerRow * bitmap.pixelsHigh)
        for y in Int(opaqueRect.minY)..<Int(opaqueRect.maxY) {
            for x in Int(opaqueRect.minX)..<Int(opaqueRect.maxX) {
                setPixel(data: data, bytesPerRow: bitmap.bytesPerRow, x: x, y: y, red: 40, green: 50, blue: 70, alpha: 255)
            }
        }

        if let contaminatedTransparentPixel {
            setPixel(
                data: data,
                bytesPerRow: bitmap.bytesPerRow,
                x: Int(contaminatedTransparentPixel.x),
                y: Int(contaminatedTransparentPixel.y),
                red: 255,
                green: 0,
                blue: 0,
                alpha: 0
            )
        }

        if let sigilLuminance {
            let value = UInt8((sigilLuminance * 255).rounded())
            for point in [
                CGPoint(x: 63, y: 31), CGPoint(x: 64, y: 31),
                CGPoint(x: 62, y: 32), CGPoint(x: 63, y: 32), CGPoint(x: 64, y: 32), CGPoint(x: 65, y: 32),
                CGPoint(x: 63, y: 33), CGPoint(x: 64, y: 33),
            ] {
                setPixel(
                    data: data,
                    bytesPerRow: bitmap.bytesPerRow,
                    x: Int(point.x),
                    y: Int(point.y),
                    red: 0,
                    green: value,
                    blue: value,
                    alpha: 255
                )
            }
        }

        let url = temporaryDirectory.appendingPathComponent("\(name).png")
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw FixtureError.cannotEncodePNG
        }
        try png.write(to: url)
        return url
    }

    private func setPixel(
        data: UnsafeMutablePointer<UInt8>,
        bytesPerRow: Int,
        x: Int,
        y: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8
    ) {
        let offset = y * bytesPerRow + x * 4
        data[offset] = red
        data[offset + 1] = green
        data[offset + 2] = blue
        data[offset + 3] = alpha
    }

    private enum FixtureError: Error {
        case cannotCreateBitmap
        case cannotEncodePNG
    }
}
