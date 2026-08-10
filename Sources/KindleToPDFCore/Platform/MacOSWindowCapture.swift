import CoreGraphics

public struct MacOSWindowCapture: WindowCapturing {
    public init() {}

    public func capture(window: KindleWindow) throws -> CGImage {
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowID),
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            throw PlatformError.unableToCaptureWindow(window.windowID)
        }
        return image
    }
}
