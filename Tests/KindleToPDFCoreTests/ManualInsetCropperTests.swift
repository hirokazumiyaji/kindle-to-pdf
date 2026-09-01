import CoreGraphics
import XCTest
@testable import KindleToPDFCore

final class ManualInsetCropperTests: XCTestCase {
    func testAppliesInsetsFromAllSides() {
        let image = makeImage(width: 10, height: 10, fill: .white, rectangles: [
            (CGRect(x: 0, y: 0, width: 10, height: 10), .darkGray),
            (CGRect(x: 2, y: 2, width: 6, height: 6), .black)
        ])
        let cropped = ManualInsetCropper().crop(
            image,
            insets: CropInsets(top: 2, bottom: 2, left: 2, right: 2)
        )
        XCTAssertEqual(cropped.width, 6)
        XCTAssertEqual(cropped.height, 6)
    }

    func testReturnsOriginalWhenInsetsAreZero() {
        let image = makeImage(width: 8, height: 8, fill: .white, rectangles: [])
        let cropped = ManualInsetCropper().crop(image, insets: .zero)
        XCTAssertEqual(cropped.width, 8)
        XCTAssertEqual(cropped.height, 8)
    }

    func testClampsInsetsThatWouldEmptyTheImage() {
        let image = makeImage(width: 4, height: 4, fill: .white, rectangles: [])
        let cropped = ManualInsetCropper().crop(
            image,
            insets: CropInsets(top: 3, bottom: 3, left: 3, right: 3)
        )
        XCTAssertGreaterThanOrEqual(cropped.width, 1)
        XCTAssertGreaterThanOrEqual(cropped.height, 1)
    }
}
