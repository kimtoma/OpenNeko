import CoreGraphics
import XCTest
@testable import OpenNekoKit

final class SpriteSheetGeometryTests: XCTestCase {
    func testTwoByTwoSheetProducesFourEqualCellsInReadingOrder() {
        XCTAssertEqual(
            SpriteSheetGeometry.cells(imageSize: CGSize(width: 1254, height: 1254)),
            [
                CGRect(x: 0, y: 0, width: 627, height: 627),
                CGRect(x: 627, y: 0, width: 627, height: 627),
                CGRect(x: 0, y: 627, width: 627, height: 627),
                CGRect(x: 627, y: 627, width: 627, height: 627),
            ]
        )
    }

    func testOddSheetSizeTrimsOnlyTheOuterRightAndBottomPixels() {
        XCTAssertEqual(
            SpriteSheetGeometry.cells(imageSize: CGSize(width: 1255, height: 1257)),
            [
                CGRect(x: 0, y: 0, width: 627, height: 628),
                CGRect(x: 627, y: 0, width: 627, height: 628),
                CGRect(x: 0, y: 628, width: 627, height: 628),
                CGRect(x: 627, y: 628, width: 627, height: 628),
            ]
        )
    }

    func testCanonicalMaskReplacesOnlyVariantAlpha() {
        let variant = SpriteRGBAImage(
            width: 2,
            height: 1,
            bytes: [10, 20, 30, 40, 50, 60, 70, 80]
        )
        let result = SpriteMasking.applyCanonicalAlpha(variant: variant, canonicalAlpha: [0, 255])

        XCTAssertEqual(result.bytes, [10, 20, 30, 0, 50, 60, 70, 255])
    }

    func testFourByThreeGridUsesTopLeftReadingOrder() {
        let cells = SpriteSheetGeometry.gridCells(
            imageSize: CGSize(width: 1200, height: 900),
            columns: 4,
            rows: 3
        )

        XCTAssertEqual(cells.count, 12)
        XCTAssertEqual(cells[0], CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertEqual(cells[3], CGRect(x: 900, y: 0, width: 300, height: 300))
        XCTAssertEqual(cells[4], CGRect(x: 0, y: 300, width: 300, height: 300))
        XCTAssertEqual(cells[11], CGRect(x: 900, y: 600, width: 300, height: 300))
    }

    func testBackgroundRemovalClearsOnlyEdgeConnectedNeutralPixels() {
        var bytes = Array(repeating: UInt8(0), count: 7 * 7 * 4)
        for y in 0..<7 {
            for x in 0..<7 {
                let offset = (y * 7 + x) * 4
                let isOutline = x == 1 || x == 5 || y == 1 || y == 5
                let value: UInt8
                if x == 0 || x == 6 || y == 0 || y == 6 {
                    value = (x + y).isMultiple(of: 2) ? 244 : 232
                } else if isOutline {
                    value = 20
                } else {
                    value = 255
                }
                bytes[offset] = value
                bytes[offset + 1] = value
                bytes[offset + 2] = value
                bytes[offset + 3] = 255
            }
        }
        let cyanOffset = (3 * 7 + 3) * 4
        bytes[cyanOffset] = 0
        bytes[cyanOffset + 1] = 220
        bytes[cyanOffset + 2] = 235

        let result = SpriteBackgroundRemoval.clearEdgeConnectedNeutralBackground(
            in: SpriteRGBAImage(width: 7, height: 7, bytes: bytes)
        )

        XCTAssertEqual(Array(result.bytes[0..<4]), [0, 0, 0, 0])
        let enclosedWhiteOffset = (2 * 7 + 2) * 4
        XCTAssertEqual(result.bytes[enclosedWhiteOffset + 3], 255)
        XCTAssertEqual(result.bytes[cyanOffset + 3], 255)
    }

    func testContentBoundsIgnoreFarNoiseAndKeepNearbyParticle() {
        var bytes = Array(repeating: UInt8(0), count: 12 * 12 * 4)
        for y in 2...8 {
            for x in 3...7 {
                bytes[(y * 12 + x) * 4 + 3] = 255
            }
        }
        bytes[(7 * 12 + 9) * 4 + 3] = 255
        bytes[(11 * 12) * 4 + 3] = 255

        let bounds = SpriteAlphaGeometry.contentBounds(
            in: SpriteRGBAImage(width: 12, height: 12, bytes: bytes),
            nearbyDistance: 2
        )

        XCTAssertEqual(bounds, CGRect(x: 3, y: 2, width: 7, height: 7))
    }
}
