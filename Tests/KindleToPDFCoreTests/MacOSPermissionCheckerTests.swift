import XCTest
@testable import KindleToPDFCore

final class MacOSPermissionCheckerTests: XCTestCase {
    func testReportsTheExecutableThatNeedsPermission() {
        let checker = MacOSPermissionChecker(
            executablePath: "/Users/test/KindleToPDF.app",
            accessibilityTrusted: { false },
            screenCaptureAuthorized: { false },
            requestScreenCapture: { false }
        )

        XCTAssertThrowsError(try checker.check()) { error in
            guard case let PlatformError.missingPermissions(permissions) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            let message = permissions.joined(separator: " ")
            XCTAssertTrue(message.contains("/Users/test/KindleToPDF.app"))
        }
    }

    func testRequestsScreenCaptureBeforeReportingItMissing() {
        var requestCount = 0
        let checker = MacOSPermissionChecker(
            executablePath: "/Users/test/KindleToPDF.app",
            accessibilityTrusted: { true },
            screenCaptureAuthorized: { false },
            requestScreenCapture: {
                requestCount += 1
                return false
            }
        )

        XCTAssertThrowsError(try checker.check())
        XCTAssertEqual(requestCount, 1)
    }
}
