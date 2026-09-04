import SwiftUI
import PDFKit

/// The app's only PDF viewer. Reused by Destaques and Ementas (PLAN §5.4).
struct PDFSheet: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ContentUnavailableView {
                        Label("Não foi possível abrir o PDF", systemImage: "doc.questionmark")
                    } description: {
                        Text("O ficheiro pode ter sido movido ou removido do site.")
                    } actions: {
                        Link("Abrir no navegador", destination: url)
                    }
                } else {
                    PDFKitView(url: url, loadFailed: $loadFailed)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url) {
                        Label("Partilhar", systemImage: "square.and.arrow.up")
                    }
                }
            }
            // PDFKit's scroll view is invisible to the navigation bar, so the
            // bar never turns opaque on scroll and the buttons end up sitting
            // on the page itself. Pin it.
            .opaqueNavigationBar()
        }
        .macWindowSize(minWidth: 480, minHeight: 560)
    }
}

/// `PDFView` is a `UIView` on iOS and an `NSView` on macOS, so the wrapper
/// differs; everything inside it is identical.
private struct PDFKitView {
    let url: URL
    @Binding var loadFailed: Bool

    func makeView() -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        load(into: view)
        return view
    }

    func updateView(_ view: PDFView) {
        guard view.document?.documentURL != url else { return }
        load(into: view)
    }

    /// `PDFDocument(url:)` blocks while it downloads, so it is fetched off the
    /// main thread and handed back when ready.
    private func load(into view: PDFView) {
        Task.detached(priority: .userInitiated) {
            let document = PDFDocument(url: url)
            await MainActor.run {
                if let document {
                    view.document = document
                } else {
                    loadFailed = true
                }
            }
        }
    }
}

#if os(iOS)
extension PDFKitView: UIViewRepresentable {
    func makeUIView(context: Context) -> PDFView { makeView() }
    func updateUIView(_ view: PDFView, context: Context) { updateView(view) }
}
#else
extension PDFKitView: NSViewRepresentable {
    func makeNSView(context: Context) -> PDFView { makeView() }
    func updateNSView(_ view: PDFView, context: Context) { updateView(view) }
}
#endif
