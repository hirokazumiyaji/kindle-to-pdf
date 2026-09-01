import SwiftUI
import KindleToPDFCore

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: LibraryViewModel
    @State private var previewItem: PDFPreviewItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding([.horizontal, .top])
            }

            if viewModel.books.isEmpty {
                ContentUnavailablePlaceholder()
            } else {
                List(viewModel.books) { book in
                    LibraryRow(book: book) {
                        openPreview(book)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        openPreview(book)
                    }
                    .contextMenu {
                        Button("再開") {
                            viewModel.resume(id: book.id)
                        }
                        Button("PDFを再生成") {
                            do {
                                try viewModel.regeneratePDF(id: book.id)
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                        Button("Finderに表示") {
                            viewModel.revealInFinder(id: book.id)
                        }
                        Divider()
                        Button("削除", role: .destructive) {
                            viewModel.delete(id: book.id)
                        }
                    }
                }
            }
        }
        .sheet(item: $previewItem) { item in
            PDFPreviewView(url: item.url)
                .frame(minWidth: 700, minHeight: 800)
        }
        .onAppear {
            viewModel.reload()
        }
    }

    private func openPreview(_ book: BookEntry) {
        guard let url = viewModel.pdfURLIfAvailable(for: book) else { return }
        previewItem = PDFPreviewItem(url: url)
    }
}

private struct LibraryRow: View {
    let book: BookEntry
    let onPreview: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.displayName)
                    .font(.headline)
                HStack(spacing: 8) {
                    StatusBadge(status: book.status)
                    Text("\(book.capturedPageCount) ページ")
                        .foregroundStyle(.secondary)
                    Text(Self.dateFormatter.string(from: book.updatedAt))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Spacer()
            if book.pdfPath != nil {
                Button("プレビュー", action: onPreview)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

private struct StatusBadge: View {
    let status: BookStatus

    var body: some View {
        Text(title)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var title: String {
        switch status {
        case .scanning: return "スキャン中"
        case .ready: return "準備完了"
        case .completed: return "完了"
        }
    }

    private var color: Color {
        switch status {
        case .scanning: return .orange
        case .ready: return .blue
        case .completed: return .green
        }
    }
}

private struct ContentUnavailablePlaceholder: View {
    var body: some View {
        Text("ライブラリは空です")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
