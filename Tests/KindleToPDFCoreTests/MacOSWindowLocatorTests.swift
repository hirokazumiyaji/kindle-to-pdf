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
}
