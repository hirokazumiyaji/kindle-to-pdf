import CoreGraphics

public struct ManualInsetCropper {
    public init() {}

    public func crop(_ image: CGImage, insets: CropInsets) -> CGImage {
        guard !insets.isZero else { return image }
        let maxLeftRight = max(0, image.width - 1)
        let maxTopBottom = max(0, image.height - 1)
        let left = min(insets.left, maxLeftRight)
        let right = min(insets.right, maxLeftRight - left)
        let top = min(insets.top, maxTopBottom)
        let bottom = min(insets.bottom, maxTopBottom - top)
        let rect = CGRect(
            x: left,
            y: top,
            width: image.width - left - right,
            height: image.height - top - bottom
        )
        return image.cropping(to: rect) ?? image
    }
}
