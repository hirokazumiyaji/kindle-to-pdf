import SwiftUI
import KindleToPDFCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("ライブラリ") {
                LabeledContent("保存先") {
                    Text(viewModel.draft.libraryRootPath)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                Button("Finderで開く") {
                    viewModel.openLibraryInFinder()
                }
            }

            Section("スキャン既定値") {
                Picker("ページ送りキー", selection: $viewModel.draft.defaultNextKey) {
                    Text("right").tag(NextKey.right)
                    Text("left").tag(NextKey.left)
                    Text("pagedown").tag(NextKey.pagedown)
                }
                TextField("ページ数（任意）", text: $viewModel.pageCountText)
                Toggle("自動クロップ", isOn: $viewModel.draft.autoCropEnabled)
            }

            Section("グローバル inset") {
                Stepper(value: insetBinding(\.top), in: 0...2000) {
                    Text("上: \(viewModel.draft.globalCropInsets.top)")
                }
                Stepper(value: insetBinding(\.bottom), in: 0...2000) {
                    Text("下: \(viewModel.draft.globalCropInsets.bottom)")
                }
                Stepper(value: insetBinding(\.left), in: 0...2000) {
                    Text("左: \(viewModel.draft.globalCropInsets.left)")
                }
                Stepper(value: insetBinding(\.right), in: 0...2000) {
                    Text("右: \(viewModel.draft.globalCropInsets.right)")
                }
            }

            Section("権限") {
                LabeledContent("アクセシビリティ") {
                    Text(model.permissionStatus.accessibility ? "許可済み" : "未許可")
                }
                LabeledContent("画面収録") {
                    Text(model.permissionStatus.screenRecording ? "許可済み" : "未許可")
                }
                LabeledContent("オートメーション") {
                    Text("未確認")
                }
                Button("権限を再確認") {
                    model.refreshPermissionStatus()
                    if model.needsPermissionSetup {
                        model.showPermissionSheet = true
                    }
                }
                Text("開発ビルド（adhoc 署名）を作り直すと実行ファイルの署名が変わり、権限の再登録が必要になることがあります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Button("保存") {
                do {
                    try viewModel.save()
                    model.settings = viewModel.draft
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func insetBinding(_ keyPath: WritableKeyPath<CropInsets, Int>) -> Binding<Int> {
        Binding(
            get: { viewModel.draft.globalCropInsets[keyPath: keyPath] },
            set: { newValue in
                var insets = viewModel.draft.globalCropInsets
                insets[keyPath: keyPath] = newValue
                viewModel.setInset(
                    top: insets.top,
                    bottom: insets.bottom,
                    left: insets.left,
                    right: insets.right
                )
            }
        )
    }
}
