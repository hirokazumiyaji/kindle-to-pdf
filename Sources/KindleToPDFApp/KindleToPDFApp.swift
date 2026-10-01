import SwiftUI

@main
struct KindleToPDFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

/// シートが表示されたままでもアプリを終了できるようにするデリゲート。
/// シートが開いているウィンドウは close を拒否するため、
/// 終了時にシートを閉じて、閉じきるのを待ってから終了を続行します。
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard endOpenSheets() else {
            return .terminateNow
        }
        waitAndReply(deadline: Date().addingTimeInterval(1))
        return .terminateLater
    }

    /// 開いているシートを閉じる。シートがあった場合は true を返す。
    @discardableResult
    private func endOpenSheets() -> Bool {
        let parents = NSApplication.shared.windows.filter { $0.attachedSheet != nil }
        parents.forEach { parent in
            if let sheet = parent.attachedSheet {
                parent.endSheet(sheet, returnCode: .continue)
            }
        }
        return !parents.isEmpty
    }

    /// シートの終了アニメーションが完了してから終了を続行する。
    private func waitAndReply(deadline: Date) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            if NSApplication.shared.windows.contains(where: { $0.attachedSheet != nil }) && Date() < deadline {
                self.endOpenSheets()
                self.waitAndReply(deadline: deadline)
                return
            }
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
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
