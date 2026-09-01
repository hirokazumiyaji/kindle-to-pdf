import AppKit
import Combine
import Foundation
import KindleToPDFCore

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var books: [BookEntry] = []
    @Published var errorMessage: String?

    private let store: LibraryStore
    private let onResume: (BookEntry) -> Void

    var paths: LibraryPaths { store.paths }

    init(store: LibraryStore, onResume: @escaping (BookEntry) -> Void) {
        self.store = store
        self.onResume = onResume
    }

    func reload() {
        do {
            books = try store.list()
            errorMessage = nil
        } catch {
            books = []
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: UUID) {
        do {
            try store.delete(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(id: UUID) {
        let pdfURL = store.paths.pdfURL(for: id)
        if FileManager.default.fileExists(atPath: pdfURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([pdfURL])
            return
        }
        let sessionURL = store.paths.sessionURL(for: id)
        if FileManager.default.fileExists(atPath: sessionURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([sessionURL])
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([store.paths.entryURL(for: id)])
    }

    func regeneratePDF(id: UUID) throws {
        let entry = try store.load(id: id)
        let session = SessionStore(rootURL: store.paths.sessionURL(for: id))
        let state = try session.load()
        let urls = session.pageURLs(count: state.capturedPageCount)
        let pdfURL = store.paths.pdfURL(for: id)
        try PDFWriter().write(imageURLs: urls, to: pdfURL)
        var updated = entry
        updated.pdfPath = "PDFs/\(id.uuidString).pdf"
        updated.status = .completed
        updated.capturedPageCount = state.capturedPageCount
        try store.save(updated)
        reload()
    }

    func resume(id: UUID) {
        do {
            let entry = try store.load(id: id)
            errorMessage = nil
            onResume(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pdfURLIfAvailable(for entry: BookEntry) -> URL? {
        guard entry.pdfPath != nil else { return nil }
        let url = store.paths.pdfURL(for: entry.id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
