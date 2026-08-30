import XCTest
@testable import KindleToPDFCore

final class CLIParserTests: XCTestCase {
    func testParsesCaptureOptions() throws {
        let command = try CLIParser.parse([
            "capture", "--output", "book.pdf", "--pages", "3",
            "--window", "My book", "--next-key", "pagedown",
            "--session", "book-session", "--resume", "--overwrite"
        ])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: 3,
            windowTitle: "My book",
            nextKey: .pagedown,
            sessionURL: URL(fileURLWithPath: "book-session"),
            resume: true,
            overwrite: true
        )))
    }

    func testAllowsMissingPageCount() throws {
        let command = try CLIParser.parse(["capture", "--output", "book.pdf"])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: nil,
            windowTitle: nil,
            nextKey: .right,
            sessionURL: nil,
            resume: false,
            overwrite: false
        )))
    }

    func testParsesLeftNextKey() throws {
        let command = try CLIParser.parse([
            "capture", "--output", "book.pdf", "--next-key", "left"
        ])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: nil,
            windowTitle: nil,
            nextKey: .left,
            sessionURL: nil,
            resume: false,
            overwrite: false
        )))
    }

    func testUsesRightKeyAndNoOptionalFlagsByDefault() throws {
        let command = try CLIParser.parse([
            "capture", "--output", "book.pdf", "--pages", "1"
        ])

        XCTAssertEqual(command, .capture(CaptureOptions(
            outputURL: URL(fileURLWithPath: "book.pdf"),
            pageCount: 1,
            windowTitle: nil,
            nextKey: .right,
            sessionURL: nil,
            resume: false,
            overwrite: false
        )))
    }
}
