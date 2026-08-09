import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum MediaError: Error, Equatable, CustomStringConvertible {
    case unableToEncodeImage
    case unableToDecodeImage
    case emptyPDFInput
    case invalidPDFImage(URL)
    case unableToWritePDF(URL)

    public var description: String {
        switch self {
        case .unableToEncodeImage:
            return "画像をPNGへ変換できません。"
        case .unableToDecodeImage:
            return "PNG画像を読み込めません。"
        case .emptyPDFInput:
            return "PDFへ変換する画像がありません。"
        case let .invalidPDFImage(url):
            return "PDFへ変換できない画像です: \(url.path)"
        case let .unableToWritePDF(url):
            return "PDFを書き込めません: \(url.path)"
        }
    }
}

public struct PNGImageCodec {
    public init() {}

    public func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaError.unableToEncodeImage
        }
        let properties = [kCGImagePropertyOrientation: 1] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaError.unableToEncodeImage
        }
        return data as Data
    }

    public func decode(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw MediaError.unableToDecodeImage
        }
        return image
    }
}
