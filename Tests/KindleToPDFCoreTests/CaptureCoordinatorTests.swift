import CoreGraphics
import Foundation
import XCTest
@testable import KindleToPDFCore

final class CaptureCoordinatorTests: XCTestCase {
    func testCapturesCurrentPageThenTurnsForRemainingPages() throws {
        let fixture = try CaptureFixture(images: [.black, .white, .white, .black, .black])
        let options = fixture.options(pageCount: 3)

        try fixture.coordinator.run(options: options, stopRequested: { false })

        XCTAssertEqual((fixture.pageTurner as! RecordingPageTurner).turnCount, 2)
        XCTAssertEqual(fixture.savedPageCount, 3)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 3)
    }

    func testStopsWithoutSavingDuplicateWhenPageDoesNotChange() throws {
        let fixture = try CaptureFixture(images: [.black, .black])
        let options = fixture.options(pageCount: 2)

        try fixture.coordinator.run(
            options: options,
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 1)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 1)
    }

    func testWaitsForPageThatTakesLongerThanFiveSecondsToRender() throws {
        var transitionImages: [CGImage] = [try makeImage(color: .black)]
        for index in 0..<20 {
            let color = FixtureRGB(
                red: UInt8(20 + index),
                green: UInt8(40 + index),
                blue: UInt8(60 + index)
            )
            transitionImages.append(makeImage(width: 2, height: 2, fill: color, rectangles: []))
        }
        transitionImages.append(contentsOf: [
            try makeImage(color: .white),
            try makeImage(color: .white)
        ])
        let fixture = CaptureFixture(capturedImages: transitionImages)

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 2)
    }

    func testResumeUsesTheNextPageAfterSavedPages() throws {
        let fixture = try CaptureFixture(images: [.white, .white])
        try fixture.seedSession(capturedPageCount: 1)

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2, resume: true),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual((fixture.pageTurner as! RecordingPageTurner).turnCount, 1)
    }

    func testRetriesPageTurnWhenImageDoesNotChangeInitially() throws {
        let shared = TurnGate(turnsBeforeChange: 2)
        let fixture = CaptureFixture(
            capture: TurnGatedWindowCapture(gate: shared, before: try makeImage(color: .black), after: try makeImage(color: .white)),
            pageTurner: GatedPageTurner(gate: shared)
        )

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2),
            stopRequested: { false }
        )

        XCTAssertEqual(shared.turnCount, 2)
        XCTAssertEqual(fixture.savedPageCount, 2)
    }

    func testActivatesApplicationBeforeEachPageTurn() throws {
        let fixture = try CaptureFixture(images: [.black, .white, .white, .black, .black])
        let activator = fixture.applicationActivator

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 3),
            stopRequested: { false }
        )

        XCTAssertEqual(activator.activatedProcessIDs, [2, 2])
    }

    func testGivesUpAfterExhaustingPageTurnRetries() throws {
        let shared = TurnGate(turnsBeforeChange: 100)
        let fixture = CaptureFixture(
            capture: TurnGatedWindowCapture(gate: shared, before: try makeImage(color: .black), after: try makeImage(color: .white)),
            pageTurner: GatedPageTurner(gate: shared)
        )

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 1)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 1)
        XCTAssertGreaterThanOrEqual(shared.turnCount, 3)
    }

    func testSwitchesToLeftWhenRightDoesNotAdvance() throws {
        let gate = KeySensitiveGate(workingKey: .left)
        let fixture = CaptureFixture(
            capture: KeyGatedWindowCapture(gate: gate, before: try makeImage(color: .black), after: try makeImage(color: .white)),
            pageTurner: KeyGatedPageTurner(gate: gate)
        )

        try fixture.coordinator.run(
            options: fixture.options(pageCount: 2),
            stopRequested: { false }
        )

        XCTAssertTrue(gate.keys.contains(.right))
        XCTAssertTrue(gate.keys.contains(.left))
        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 2)
    }

    func testCompletesWhenPageStopsChangingWithoutPageLimit() throws {
        let fixture = try CaptureFixture(images: [.black, .white, .white, .white])

        try fixture.coordinator.run(
            options: fixture.options(pageCount: nil),
            stopRequested: { false }
        )

        XCTAssertEqual(fixture.savedPageCount, 2)
        XCTAssertEqual(fixture.pdfWriter.writtenImageCount, 2)
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

private final class RecordingApplicationActivator: ApplicationActivating {
    private(set) var activatedProcessIDs: [Int32] = []

    func activate(processID: Int32) throws {
        activatedProcessIDs.append(processID)
    }
}

private final class TurnGate {
    private let turnsBeforeChange: Int
    private(set) var turnCount = 0

    init(turnsBeforeChange: Int) {
        self.turnsBeforeChange = turnsBeforeChange
    }

    func recordTurn() {
        turnCount += 1
    }

    var hasChanged: Bool {
        turnCount >= turnsBeforeChange
    }
}

private final class GatedPageTurner: PageTurning {
    private let gate: TurnGate

    init(gate: TurnGate) {
        self.gate = gate
    }

    func turn(window: KindleWindow, key: NextKey) throws {
        gate.recordTurn()
    }
}

private final class TurnGatedWindowCapture: WindowCapturing {
    private let gate: TurnGate
    private let before: CGImage
    private let after: CGImage
    private var afterChangeSamples = 0

    init(gate: TurnGate, before: CGImage, after: CGImage) {
        self.gate = gate
        self.before = before
        self.after = after
    }

    func capture(window: KindleWindow) throws -> CGImage {
        if gate.hasChanged {
            afterChangeSamples += 1
            return after
        }
        return before
    }
}

private final class KeySensitiveGate {
    let workingKey: NextKey
    private(set) var keys: [NextKey] = []
    private var workingTurnCount = 0

    init(workingKey: NextKey) {
        self.workingKey = workingKey
    }

    func record(_ key: NextKey) {
        keys.append(key)
        if key == workingKey {
            workingTurnCount += 1
        }
    }

    var hasChanged: Bool {
        workingTurnCount >= 1
    }
}

private final class KeyGatedPageTurner: PageTurning {
    private let gate: KeySensitiveGate

    init(gate: KeySensitiveGate) {
        self.gate = gate
    }

    func turn(window: KindleWindow, key: NextKey) throws {
        gate.record(key)
    }
}

private final class KeyGatedWindowCapture: WindowCapturing {
    private let gate: KeySensitiveGate
    private let before: CGImage
    private let after: CGImage

    init(gate: KeySensitiveGate, before: CGImage, after: CGImage) {
        self.gate = gate
        self.before = before
        self.after = after
    }

    func capture(window: KindleWindow) throws -> CGImage {
        gate.hasChanged ? after : before
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
    let pageTurner: PageTurning
    let applicationActivator: RecordingApplicationActivator
    let pdfWriter = RecordingPDFWriter()
    let coordinator: CaptureCoordinator

    convenience init(images: [FixtureColor]) throws {
        self.init(capturedImages: try images.map { try makeImage(color: $0) })
    }

    convenience init(capturedImages: [CGImage]) {
        self.init(
            capture: FixtureWindowCapture(images: capturedImages),
            pageTurner: RecordingPageTurner()
        )
    }

    init(capture: WindowCapturing, pageTurner: PageTurning) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        outputURL = rootURL.appendingPathComponent("book.pdf")
        sessionURL = rootURL.appendingPathComponent("book.kindle-session")
        store = SessionStore(rootURL: sessionURL)
        self.pageTurner = pageTurner
        applicationActivator = RecordingApplicationActivator()
        coordinator = CaptureCoordinator(
            windowLocator: FixtureWindowLocator(),
            permissionChecker: AllowingPermissionChecker(),
            pageTurner: pageTurner,
            applicationActivator: applicationActivator,
            windowCapture: capture,
            imageCodec: PNGImageCodec(),
            imageChangeDetector: ImageChangeDetector(changedPixelRatio: 0.01),
            pdfWriter: pdfWriter,
            sleeper: NoOpSleeper()
        )
    }

    func options(pageCount: Int?, resume: Bool = false) -> CaptureOptions {
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
