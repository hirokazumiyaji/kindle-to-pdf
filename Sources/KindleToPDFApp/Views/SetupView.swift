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

            Section("ウィンドウ") {
                Picker("Kindleウィンドウ", selection: $viewModel.windowTitle) {
                    Text("自動").tag("")
                    ForEach(viewModel.availableWindows, id: \.windowID) { window in
                        Text(window.title.isEmpty ? "無題" : window.title)
                            .tag(window.title)
                    }
                }
                .disabled(viewModel.isRunning)
                TextField("ウィンドウタイトル（任意）", text: $viewModel.windowTitle)
                    .disabled(viewModel.isRunning)
                Button("ウィンドウを再読み込み") {
                    viewModel.refreshWindows()
                }
                .disabled(viewModel.isRunning)
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
            viewModel.refreshWindows()
        }
    }

    private static let maxInsetFraction = 0.5

    private func insetSlider(_ label: String, keyPath: WritableKeyPath<CropInsets, Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                TextField(
                    label,
                    value: insetValueBinding(keyPath),
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isRunning)
            }
            Slider(
                value: insetBinding(keyPath),
                in: insetRange(keyPath),
                step: 1
            )
            .disabled(viewModel.isRunning)
        }
    }

    /// スライダーの上限はテストスキャン画像の各辺に対する割合で決める。
    /// キャプチャはRetinaで数千pxになるため、固定のpx上限では足りなくなる。
    private func insetRange(_ keyPath: WritableKeyPath<CropInsets, Int>) -> ClosedRange<Double> {
        guard let size = viewModel.baseImageSize else { return 0...100 }
        let isHorizontal = keyPath == \CropInsets.left || keyPath == \CropInsets.right
        let dimension = isHorizontal ? size.width : size.height
        let maxInset = (dimension * Self.maxInsetFraction).rounded()
        return 0...max(100, maxInset)
    }

    private func insetBinding(_ keyPath: WritableKeyPath<CropInsets, Int>) -> Binding<Double> {
        Binding(
            get: { Double(viewModel.insets[keyPath: keyPath]) },
            set: { newValue in
                updateInset(Int(newValue.rounded()), keyPath: keyPath)
            }
        )
    }

    private func insetValueBinding(_ keyPath: WritableKeyPath<CropInsets, Int>) -> Binding<Int> {
        Binding(
            get: { viewModel.insets[keyPath: keyPath] },
            set: { newValue in
                updateInset(newValue, keyPath: keyPath)
            }
        )
    }

    private func updateInset(_ value: Int, keyPath: WritableKeyPath<CropInsets, Int>) {
        let range = insetRange(keyPath)
        let clampedValue = min(max(value, Int(range.lowerBound)), Int(range.upperBound))
        viewModel.insets[keyPath: keyPath] = clampedValue
        viewModel.refreshPreview()
    }
}
