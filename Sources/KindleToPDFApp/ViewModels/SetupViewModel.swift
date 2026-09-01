import AppKit
import Combine
import Foundation
import KindleToPDFCore

@MainActor
final class SetupViewModel: ObservableObject {
    @Published var insets: CropInsets
    @Published var previewImage: NSImage?
    @Published var isRunning = false
    @Published var message: String?

    private let settingsStore: AppSettingsStore
    private let paths: LibraryPaths
    private let presentPermissionsIfNeeded: () -> Bool
    private let settingsProvider: () -> AppSettings
    private let onSettingsSaved: (AppSettings) -> Void
    private let cropper = ManualInsetCropper()
    private let codec = PNGImageCodec()
    private var baseImage: CGImage?

    static let testPageCount = 3
    static let sessionDirectoryName = ".setup-test"

    init(
        settingsStore: AppSettingsStore,
        paths: LibraryPaths,
        presentPermissionsIfNeeded: @escaping () -> Bool,
        settingsProvider: @escaping () -> AppSettings,
        onSettingsSaved: @escaping (AppSettings) -> Void
    ) {
        self.settingsStore = settingsStore
        self.paths = paths
        self.presentPermissionsIfNeeded = presentPermissionsIfNeeded
        self.settingsProvider = settingsProvider
        self.onSettingsSaved = onSettingsSaved
        self.insets = settingsProvider().globalCropInsets
    }

    var sessionURL: URL {
        paths.sessionsURL.appendingPathComponent(Self.sessionDirectoryName, isDirectory: true)
    }

    var outputURL: URL {
        paths.pdfsURL.appendingPathComponent("\(Self.sessionDirectoryName).pdf")
    }

    func reloadInsetsFromSettings() {
        insets = settingsProvider().globalCropInsets
        refreshPreview()
    }

    func runTestScan() async {
        guard !isRunning else { return }
        if presentPermissionsIfNeeded() { return }

        message = nil
        isRunning = true
        message = "テストスキャン中"

        let sessionURL = sessionURL
        let outputURL = outputURL
        let settings = settingsProvider()
        let coordinator = makeCoordinator()
        let options = CaptureOptions(
            outputURL: outputURL,
            pageCount: Self.testPageCount,
            windowTitle: nil,
            nextKey: settings.defaultNextKey,
            sessionURL: sessionURL,
            resume: false,
            overwrite: true
        )

        do {
            try prepareFreshSession(sessionURL: sessionURL, outputURL: outputURL)
            try await Task.detached {
                try coordinator.run(
                    options: options,
                    stopRequested: { false }
                )
            }.value
            try loadFirstPage(sessionURL: sessionURL)
            message = "テストスキャン完了"
        } catch {
            message = Self.message(for: error)
        }

        isRunning = false
    }

    func refreshPreview() {
        guard let baseImage else {
            previewImage = nil
            return
        }
        let cropped = cropper.crop(baseImage, insets: insets)
        previewImage = NSImage(
            cgImage: cropped,
            size: NSSize(width: cropped.width, height: cropped.height)
        )
    }

    func saveAsDefaults() throws {
        var settings = settingsProvider()
        settings.globalCropInsets = insets
        try settingsStore.save(settings)
        onSettingsSaved(settings)
        message = "保存しました"
    }

    func makeCoordinator() -> CaptureCoordinator {
        CaptureCoordinator(
            windowLocator: MacOSWindowLocator(),
            permissionChecker: MacOSPermissionChecker(),
            pageTurner: MacOSPageTurner(),
            applicationActivator: MacOSApplicationActivator(),
            windowCapture: MacOSWindowCapture(edgeCropEnabled: true, insets: nil),
            imageCodec: PNGImageCodec(),
            imageChangeDetector: ImageChangeDetector(),
            pdfWriter: PDFWriter(),
            sleeper: ThreadSleeper()
        )
    }

    private func prepareFreshSession(sessionURL: URL, outputURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: sessionURL.path) {
            try fileManager.removeItem(at: sessionURL)
        }
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
    }

    private func loadFirstPage(sessionURL: URL) throws {
        let store = SessionStore(rootURL: sessionURL)
        let data = try Data(contentsOf: store.pageURL(index: 1))
        baseImage = try codec.decode(data)
        refreshPreview()
    }

    private static func message(for error: Error) -> String {
        if let captureError = error as? CaptureError {
            return captureError.description
        }
        if let platformError = error as? PlatformError {
            return platformError.description
        }
        if let mediaError = error as? MediaError {
            return mediaError.description
        }
        return error.localizedDescription
    }
}
