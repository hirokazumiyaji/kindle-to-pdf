import CoreGraphics
import Foundation

enum FixtureColor: Equatable {
    case black
    case white
}

struct FixtureRGB: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let darkGray = FixtureRGB(red: 64, green: 64, blue: 64)
    static let white = FixtureRGB(red: 255, green: 255, blue: 255)
    static let black = FixtureRGB(red: 0, green: 0, blue: 0)
}

func makeImage(
    width: Int,
    height: Int,
    fill: FixtureRGB,
    rectangles: [(CGRect, FixtureRGB)]
) -> CGImage {
    var pixels = Array(repeating: UInt8(255), count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let color = rectangles.reduce(fill) { current, rectangle in
                rectangle.0.contains(CGPoint(x: x, y: y)) ? rectangle.1 : current
            }
            let offset = (y * width + x) * 4
            pixels[offset] = color.red
            pixels[offset + 1] = color.green
            pixels[offset + 2] = color.blue
        }
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

func imagePixel(_ image: CGImage, x: Int, y: Int) -> FixtureRGB {
    var pixels = Array(repeating: UInt8(0), count: image.width * image.height * 4)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: &pixels,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

    let offset = (y * image.width + x) * 4
    return FixtureRGB(red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
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
