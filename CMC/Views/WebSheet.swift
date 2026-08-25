import SwiftUI
#if os(iOS)
import SafariServices
#endif

/// Web content is shown in `SFSafariViewController` — the HIG-sanctioned way to
/// present third-party pages: Reader mode, cookies shared with Safari, and a
/// visible address so the user knows they are on the web. Never a chrome-less
/// `WKWebView` dressed up as native (PLAN §5.2).
struct WebSheet: View {
    let url: URL

    var body: some View {
        #if os(iOS)
        SafariView(url: url).ignoresSafeArea()
        #else
        // macOS has no SFSafariViewController; the opener sends URLs straight
        // to the default browser, so this is only ever a fallback.
        ContentUnavailableView {
            Label("Abrir no navegador", systemImage: "safari")
        } description: {
            Text(url.absoluteString)
        } actions: {
            Link("Abrir", destination: url)
        }
        .frame(minWidth: 420, minHeight: 260)
        #endif
    }
}

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif
