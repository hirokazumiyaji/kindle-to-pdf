import AppKit
import Foundation
import PDFKit

public protocol PDFWriting {
    func write(imageURLs: [URL], to outputURL: URL) throws
}

public struct PDFWriter: PDFWriting {
    private let codec: PNGImageCodec

    public init(codec: PNGImageCodec = PNGImageCodec()) {
        self.codec = codec
    }

    public func write(imageURLs: [URL], to outputURL: URL) throws {
        guard !imageURLs.isEmpty else {
            throw MediaError.emptyPDFInput
        }

        let document = PDFDocument()
        for (index, imageURL) in imageURLs.enumerated() {
            let image: CGImage
            do {
                image = try codec.decode(Data(contentsOf: imageURL))
            } catch {
                throw MediaError.invalidPDFImage(imageURL)
            }
            let size = NSSize(width: image.width, height: image.height)
            guard let page = PDFPage(image: NSImage(cgImage: image, size: size)) else {
                throw MediaError.invalidPDFImage(imageURL)
            }
            document.insert(page, at: index)
        }

        let parentURL = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentURL,
            withIntermediateDirectories: true
        )
        let temporaryURL = parentURL.appendingPathComponent(
            ".\(outputURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        guard document.write(to: temporaryURL) else {
            throw MediaError.unableToWritePDF(outputURL)
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    }
}
