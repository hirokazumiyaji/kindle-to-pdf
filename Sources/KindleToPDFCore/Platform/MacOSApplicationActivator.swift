import AppKit

public struct MacOSApplicationActivator: ApplicationActivating {
    public init() {}

    public func activate(processID: Int32) throws {
        guard let application = NSRunningApplication(processIdentifier: processID) else {
            return
        }
        application.activate(options: [.activateIgnoringOtherApps])
    }
}
