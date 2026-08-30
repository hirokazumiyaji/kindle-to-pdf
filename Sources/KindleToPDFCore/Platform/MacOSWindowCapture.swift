import CoreGraphics

public struct MacOSWindowCapture: WindowCapturing {
    private let imageProvider: (CGWindowID) -> CGImage?
    private let cropper: EdgeBackgroundCropper

    public init() {
        self.init(imageProvider: { windowID in
            CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.bestResolution, .boundsIgnoreFraming]
            )
        })
    }

    init(
        imageProvider: @escaping (CGWindowID) -> CGImage?,
        cropper: EdgeBackgroundCropper = EdgeBackgroundCropper()
    ) {
        self.imageProvider = imageProvider
        self.cropper = cropper
    }

    public func capture(window: KindleWindow) throws -> CGImage {
        guard let image = imageProvider(CGWindowID(window.windowID)) else {
            throw PlatformError.unableToCaptureWindow(window.windowID)
        }
        return cropper.crop(image)
    }
}
