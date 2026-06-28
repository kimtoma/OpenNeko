import CoreGraphics

public enum CatLayoutMetrics {
    public static let spriteFrameLength: CGFloat = 128
    public static let floorPadding: CGFloat = 2

    public static var primaryCatSize: CGSize {
        CGSize(width: spriteFrameLength, height: spriteFrameLength)
    }

    public static var guestCatSize: CGSize {
        primaryCatSize
    }
}
