import SwiftUI
import KindleToPDFCore

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        Form {
            Section {
                Text("テストスキャンで3ページを取得し、自動クロップ後の1ページ目を表示します。スライダーで余白を追加調整し、保存すると以降のスキャンの既定 inset になります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("プレビュー") {
                if let previewImage = viewModel.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 420)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("テストスキャンでプレビューを表示します")
                        .foregroundStyle(.secondary)
                }
            }

            Section("手動 inset") {
                insetSlider("上", keyPath: \.top)
                insetSlider("下", keyPath: \.bottom)
                insetSlider("左", keyPath: \.left)
                insetSlider("右", keyPath: \.right)
            }

            if let message = viewModel.message {
                Section {
                    Text(message)
                }
            }

            HStack {
                Button("テストスキャン") {
                    Task {
                        await viewModel.runTestScan()
                    }
                }
                .disabled(viewModel.isRunning)
                Button("保存") {
                    do {
                        try viewModel.saveAsDefaults()
                    } catch {
                        viewModel.message = error.localizedDescription
                    }
                }
                .disabled(viewModel.isRunning)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            viewModel.reloadInsetsFromSettings()
        }
    }

    private func insetSlider(_ label: String, keyPath: WritableKeyPath<CropInsets, Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label): \(viewModel.insets[keyPath: keyPath])")
            Slider(
                value: insetBinding(keyPath),
                in: 0...100,
                step: 1
            )
            .disabled(viewModel.isRunning)
        }
    }

    private func insetBinding(_ keyPath: WritableKeyPath<CropInsets, Int>) -> Binding<Double> {
        Binding(
            get: { Double(viewModel.insets[keyPath: keyPath]) },
            set: { newValue in
                viewModel.insets[keyPath: keyPath] = Int(newValue.rounded())
                viewModel.refreshPreview()
            }
        )
    }
}
