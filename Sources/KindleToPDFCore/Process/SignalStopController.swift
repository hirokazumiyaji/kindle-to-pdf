import Foundation

public final class SignalStopController {
    private let lock = NSLock()
    private var requested = false

    public init() {}

    public var isRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    public func requestStop() {
        lock.lock()
        requested = true
        lock.unlock()
    }
}
