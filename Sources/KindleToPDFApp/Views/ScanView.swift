import SwiftUI
import KindleToPDFCore

struct ScanView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        Form {
            Section("本") {
                TextField("表示名", text: $viewModel.displayName)
                    .disabled(viewModel.isRunning)
                TextField("ページ数（任意）", text: $viewModel.pageCountText)
                    .disabled(viewModel.isRunning)
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

            Section("ページ送り") {
                Picker("キー", selection: $viewModel.nextKey) {
                    Text("right").tag(NextKey.right)
                    Text("left").tag(NextKey.left)
                    Text("pagedown").tag(NextKey.pagedown)
                }
                .disabled(viewModel.isRunning)
            }

            Section("進捗") {
                Text("\(viewModel.capturedPageCount) ページ")
                if viewModel.resume {
                    Text("未完了セッションを再開します")
                        .foregroundStyle(.secondary)
                }
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                }
            }

            Section {
                Text("スキャン中は Kindle を前面にします。他の作業はできません。フルスクリーン表示を推奨します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("開始") {
                    viewModel.start()
                }
                .disabled(viewModel.isRunning)
                Button("停止") {
                    viewModel.stop()
                }
                .disabled(!viewModel.isRunning)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            viewModel.refreshWindows()
            model.applyPendingResumeIfNeeded()
        }
        .onChange(of: model.pendingResume) { _ in
            model.applyPendingResumeIfNeeded()
        }
    }
}
