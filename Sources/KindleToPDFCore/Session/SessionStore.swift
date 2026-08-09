import Foundation

public struct SessionStore {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func createDirectories() throws {
        try FileManager.default.createDirectory(
            at: pagesURL,
            withIntermediateDirectories: true
        )
    }

    public func save(_ state: SessionState) throws {
        try createDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    public func load() throws -> SessionState {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            throw SessionError.missingState(stateURL)
        }

        do {
            return try JSONDecoder().decode(SessionState.self, from: Data(contentsOf: stateURL))
        } catch {
            throw SessionError.invalidState(stateURL)
        }
    }

    public func savePage(_ data: Data, index: Int) throws {
        guard index > 0 else {
            throw SessionError.invalidPageIndex(index)
        }
        try createDirectories()
        try data.write(to: pageURL(index: index), options: .atomic)
    }

    public func pageURL(index: Int) -> URL {
        rootURL.appendingPathComponent("pages").appendingPathComponent(
            String(format: "%04d.png", index)
        )
    }

    public func pageURLs(count: Int) -> [URL] {
        guard count > 0 else {
            return []
        }
        return (1...count).map(pageURL(index:))
    }

    private var stateURL: URL {
        rootURL.appendingPathComponent("state.json")
    }

    private var pagesURL: URL {
        rootURL.appendingPathComponent("pages")
    }
}
