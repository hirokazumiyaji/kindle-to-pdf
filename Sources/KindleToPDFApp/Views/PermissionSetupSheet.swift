import AppKit
import SwiftUI
import KindleToPDFCore

struct PermissionSetupSheet: View {
    let status: PermissionStatus
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("必要な権限")
                .font(.title2.bold())

            Text("スキャンを始める前に、次の権限を許可してください。")
                .foregroundStyle(.secondary)

            permissionRow(
                title: "アクセシビリティ",
                detail: "ページ送りのキー送信に使います",
                granted: status.accessibility,
                settingsURL: Self.accessibilitySettingsURL
            )

            permissionRow(
                title: "画面収録",
                detail: "Kindle ウィンドウのキャプチャに使います",
                granted: status.screenRecording,
                settingsURL: Self.screenCaptureSettingsURL
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
                Button("再確認") {
                    onRefresh()
                }
                Spacer()
            }
        }
        .padding(24)
        .frame(minWidth: 440)
    }

    private func permissionRow(title: String, detail: String, granted: Bool, settingsURL: URL) -> some View {
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
                Self.open(settingsURL)
            }
        }
    }

    private static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
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
