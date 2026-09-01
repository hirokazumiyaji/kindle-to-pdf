import Combine
import Foundation
import KindleToPDFCore

@MainActor
final class AppModel: ObservableObject {
    let libraryStore: LibraryStore
    let settingsStore: AppSettingsStore
    let permissionChecker: MacOSPermissionChecker
    let settingsViewModel: SettingsViewModel
    lazy var scanViewModel: ScanViewModel = ScanViewModel(
        libraryStore: libraryStore,
        presentPermissionsIfNeeded: { [weak self] in
            self?.presentPermissionsIfNeeded() ?? true
        },
        settingsProvider: { [weak self] in
            self?.settings ?? .default
        }
    )
    lazy var libraryViewModel: LibraryViewModel = LibraryViewModel(
        store: libraryStore,
        onResume: { [weak self] entry in
            self?.pendingResume = entry
            self?.selectedSection = .scan
        }
    )

    @Published var selectedSection: AppSection = .scan
    @Published var settings: AppSettings
    @Published var permissionStatus: PermissionStatus
    @Published var showPermissionSheet = false
    @Published var pendingResume: BookEntry?

    var needsPermissionSetup: Bool {
        !permissionStatus.accessibility || !permissionStatus.screenRecording
    }

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
        let permissionChecker = MacOSPermissionChecker()
        let permissionStatus = permissionChecker.status()

        self.libraryStore = libraryStore
        self.settingsStore = settingsStore
        self.settings = settings
        self.permissionChecker = permissionChecker
        self.permissionStatus = permissionStatus
        self.settingsViewModel = SettingsViewModel(store: settingsStore, settings: settings)
        self.showPermissionSheet = !permissionStatus.accessibility || !permissionStatus.screenRecording
    }

    func refreshPermissionStatus() {
        permissionStatus = permissionChecker.status()
    }

    /// Shows the setup sheet when Accessibility or Screen Recording is missing.
    /// Returns true if the caller should block (for example scan start).
    @discardableResult
    func presentPermissionsIfNeeded() -> Bool {
        refreshPermissionStatus()
        if needsPermissionSetup {
            showPermissionSheet = true
            return true
        }
        return false
    }

    func applyPendingResumeIfNeeded() {
        guard let entry = pendingResume else { return }
        scanViewModel.applyPendingResume(entry)
        pendingResume = nil
    }
}
