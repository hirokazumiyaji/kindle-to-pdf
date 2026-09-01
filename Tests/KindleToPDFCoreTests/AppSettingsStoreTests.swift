import Foundation
import XCTest
@testable import KindleToPDFCore

final class AppSettingsStoreTests: XCTestCase {
    func testLoadsDefaultsWhenMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = LibraryPaths(rootURL: root)
        try FileManager.default.createDirectory(at: paths.settingsURL, withIntermediateDirectories: true)
        let store = AppSettingsStore(paths: paths)
        let settings = try store.load()
        XCTAssertEqual(settings.defaultNextKey, .right)
        XCTAssertTrue(settings.autoCropEnabled)
    }

    func testRoundTripsSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = LibraryPaths(rootURL: root)
        try LibraryStore(rootURL: root).ensureLayout()
        let store = AppSettingsStore(paths: paths)
        var settings = AppSettings.default
        settings.defaultNextKey = .left
        settings.defaultPageCount = 50
        settings.globalCropInsets = CropInsets(top: 1, bottom: 2, left: 3, right: 4)
        try store.save(settings)
        XCTAssertEqual(try store.load(), settings)
    }
}
