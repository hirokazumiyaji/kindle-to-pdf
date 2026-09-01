import Foundation

public final class AppSettingsStore {
    public let paths: LibraryPaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: LibraryPaths) {
        self.paths = paths

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func load() throws -> AppSettings {
        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            var settings = AppSettings.default
            settings.libraryRootPath = paths.rootURL.path
            return settings
        }
        return try decoder.decode(AppSettings.self, from: Data(contentsOf: url))
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: paths.settingsURL, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: settingsFileURL, options: .atomic)
    }

    private var settingsFileURL: URL {
        paths.settingsURL.appendingPathComponent("settings.json")
    }
}
