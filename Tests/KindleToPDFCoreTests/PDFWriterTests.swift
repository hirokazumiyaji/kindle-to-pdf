import Foundation
import PDFKit
import XCTest
@testable import KindleToPDFCore

final class PDFWriterTests: XCTestCase {
    func testWritesOnePDFPagePerPNG() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let codec = PNGImageCodec()
        let firstURL = directory.appendingPathComponent("0001.png")
        let secondURL = directory.appendingPathComponent("0002.png")
        try codec.encode(try makeImage(color: .black)).write(to: firstURL)
        try codec.encode(try makeImage(color: .white)).write(to: secondURL)
        let output = directory.appendingPathComponent("book.pdf")

        try PDFWriter().write(imageURLs: [firstURL, secondURL], to: output)

        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 2)
    }
}
