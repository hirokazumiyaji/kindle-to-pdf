import AppKit

public struct MacOSApplicationActivator: ApplicationActivating {
    public init() {}

    public func activate(processID: Int32) throws {
        guard let application = NSRunningApplication(processIdentifier: processID) else {
            return
        }
        if application.isActive {
            return
        }

        if let bundleIdentifier = application.bundleIdentifier {
            let source = "tell application id \"\(bundleIdentifier)\" to activate"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if error == nil, application.isActive {
                return
            }
        }

        if let name = application.localizedName {
            let escaped = name.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let source = "tell application \"\(escaped)\" to activate"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if error == nil, application.isActive {
                return
            }
        }

        _ = application.activate()
    }
}
