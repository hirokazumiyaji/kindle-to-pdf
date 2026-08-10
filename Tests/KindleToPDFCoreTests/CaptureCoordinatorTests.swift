import CoreGraphics
import Foundation
import XCTest
@testable import KindleToPDFCore

final class CaptureCoordinatorTests: XCTestCase {
    func testCapturesCurrentPageThenTurnsForRemainingPages() throws {
        let fixture = try CaptureFixture(images: [.black, .white, .white, .black, .black])
        let options = fixture.options(pageCount: 3)

        try fixture.coordinator.run(options: options, stopRequested: { false })

        XCTAssertEqual(fixture.pageTurner.turnCount, 2)
        XCTAssertEqual(fixture.savedPageCount, 3)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 3)
    }

    func testStopsWithoutSavingDuplicateWhenPageDoesNotChange() throws {
        let fixture = try CaptureFixture(images: [.black, .black])
        let options = fixture.options(pageCount: 2)

        XCTAssertThrowsError(try fixture.coordinator.run(
            options: options,
            stopRequested: { false }
        ))

        XCTAssertEqual(fixture.savedPageCount, 1)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 0)
    }

    func testResumeUsesTheNextPageAfterSavedPages() throws {
        let fixture = try CaptureFixture(images: [.white, .white])
        try fixture.seedSession(capturedPageCount: 1)

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2, resume: true),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual(fixture.pageTurner.turnCount, 1)
    }
}

private struct AllowingPermissionChecker: PermissionChecking {
    func check() throws {}
}

private struct FixtureWindowLocator: WindowLocating {
    let window = KindleWindow(windowID: 1, processID: 2, title: "Kindle", bounds: .zero)

    func locate(title: String?) throws -> KindleWindow {
        window
    }
}

private final class RecordingPageTurner: PageTurning {
    private(set) var turnCount = 0

    func turn(window: KindleWindow, key: NextKey) throws {
        turnCount += 1
    }
}

private final class RecordingPDFWriter: PDFWriting {
    private(set) var writtenImageCount = 0

    func write(imageURLs: [URL], to outputURL: URL) throws {
        writtenImageCount = imageURLs.count
    }
}

private final class FixtureWindowCapture: WindowCapturing {
    private let images: [CGImage]
    private var index = 0

    init(images: [CGImage]) {
        self.images = images
    }

    func capture(window: KindleWindow) throws -> CGImage {
        let image = images[min(index, images.count - 1)]
        index += 1
        return image
    }
}

private struct NoOpSleeper: Sleeper {
    func sleep(for duration: TimeInterval) throws {}
}

private final class CaptureFixture {
    let outputURL: URL
    let sessionURL: URL
    let store: SessionStore
    let pageTurner = RecordingPageTurner()
    let pdfWriter = RecordingPDFWriter()
    let coordinator: CaptureCoordinator

    init(images: [FixtureColor]) throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        outputURL = rootURL.appendingPathComponent("book.pdf")
        sessionURL = rootURL.appendingPathComponent("book.kindle-session")
        store = SessionStore(rootURL: sessionURL)
        let capturedImages = try images.map { try makeImage(color: $0) }
        coordinator = CaptureCoordinator(
            windowLocator: FixtureWindowLocator(),
            permissionChecker: AllowingPermissionChecker(),
            pageTurner: pageTurner,
            windowCapture: FixtureWindowCapture(images: capturedImages),
            imageCodec: PNGImageCodec(),
            imageChangeDetector: ImageChangeDetector(changedPixelRatio: 0.01),
            pdfWriter: pdfWriter,
            sleeper: NoOpSleeper()
        )
    }

    func options(pageCount: Int, resume: Bool = false) -> CaptureOptions {
        CaptureOptions(
            outputURL: outputURL,
            pageCount: pageCount,
            windowTitle: nil,
            nextKey: .right,
            sessionURL: sessionURL,
            resume: resume,
            overwrite: false
        )
    }

    func seedSession(capturedPageCount: Int) throws {
        let page = try PNGImageCodec().encode(try makeImage(color: .black))
        try store.savePage(page, index: 1)
        try store.save(SessionState(
            schemaVersion: 1,
            outputPath: outputURL.path,
            requestedPageCount: 2,
            capturedPageCount: capturedPageCount,
            windowTitle: "Kindle",
            windowID: 1,
            processID: 2,
            lastImageHash: nil,
            status: .capturing
        ))
    }

    var savedPageCount: Int {
        (try? store.load().capturedPageCount) ?? 0
    }
}
