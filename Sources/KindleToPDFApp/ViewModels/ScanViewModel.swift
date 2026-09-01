import Combine
import Foundation
import KindleToPDFCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var pageCountText = ""
    @Published var windowTitle = ""
    @Published var nextKey: NextKey = .right
    @Published var isRunning = false
    @Published var capturedPageCount = 0
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var availableWindows: [KindleWindow] = []

    private let libraryStore: LibraryStore
    private let windowListing: any WindowListing
    private let presentPermissionsIfNeeded: () -> Bool
    private let settingsProvider: () -> AppSettings
    private var stopController: SignalStopController?

    init(
        libraryStore: LibraryStore,
        windowListing: any WindowListing = MacOSWindowLocator(),
        presentPermissionsIfNeeded: @escaping () -> Bool,
        settingsProvider: @escaping () -> AppSettings
    ) {
        self.libraryStore = libraryStore
        self.windowListing = windowListing
        self.presentPermissionsIfNeeded = presentPermissionsIfNeeded
        self.settingsProvider = settingsProvider
        let settings = settingsProvider()
        self.pageCountText = settings.defaultPageCount.map(String.init) ?? ""
        self.nextKey = settings.defaultNextKey
    }

    func refreshWindows() {
        do {
            availableWindows = try windowListing.listWindows()
        } catch {
            availableWindows = []
            statusMessage = Self.message(for: error)
        }
    }

    func start() {
        guard !isRunning else { return }
        if presentPermissionsIfNeeded() { return }

        errorMessage = nil
        let settings = settingsProvider()

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "表示名を入力してください"
            return
        }

        let pageCount: Int?
        let trimmedPages = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPages.isEmpty {
            pageCount = nil
        } else if let value = Int(trimmedPages), value > 0 {
            pageCount = value
        } else {
            errorMessage = "ページ数は空欄か 1 以上の整数を入力してください"
            return
        }

        let entry = libraryStore.makeNewEntry(displayName: name, requestedPageCount: pageCount)
        do {
            try libraryStore.save(entry)
        } catch {
            errorMessage = Self.message(for: error)
            return
        }

        let insetsSource = entry.cropOverride ?? settings.globalCropInsets
        let insets: CropInsets? = insetsSource.isZero ? nil : insetsSource
        let coordinator = makeCoordinator(
            insets: insets,
            edgeCropEnabled: settings.autoCropEnabled
        )
        let title = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = CaptureOptions(
            outputURL: libraryStore.paths.pdfURL(for: entry.id),
            pageCount: pageCount,
            windowTitle: title.isEmpty ? nil : title,
            nextKey: nextKey,
            sessionURL: libraryStore.paths.sessionURL(for: entry.id),
            resume: false,
            overwrite: true
        )

        let stopController = SignalStopController()
        self.stopController = stopController
        isRunning = true
        capturedPageCount = 0
        statusMessage = "スキャン中"

        let entryID = entry.id
        let pdfPath = "PDFs/\(entry.id.uuidString).pdf"

        Task.detached {
            do {
                try coordinator.run(
                    options: options,
                    stopRequested: { stopController.isRequested },
                    onProgress: { count in
                        Task { @MainActor [weak self] in
                            self?.capturedPageCount = count
                            self?.statusMessage = "スキャン中"
                        }
                    }
                )
                await MainActor.run { [weak self] in
                    self?.finishSuccess(entryID: entryID, pdfPath: pdfPath)
                }
            } catch CaptureError.stopRequested {
                await MainActor.run { [weak self] in
                    self?.finishStopped(entryID: entryID)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.finishFailed(entryID: entryID, error: error)
                }
            }
        }
    }

    func stop() {
        stopController?.requestStop()
    }

    func makeCoordinator(insets: CropInsets?, edgeCropEnabled: Bool) -> CaptureCoordinator {
        CaptureCoordinator(
            windowLocator: MacOSWindowLocator(),
            permissionChecker: MacOSPermissionChecker(),
            pageTurner: MacOSPageTurner(),
            applicationActivator: MacOSApplicationActivator(),
            windowCapture: MacOSWindowCapture(edgeCropEnabled: edgeCropEnabled, insets: insets),
            imageCodec: PNGImageCodec(),
            imageChangeDetector: ImageChangeDetector(),
            pdfWriter: PDFWriter(),
            sleeper: ThreadSleeper()
        )
    }

    private func finishSuccess(entryID: UUID, pdfPath: String) {
        isRunning = false
        stopController = nil
        statusMessage = "完了"
        updateEntry(id: entryID) { entry in
            entry.status = .completed
            entry.pdfPath = pdfPath
            entry.capturedPageCount = capturedPageCount
        }
    }

    private func finishStopped(entryID: UUID) {
        isRunning = false
        stopController = nil
        errorMessage = nil
        statusMessage = "停止しました"
        updateEntry(id: entryID) { entry in
            entry.status = .scanning
            entry.capturedPageCount = capturedPageCount
        }
    }

    private func finishFailed(entryID: UUID, error: Error) {
        isRunning = false
        stopController = nil
        errorMessage = Self.message(for: error)
        statusMessage = "エラー"
        updateEntry(id: entryID) { entry in
            entry.status = .scanning
            entry.capturedPageCount = capturedPageCount
        }
    }

    private func updateEntry(id: UUID, mutate: (inout BookEntry) -> Void) {
        do {
            var entry = try libraryStore.load(id: id)
            mutate(&entry)
            try libraryStore.save(entry)
        } catch {
            if errorMessage == nil {
                errorMessage = Self.message(for: error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let captureError = error as? CaptureError {
            return captureError.description
        }
        if let platformError = error as? PlatformError {
            return platformError.description
        }
        return error.localizedDescription
    }
}
