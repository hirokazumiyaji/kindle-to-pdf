import AppKit
import SwiftUI
import KindleToPDFCore

struct PermissionSetupSheet: View {
    let status: PermissionStatus
    let onDismiss: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if status.accessibility && status.screenRecording {
                grantedSection
            } else {
                missingSection
            }
        }
        .padding(24)
        .frame(minWidth: 440, maxWidth: 520)
    }

    private var grantedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("権限が揃いました")
                .font(.title2.bold())

            Text("必要な権限はすべて許可されています。画面収録の許可を切り替えた直後は、アプリの再起動後に反映されます。")
                .foregroundStyle(.secondary)

            HStack {
                Button("閉じる") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                if Self.canRelaunch {
                    Button("アプリを再起動") {
                        Self.relaunch()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("必要な権限")
                .font(.title2.bold())

            Text("スキャンを始める前に、次の権限を許可してください。")
                .foregroundStyle(.secondary)

            Text("「システム設定を開く」を押すと権限の確認ダイアログが出て、リストに本アプリが追加されます。あとはスイッチをオンにするだけです。リストに表示されない場合はシステム設定を一度開き直してください。")
                .font(.caption)
                .foregroundStyle(.secondary)

            permissionRow(
                title: "アクセシビリティ",
                detail: "ページ送りのキー送信に使います",
                granted: status.accessibility,
                settingsURL: Self.accessibilitySettingsURL,
                onRequest: { Self.checker.requestAccessibility() }
            )

            permissionRow(
                title: "画面収録",
                detail: "Kindle ウィンドウのキャプチャに使います。許可の反映にはアプリの再起動が必要です。",
                granted: status.screenRecording,
                settingsURL: Self.screenCaptureSettingsURL,
                onRequest: { Self.checker.requestScreenRecording() }
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                    Text("オートメーション")
                        .font(.headline)
                    Spacer()
                    Text("未確認")
                        .foregroundStyle(.secondary)
                }
                Text("Kindle の前面化（AppleScript）に使います。事前確認できないため、初回のページ送り時に許可ダイアログが出ることがあります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("システム設定を開く") {
                    Self.open(Self.automationSettingsURL)
                }
            }

            HStack {
                Button("後で設定する") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("再確認") {
                    onRefresh()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        granted: Bool,
        settingsURL: URL,
        onRequest: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(granted ? Color.green : Color.red)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(granted ? "許可済み" : "未許可")
                    .foregroundStyle(granted ? Color.secondary : Color.red)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("システム設定を開く") {
                onRequest()
                Self.open(settingsURL)
            }
        }
    }

    private static let checker = MacOSPermissionChecker()

    private static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private static var canRelaunch: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    static let screenCaptureSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    static let automationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    )!
}
