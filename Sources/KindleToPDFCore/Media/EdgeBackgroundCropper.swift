import CoreGraphics

public struct EdgeBackgroundCropper {
    private static let tolerance = 16
    private static let backgroundRatio = 0.995
    private static let minimumContentRatio = 0.5

    public init() {}

    public func crop(_ image: CGImage) -> CGImage {
        guard image.width >= 2, image.height >= 2,
              let pixels = normalizedPixels(from: image) else {
            return image
        }

        let corners = [
            pixel(atX: 0, y: 0, pixels: pixels, width: image.width),
            pixel(atX: image.width - 1, y: 0, pixels: pixels, width: image.width),
            pixel(atX: 0, y: image.height - 1, pixels: pixels, width: image.width),
            pixel(atX: image.width - 1, y: image.height - 1, pixels: pixels, width: image.width)
        ]

        guard cornerSamplesAreConsistent(corners) else {
            return image
        }

        let background = average(of: corners)
        guard let top = firstContentRow(
            in: 0..<(image.height - 1),
            pixels: pixels,
            width: image.width,
            background: background
        ),
        let bottom = firstContentRow(
            in: (1..<image.height).reversed(),
            pixels: pixels,
            width: image.width,
            background: background
        ),
        let left = firstContentColumn(
            in: 0..<(image.width - 1),
            pixels: pixels,
            width: image.width,
            height: image.height,
            background: background
        ),
        let right = firstContentColumn(
            in: (1..<image.width).reversed(),
            pixels: pixels,
            width: image.width,
            height: image.height,
            background: background
        ) else {
            return image
        }

        let rectangle = CGRect(
            x: left,
            y: top,
            width: right - left + 1,
            height: bottom - top + 1
        )
        let originalBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard rectangle != originalBounds,
              hasStrongContentSupport(
                (0..<image.width).map { pixel(atX: $0, y: top, pixels: pixels, width: image.width) },
                background: background
              ),
              hasStrongContentSupport(
                (0..<image.width).map { pixel(atX: $0, y: bottom, pixels: pixels, width: image.width) },
                background: background
              ),
              hasStrongContentSupport(
                (0..<image.height).map { pixel(atX: left, y: $0, pixels: pixels, width: image.width) },
                background: background
              ),
              hasStrongContentSupport(
                (0..<image.height).map { pixel(atX: right, y: $0, pixels: pixels, width: image.width) },
                background: background
              ) else {
            return image
        }

        return image.cropping(to: rectangle) ?? image
    }

    private func normalizedPixels(from image: CGImage) -> [UInt8]? {
        var pixels = Array(repeating: UInt8(0), count: image.width * image.height * 4)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    private func cornerSamplesAreConsistent(_ corners: [RGB]) -> Bool {
        corners.allSatisfy { sample in
            corners.allSatisfy { other in
                channelDifference(sample.red, other.red) <= Self.tolerance
                    && channelDifference(sample.green, other.green) <= Self.tolerance
                    && channelDifference(sample.blue, other.blue) <= Self.tolerance
            }
        }
    }

    private func average(of colors: [RGB]) -> RGB {
        RGB(
            red: colors.reduce(0) { $0 + Int($1.red) } / colors.count,
            green: colors.reduce(0) { $0 + Int($1.green) } / colors.count,
            blue: colors.reduce(0) { $0 + Int($1.blue) } / colors.count
        )
    }

    private func firstContentRow<Rows: Sequence>(
        in rows: Rows,
        pixels: [UInt8],
        width: Int,
        background: RGB
    ) -> Int? where Rows.Element == Int {
        rows.first { row in
            backgroundPixelRatio(
                (0..<width).map { pixel(atX: $0, y: row, pixels: pixels, width: width) },
                background: background
            ) < Self.backgroundRatio
        }
    }

    private func firstContentColumn<Columns: Sequence>(
        in columns: Columns,
        pixels: [UInt8],
        width: Int,
        height: Int,
        background: RGB
    ) -> Int? where Columns.Element == Int {
        columns.first { column in
            backgroundPixelRatio(
                (0..<height).map { pixel(atX: column, y: $0, pixels: pixels, width: width) },
                background: background
            ) < Self.backgroundRatio
        }
    }

    private func backgroundPixelRatio(_ pixels: [RGB], background: RGB) -> Double {
        let backgroundPixels = pixels.filter { pixel in
            channelDifference(pixel.red, background.red) <= Self.tolerance
                && channelDifference(pixel.green, background.green) <= Self.tolerance
                && channelDifference(pixel.blue, background.blue) <= Self.tolerance
        }
        return Double(backgroundPixels.count) / Double(pixels.count)
    }

    private func hasStrongContentSupport(_ pixels: [RGB], background: RGB) -> Bool {
        1 - backgroundPixelRatio(pixels, background: background) >= Self.minimumContentRatio
    }

    private func pixel(atX x: Int, y: Int, pixels: [UInt8], width: Int) -> RGB {
        let offset = (y * width + x) * 4
        return RGB(red: Int(pixels[offset]), green: Int(pixels[offset + 1]), blue: Int(pixels[offset + 2]))
    }

    private func channelDifference(_ first: Int, _ second: Int) -> Int {
        abs(first - second)
    }
}

private struct RGB {
    let red: Int
    let green: Int
    let blue: Int
}
