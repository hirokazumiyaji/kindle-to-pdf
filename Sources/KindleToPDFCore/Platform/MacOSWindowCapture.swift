import CoreGraphics

public struct MacOSWindowCapture: WindowCapturing {
    private let imageProvider: (CGWindowID) -> CGImage?
    private let cropper: EdgeBackgroundCropper
    private let manualCropper: ManualInsetCropper
    private let insets: CropInsets?
    private let edgeCropEnabled: Bool

    public init() {
        self.init(imageProvider: Self.defaultImageProvider)
    }

    public init(edgeCropEnabled: Bool, insets: CropInsets? = nil) {
        self.init(
            imageProvider: Self.defaultImageProvider,
            insets: insets,
            edgeCropEnabled: edgeCropEnabled
        )
    }

    init(
        imageProvider: @escaping (CGWindowID) -> CGImage?,
        cropper: EdgeBackgroundCropper = EdgeBackgroundCropper(),
        manualCropper: ManualInsetCropper = ManualInsetCropper(),
        insets: CropInsets? = nil,
        edgeCropEnabled: Bool = true
    ) {
        self.imageProvider = imageProvider
        self.cropper = cropper
        self.manualCropper = manualCropper
        self.insets = insets
        self.edgeCropEnabled = edgeCropEnabled
    }

    public func capture(window: KindleWindow) throws -> CGImage {
        guard let image = imageProvider(CGWindowID(window.windowID)) else {
            throw PlatformError.unableToCaptureWindow(window.windowID)
        }
        let prepared = edgeCropEnabled ? cropper.crop(image) : image
        if let insets, !insets.isZero {
            return manualCropper.crop(prepared, insets: insets)
        }
        return prepared
    }

    private static let defaultImageProvider: (CGWindowID) -> CGImage? = { windowID in
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }
}
