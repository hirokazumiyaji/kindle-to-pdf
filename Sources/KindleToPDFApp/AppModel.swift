import Combine
import Foundation
import KindleToPDFCore

final class AppModel: ObservableObject {
    let libraryStore: LibraryStore
    let settingsStore: AppSettingsStore

    @Published var selectedSection: AppSection = .scan
    @Published var settings: AppSettings

    init() {
        let defaultPaths = LibraryPaths(rootURL: LibraryPaths.defaultRootURL)
        let bootstrapStore = AppSettingsStore(paths: defaultPaths)
        let bootstrapSettings = (try? bootstrapStore.load()) ?? .default
        let rootURL = URL(fileURLWithPath: bootstrapSettings.libraryRootPath, isDirectory: true)

        let libraryStore = LibraryStore(rootURL: rootURL)
        try? libraryStore.ensureLayout()
        let settingsStore = AppSettingsStore(paths: libraryStore.paths)
        let settings = (try? settingsStore.load()) ?? {
            var fallback = AppSettings.default
            fallback.libraryRootPath = rootURL.path
            return fallback
        }()

        self.libraryStore = libraryStore
        self.settingsStore = settingsStore
        self.settings = settings
    }
}
