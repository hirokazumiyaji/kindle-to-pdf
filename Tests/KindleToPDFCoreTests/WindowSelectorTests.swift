import CoreGraphics
import XCTest
@testable import KindleToPDFCore

final class WindowSelectorTests: XCTestCase {
    func testSelectsTheOnlyKindleWindow() throws {
        let windows = [KindleWindow(
            windowID: 1, processID: 2, title: "Kindle - Book", bounds: .zero
        )]

        XCTAssertEqual(try WindowSelector.select(from: windows, title: nil), windows[0])
    }

    func testRejectsAmbiguousWindowsWithoutTitle() {
        let windows = [
            KindleWindow(windowID: 1, processID: 2, title: "Book A", bounds: .zero),
            KindleWindow(windowID: 3, processID: 4, title: "Book B", bounds: .zero)
        ]

        XCTAssertThrowsError(try WindowSelector.select(from: windows, title: nil))
    }
}
