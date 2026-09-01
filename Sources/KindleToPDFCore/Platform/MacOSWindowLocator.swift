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

enum KindleWindowFilter {
    static func contentWindows(
        from windows: [KindleWindow],
        minimumHeight: CGFloat = 200
    ) -> [KindleWindow] {
        windows.filter { $0.bounds.height >= minimumHeight }
    }
}

public struct MacOSWindowLocator: WindowLocating, WindowListing {
    static let windowListOptions: CGWindowListOption = [.excludeDesktopElements]

    public init() {}

    public func listWindows() throws -> [KindleWindow] {
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
        return KindleWindowFilter.contentWindows(from: windows)
    }

    public func locate(title: String?) throws -> KindleWindow {
        try WindowSelector.select(from: try listWindows(), title: title)
    }
}
