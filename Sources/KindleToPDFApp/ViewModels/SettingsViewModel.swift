import AppKit
import Combine
import Foundation
import KindleToPDFCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var draft: AppSettings
    @Published var pageCountText: String
    @Published var errorMessage: String?

    private let store: AppSettingsStore

    init(store: AppSettingsStore, settings: AppSettings) {
        self.store = store
        self.draft = settings
        self.pageCountText = settings.defaultPageCount.map(String.init) ?? ""
    }

    func save() throws {
        let trimmed = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draft.defaultPageCount = nil
        } else if let value = Int(trimmed), value > 0 {
            draft.defaultPageCount = value
        } else {
            throw SettingsViewModelError.invalidPageCount
        }
        try store.save(draft)
        errorMessage = nil
    }

    func openLibraryInFinder() {
        let url = URL(fileURLWithPath: draft.libraryRootPath, isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    func setInset(top: Int? = nil, bottom: Int? = nil, left: Int? = nil, right: Int? = nil) {
        let current = draft.globalCropInsets
        draft.globalCropInsets = CropInsets(
            top: top ?? current.top,
            bottom: bottom ?? current.bottom,
            left: left ?? current.left,
            right: right ?? current.right
        )
    }
}

enum SettingsViewModelError: LocalizedError {
    case invalidPageCount

    var errorDescription: String? {
        switch self {
        case .invalidPageCount:
            return "ページ数は空欄か 1 以上の整数を入力してください"
        }
    }
}
