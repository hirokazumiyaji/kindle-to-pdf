import Foundation

public struct LibraryPaths {
    public let rootURL: URL

    public static var defaultRootURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/KindleToPDF", isDirectory: true)
    }

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public var libraryURL: URL {
        rootURL.appendingPathComponent("Library", isDirectory: true)
    }

    public var sessionsURL: URL {
        rootURL.appendingPathComponent("Sessions", isDirectory: true)
    }

    public var pdfsURL: URL {
        rootURL.appendingPathComponent("PDFs", isDirectory: true)
    }

    public var settingsURL: URL {
        rootURL.appendingPathComponent("Settings", isDirectory: true)
    }

    public func sessionURL(for id: UUID) -> URL {
        sessionsURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public func pdfURL(for id: UUID) -> URL {
        pdfsURL.appendingPathComponent("\(id.uuidString).pdf")
    }

    public func entryURL(for id: UUID) -> URL {
        libraryURL.appendingPathComponent("\(id.uuidString).json")
    }
}
