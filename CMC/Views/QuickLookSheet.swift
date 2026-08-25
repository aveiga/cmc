import SwiftUI
#if os(iOS)
import QuickLook
#endif

/// Preview for file types PDFKit cannot show — Word, Excel, and anything else
/// the school decides to link (PLAN §5.2).
struct QuickLookSheet: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
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
        }
    }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        QuickLookView(url: url).ignoresSafeArea(edges: .bottom)
        #else
        // macOS opens downloaded files with the system default app instead.
        ContentUnavailableView {
            Label("Ficheiro transferido", systemImage: "doc")
        } description: {
            Text(url.lastPathComponent)
        } actions: {
            Button("Abrir") { Platform.openExternally(url) }
        }
        .frame(minWidth: 420, minHeight: 260)
        #endif
    }
}

#if os(iOS)
private struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(
            _ controller: QLPreviewController, previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif
