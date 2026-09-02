import Foundation

public final class LibraryStore {
    public let paths: LibraryPaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.paths = LibraryPaths(rootURL: rootURL)
        self.fileManager = fileManager

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO8601 date: \(string)"
                )
            }
            return date
        }
        self.decoder = decoder
    }

    public func ensureLayout() throws {
        for url in [paths.libraryURL, paths.sessionsURL, paths.pdfsURL, paths.settingsURL] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    public func list() throws -> [BookEntry] {
        let urls = try fileManager.contentsOfDirectory(
            at: paths.libraryURL,
            includingPropertiesForKeys: nil
        )
        let entries = try urls
            .filter { $0.pathExtension == "json" }
            .map { try decode(from: $0) }
        return entries.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(_ entry: BookEntry) throws {
        var entry = entry
        entry.updatedAt = Date()
        try ensureLayout()
        let data = try encoder.encode(entry)
        try data.write(to: paths.entryURL(for: entry.id), options: .atomic)
    }

    public func load(id: UUID) throws -> BookEntry {
        try decode(from: paths.entryURL(for: id))
    }

    public func delete(id: UUID) throws {
        try removeIfExists(paths.entryURL(for: id))
        try removeIfExists(paths.sessionURL(for: id))
        try removeIfExists(paths.pdfURL(for: id))
    }

    public func makeNewEntry(displayName: String, requestedPageCount: Int?) -> BookEntry {
        let id = UUID()
        let now = Date()
        return BookEntry(
            id: id,
            displayName: displayName,
            createdAt: now,
            updatedAt: now,
            status: .scanning,
            sessionPath: "Sessions/\(id.uuidString)",
            pdfPath: nil,
            capturedPageCount: 0,
            requestedPageCount: requestedPageCount,
            cropOverride: nil
        )
    }

    private func decode(from url: URL) throws -> BookEntry {
        try decoder.decode(BookEntry.self, from: Data(contentsOf: url))
    }

    private func removeIfExists(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
