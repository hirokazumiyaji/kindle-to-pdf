import XCTest
@testable import KindleToPDFCore

final class ImageChangeDetectorTests: XCTestCase {
    func testDetectsDifferentPixels() throws {
        let detector = ImageChangeDetector(changedPixelRatio: 0.01)
        let first = try makeImage(color: .black)
        let second = try makeImage(color: .white)

        XCTAssertTrue(try detector.hasChanged(first, second))
    }

    func testRequiresStableSamples() throws {
        let detector = ImageChangeDetector()
        let image = try makeImage(color: .black)

        XCTAssertTrue(try detector.isStable([image, image, image]))
    }
}
