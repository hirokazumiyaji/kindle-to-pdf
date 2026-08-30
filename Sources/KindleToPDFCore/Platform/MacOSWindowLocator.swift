import AppKit
import CoreGraphics

enum KindleApplicationMatcher {
    static func matches(localizedName: String?, bundleIdentifier: String?) -> Bool {
        let nameMatches = localizedName?.caseInsensitiveCompare("Kindle") == .orderedSame
            || localizedName?.caseInsensitiveCompare("Amazon Kindle") == .orderedSame
        let bundleIdentifierMatches = bundleIdentifier == "com.amazon.Kindle"
            || bundleIdentifier == "com.amazon.Lassen"
        return nameMatches || bundleIdentifierMatches
    }
}

public struct MacOSWindowLocator: WindowLocating {
    static let windowListOptions: CGWindowListOption = [.excludeDesktopElements]

    public init() {}

    public func locate(title: String?) throws -> KindleWindow {
        let applications = NSWorkspace.shared.runningApplications.filter { application in
            KindleApplicationMatcher.matches(
                localizedName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier
            )
        }
        guard let application = applications.first else {
            throw PlatformError.noKindleApplication
        }

        let windowInfo = CGWindowListCopyWindowInfo(
            Self.windowListOptions,
            kCGNullWindowID
        ) as? [[String: Any]] ?? []
        let windows = windowInfo.compactMap { info -> KindleWindow? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == application.processIdentifier,
                  let number = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  !bounds.isEmpty else {
                return nil
            }

            return KindleWindow(
                windowID: number.uint32Value,
                processID: application.processIdentifier,
                title: info[kCGWindowName as String] as? String ?? "",
                bounds: bounds
            )
        }
        return try WindowSelector.select(from: windows, title: title)
    }
}
