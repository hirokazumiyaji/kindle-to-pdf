import Foundation

public protocol Sleeper {
    func sleep(for duration: TimeInterval) throws
}

public struct ThreadSleeper: Sleeper {
    public init() {}

    public func sleep(for duration: TimeInterval) throws {
        Thread.sleep(forTimeInterval: duration)
    }
}
