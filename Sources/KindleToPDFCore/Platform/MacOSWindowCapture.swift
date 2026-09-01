import CoreGraphics

public struct MacOSWindowCapture: WindowCapturing {
    private let imageProvider: (CGWindowID) -> CGImage?
    private let cropper: EdgeBackgroundCropper
    private let manualCropper: ManualInsetCropper
    private let insets: CropInsets?

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
        cropper: EdgeBackgroundCropper = EdgeBackgroundCropper(),
        manualCropper: ManualInsetCropper = ManualInsetCropper(),
        insets: CropInsets? = nil
    ) {
        self.imageProvider = imageProvider
        self.cropper = cropper
        self.manualCropper = manualCropper
        self.insets = insets
    }

    public func capture(window: KindleWindow) throws -> CGImage {
        guard let image = imageProvider(CGWindowID(window.windowID)) else {
            throw PlatformError.unableToCaptureWindow(window.windowID)
        }
        let cropped = cropper.crop(image)
        if let insets, !insets.isZero {
            return manualCropper.crop(cropped, insets: insets)
        }
        return cropped
    }
}
