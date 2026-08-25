import SwiftUI

/// The one place a URL becomes a screen. Every tap that opens something —
/// Destaques and Ementas alike — goes through here, so there is only ever one
/// PDF viewer in the app (PLAN §5.4).
///
/// | Target | Presentation |
/// |---|---|
/// | PDF | in-app PDFKit sheet with a `ShareLink` |
/// | web page (ours or not) | `SFSafariViewController` |
/// | other file | downloaded, then QuickLook |
///
/// On macOS, where neither `SFSafariViewController` nor `QLPreviewController`
/// exists, web pages and other files are handed to the system instead.
@Observable
final class DestaqueOpener {

    enum Presentation: Identifiable {
        case pdf(URL, title: String)
        case web(URL)
        case file(URL, title: String)

        var id: String {
            switch self {
            case .pdf(let url, _), .web(let url), .file(let url, _): return url.absoluteString
            }
        }
    }

    var presentation: Presentation?
    var isDownloading = false
    var downloadError: String?

    func open(_ destaque: Destaque) {
        open(url: destaque.url, title: destaque.title, kind: destaque.kind)
    }

    func open(_ ementa: Ementa) {
        open(url: ementa.url, title: "\(ementa.track) — \(ementa.displayTitle)", kind: .pdf)
    }

    func open(url: URL, title: String, kind: Destaque.Kind) {
        switch kind {
        case .pdf:
            presentation = .pdf(url, title: title)

        case .webPage, .externalWebPage:
            #if os(iOS)
            presentation = .web(url)
            #else
            Platform.openExternally(url)
            #endif

        case .otherFile:
            Task { await download(url, title: title) }
        }
    }

    private func download(_ url: URL, title: String) async {
        isDownloading = true
        defer { isDownloading = false }
        do {
            let file = try await SiteClient.downloadToTemporaryFile(url)
            #if os(iOS)
            presentation = .file(file, title: title)
            #else
            Platform.openExternally(file)
            #endif
        } catch {
            downloadError = error.localizedDescription
        }
    }
}

// MARK: - Sheet host

extension View {
    /// Attaches the opener's sheet. Applied once per screen.
    func destaqueSheets(_ opener: DestaqueOpener) -> some View {
        modifier(DestaqueSheetModifier(opener: opener))
    }
}

private struct DestaqueSheetModifier: ViewModifier {
    @Bindable var opener: DestaqueOpener

    func body(content: Content) -> some View {
        content
            .sheet(item: $opener.presentation) { presentation in
                switch presentation {
                case .pdf(let url, let title):
                    PDFSheet(url: url, title: title)
                case .web(let url):
                    WebSheet(url: url)
                case .file(let url, let title):
                    QuickLookSheet(url: url, title: title)
                }
            }
            .overlay {
                if opener.isDownloading {
                    ProgressView("A transferir…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert(
                "Não foi possível abrir",
                isPresented: Binding(
                    get: { opener.downloadError != nil },
                    set: { if !$0 { opener.downloadError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { opener.downloadError = nil }
            } message: {
                Text(opener.downloadError ?? "")
            }
    }
}
