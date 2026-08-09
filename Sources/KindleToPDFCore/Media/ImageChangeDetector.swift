import CoreGraphics
import Foundation

public struct ImageChangeDetector {
    public let changedPixelRatio: Double

    public init(changedPixelRatio: Double = 0.01) {
        self.changedPixelRatio = changedPixelRatio
    }

    public func hasChanged(_ before: CGImage, _ after: CGImage) throws -> Bool {
        guard before.width == after.width,
              before.height == after.height else {
            return true
        }

        guard let beforeData = before.dataProvider?.data as Data?,
              let afterData = after.dataProvider?.data as Data?,
              !beforeData.isEmpty,
              beforeData.count == afterData.count else {
            return true
        }

        let differingBytes = zip(beforeData, afterData).reduce(into: 0) { count, pair in
            if pair.0 != pair.1 {
                count += 1
            }
        }
        return Double(differingBytes) / Double(beforeData.count) >= changedPixelRatio
    }

    public func isStable(_ samples: [CGImage]) throws -> Bool {
        guard samples.count >= 2 else {
            return false
        }
        for pair in zip(samples, samples.dropFirst()) {
            if try hasChanged(pair.0, pair.1) {
                return false
            }
        }
        return true
    }
}
