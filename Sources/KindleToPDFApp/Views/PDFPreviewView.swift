import AppKit
import PDFKit
import SwiftUI

struct PDFPreviewItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct PDFPreviewView: View {
    let url: URL

    var body: some View {
        PDFKitRepresentedView(url: url)
    }
}

struct PDFKitRepresentedView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}
