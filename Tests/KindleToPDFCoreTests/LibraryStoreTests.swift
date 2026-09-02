import Foundation
import XCTest
@testable import KindleToPDFCore

final class LibraryStoreTests: XCTestCase {
    func testCreatesLayoutAndSavesEntry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LibraryStore(rootURL: root)
        try store.ensureLayout()
        var entry = store.makeNewEntry(displayName: "Sample", requestedPageCount: 10)
        entry.status = .scanning
        try store.save(entry)

        let loaded = try store.load(id: entry.id)
        XCTAssertEqual(loaded.displayName, "Sample")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.paths.entryURL(for: entry.id).path))
    }

    func testListsNewestFirstAndDeletesArtifacts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LibraryStore(rootURL: root)
        try store.ensureLayout()
        let first = store.makeNewEntry(displayName: "A", requestedPageCount: nil)
        try store.save(first)
        Thread.sleep(forTimeInterval: 0.01)
        var second = store.makeNewEntry(displayName: "B", requestedPageCount: nil)
        second.status = .completed
        try store.save(second)
        // create dummy session + pdf files
        let sessionURL = store.paths.sessionURL(for: second.id)
        try FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        try Data().write(to: sessionURL.appendingPathComponent("state.json"))
        try Data().write(to: store.paths.pdfURL(for: second.id))

        XCTAssertEqual(try store.list().map(\.displayName), ["B", "A"])
        try store.delete(id: second.id)
        XCTAssertEqual(try store.list().map(\.displayName), ["A"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.paths.pdfURL(for: second.id).path))
    }

    func testSaveDoesNotCreateSessionDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LibraryStore(rootURL: root)
        let entry = store.makeNewEntry(displayName: "Sample", requestedPageCount: nil)

        try store.save(entry)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: store.paths.sessionURL(for: entry.id).path),
            "LibraryStore.save must not create Sessions/<id>; CaptureCoordinator treats an existing session dir as sessionAlreadyExists"
        )
    }
}
