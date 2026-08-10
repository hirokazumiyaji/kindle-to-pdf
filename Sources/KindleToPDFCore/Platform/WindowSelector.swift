public enum WindowSelector {
    public static func select(
        from windows: [KindleWindow],
        title: String?
    ) throws -> KindleWindow {
        guard !windows.isEmpty else {
            throw PlatformError.noWindows
        }

        if let title {
            let matches = windows.filter { $0.title == title }
            guard matches.count == 1 else {
                throw PlatformError.titleNotFound(title)
            }
            return matches[0]
        }

        guard windows.count == 1 else {
            throw PlatformError.ambiguousWindows
        }
        return windows[0]
    }
}
