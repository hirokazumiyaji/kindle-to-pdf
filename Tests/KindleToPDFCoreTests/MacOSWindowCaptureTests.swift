import CoreGraphics
import XCTest
@testable import KindleToPDFCore

final class MacOSWindowCaptureTests: XCTestCase {
    func testCropsCapturedWindowImage() throws {
        let image = makeImage(
            width: 10,
            height: 10,
            fill: .darkGray,
            rectangles: [
                (CGRect(x: 2, y: 2, width: 6, height: 6), .white),
                (CGRect(x: 4, y: 4, width: 2, height: 2), .black)
            ]
        )
        let capture = MacOSWindowCapture(imageProvider: { windowID in
            windowID == 42 ? image : nil
        })
        let window = KindleWindow(windowID: 42, processID: 1, title: "Kindle", bounds: .zero)

        let captured = try capture.capture(window: window)

        XCTAssertEqual(captured.width, 6)
        XCTAssertEqual(captured.height, 6)
    }

    func testAppliesManualInsetsAfterEdgeCrop() throws {
        let image = makeImage(
            width: 10,
            height: 10,
            fill: .darkGray,
            rectangles: [
                (CGRect(x: 2, y: 2, width: 6, height: 6), .white),
                (CGRect(x: 4, y: 4, width: 2, height: 2), .black)
            ]
        )
        let capture = MacOSWindowCapture(
            imageProvider: { windowID in
                windowID == 42 ? image : nil
            },
            insets: CropInsets(top: 1, bottom: 1, left: 1, right: 1)
        )
        let window = KindleWindow(windowID: 42, processID: 1, title: "Kindle", bounds: .zero)

        let captured = try capture.capture(window: window)

        XCTAssertEqual(captured.width, 4)
        XCTAssertEqual(captured.height, 4)
    }

    func testThrowsUnableToCaptureWindowWhenProviderReturnsNil() {
        let capture = MacOSWindowCapture(imageProvider: { _ in nil })
        let window = KindleWindow(windowID: 42, processID: 1, title: "Kindle", bounds: .zero)

        XCTAssertThrowsError(try capture.capture(window: window)) { error in
            XCTAssertEqual(error as? PlatformError, .unableToCaptureWindow(42))
        }
    }
}
