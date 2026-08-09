import CoreGraphics
import Foundation

enum FixtureColor: Equatable {
    case black
    case white
}

func makeImage(color: FixtureColor) throws -> CGImage {
    let value: UInt8 = color == .black ? 0 : 255
    var pixels = Array(repeating: value, count: 2 * 2 * 4)
    for index in stride(from: 3, to: pixels.count, by: 4) {
        pixels[index] = 255
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: 2,
        height: 2,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 8,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}
