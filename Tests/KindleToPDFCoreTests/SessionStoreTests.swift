import Foundation
import XCTest
@testable import KindleToPDFCore

final class SessionStoreTests: XCTestCase {
    func testSavesAndLoadsStateAndPage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = SessionStore(rootURL: root)
        let state = SessionState(
            schemaVersion: 1,
            outputPath: "/tmp/book.pdf",
            requestedPageCount: 2,
            capturedPageCount: 1,
            windowTitle: "Kindle",
            windowID: 42,
            processID: 99,
            lastImageHash: "abc",
            status: .capturing
        )

        try store.save(state)
        try store.savePage(Data([1, 2, 3]), index: 1)

        XCTAssertEqual(try store.load(), state)
        XCTAssertEqual(try Data(contentsOf: store.pageURL(index: 1)), Data([1, 2, 3]))
    }

    func testReturnsNaturalPageOrder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = SessionStore(rootURL: root)

        XCTAssertEqual(
            store.pageURLs(count: 3).map(\.lastPathComponent),
            ["0001.png", "0002.png", "0003.png"]
        )
    }
}
