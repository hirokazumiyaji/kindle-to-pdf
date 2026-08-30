import CoreGraphics
import XCTest
@testable import KindleToPDFCore

final class EdgeBackgroundCropperTests: XCTestCase {
    func testKeepsFullFramePageWithCenteredContent() throws {
        let image = makeImage(
            width: 8,
            height: 8,
            fill: .white,
            rectangles: [(CGRect(x: 3, y: 3, width: 2, height: 2), .black)]
        )

        let cropped = EdgeBackgroundCropper().crop(image)

        XCTAssertEqual(cropped.width, 8)
        XCTAssertEqual(cropped.height, 8)
    }

    func testRemovesOuterBackgroundAndPreservesPageMargin() throws {
        let image = makeImage(
            width: 10,
            height: 10,
            fill: .darkGray,
            rectangles: [
                (CGRect(x: 1, y: 3, width: 6, height: 6), .white),
                (CGRect(x: 2, y: 5, width: 2, height: 1), .black)
            ]
        )

        let cropped = EdgeBackgroundCropper().crop(image)

        XCTAssertEqual(cropped.width, 6)
        XCTAssertEqual(cropped.height, 6)
        XCTAssertEqual(imagePixel(cropped, x: 0, y: 0), .white)
        XCTAssertEqual(imagePixel(cropped, x: 1, y: 1), .white)
        XCTAssertEqual(imagePixel(cropped, x: 1, y: 2), .black)
        XCTAssertEqual(imagePixel(cropped, x: 2, y: 2), .black)
        XCTAssertEqual(imagePixel(cropped, x: 3, y: 2), .white)
        XCTAssertEqual(imagePixel(cropped, x: 1, y: 3), .white)
        XCTAssertEqual(imagePixel(cropped, x: 5, y: 5), .white)
    }

    func testReturnsOriginalWhenCornerBackgroundIsInconsistent() throws {
        let image = makeImage(
            width: 8,
            height: 8,
            fill: .darkGray,
            rectangles: [(CGRect(x: 0, y: 0, width: 1, height: 1), .white)]
        )

        let cropped = EdgeBackgroundCropper().crop(image)

        XCTAssertEqual(cropped.width, image.width)
        XCTAssertEqual(cropped.height, image.height)
    }

    func testReturnsOriginalWhenImageContainsOnlyBackground() throws {
        let image = makeImage(width: 8, height: 8, fill: .darkGray, rectangles: [])

        let cropped = EdgeBackgroundCropper().crop(image)

        XCTAssertEqual(cropped.width, image.width)
        XCTAssertEqual(cropped.height, image.height)
    }
}
