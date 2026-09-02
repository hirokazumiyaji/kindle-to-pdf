import CoreGraphics
import XCTest
@testable import KindleToPDFCore

final class MacOSWindowLocatorTests: XCTestCase {
    func testRecognizesCurrentAmazonKindleApplication() {
        XCTAssertTrue(
            KindleApplicationMatcher.matches(
                localizedName: "Amazon Kindle",
                bundleIdentifier: "com.amazon.Lassen"
            )
        )
    }

    func testEnumeratesWindowsOutsideTheActiveDesktop() {
        XCTAssertFalse(MacOSWindowLocator.windowListOptions.contains(.optionOnScreenOnly))
        XCTAssertTrue(MacOSWindowLocator.windowListOptions.contains(.excludeDesktopElements))
    }

    func testKindleWindowFilterDropsTitleBarStripAndKeepsMainWindow() {
        let titleBar = KindleWindow(
            windowID: 1,
            processID: 2,
            title: "",
            bounds: CGRect(x: 0, y: 0, width: 1470, height: 33)
        )
        let mainWindow = KindleWindow(
            windowID: 3,
            processID: 2,
            title: "Kindle - Book",
            bounds: CGRect(x: 0, y: 0, width: 1470, height: 1084)
        )

        XCTAssertEqual(
            KindleWindowFilter.contentWindows(from: [titleBar, mainWindow]),
            [mainWindow]
        )
    }
}
