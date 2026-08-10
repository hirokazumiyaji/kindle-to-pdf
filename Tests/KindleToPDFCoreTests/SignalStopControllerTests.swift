import XCTest
@testable import KindleToPDFCore

final class SignalStopControllerTests: XCTestCase {
    func testStartsNotRequestedAndCanBeRequested() {
        let controller = SignalStopController()

        XCTAssertFalse(controller.isRequested)
        controller.requestStop()
        XCTAssertTrue(controller.isRequested)
    }
}
