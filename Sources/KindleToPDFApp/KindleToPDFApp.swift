import SwiftUI

@main
struct KindleToPDFApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case scan, library, setup, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan: return "スキャン"
        case .library: return "ライブラリ"
        case .setup: return "セットアップ"
        case .settings: return "設定"
        }
    }
}
