import Foundation

/// One entry of the homepage "Destaques" list.
///
/// The destination URL only exists in the rendered homepage HTML — the
/// `ultima_hora` REST API does not expose it (PLAN §2.2). So a `Destaque`
/// always comes from the scrape; `postID` and `publishedAt` are optional
/// extras joined in from the API when that succeeds.
nonisolated struct Destaque: Identifiable, Codable, Hashable {

    /// What tapping the row will do. Derived from the URL, never from the site.
    enum Kind: String, Codable {
        case pdf
        case webPage
        case externalWebPage
        case otherFile
    }

    /// WordPress post id, when the API join succeeded.
    var postID: Int?
    /// e.g. "Circular"
    var title: String
    /// The call-to-action label, e.g. "Agosto 2026" or "Consultar".
    var ctaLabel: String?
    var url: URL
    var publishedAt: Date?

    /// Stable across refreshes: the same Destaque keeps the same target URL.
    var id: String { url.absoluteString }

    var kind: Kind { Destaque.kind(for: url) }

    // MARK: - Kind derivation

    /// Extensions we can preview with QuickLook but not with PDFKit.
    private static let documentExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp",
        "rtf", "csv", "zip", "pages", "numbers", "key",
    ]

    static func kind(for url: URL) -> Kind {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return .pdf }
        if documentExtensions.contains(ext) { return .otherFile }
        return SiteClient.isSiteHost(url) ? .webPage : .externalWebPage
    }

    // MARK: - Presentation

    /// SF Symbol telling the user what a tap will do before they tap (PLAN §5.2).
    var symbolName: String {
        switch kind {
        case .pdf: return "doc.richtext"
        case .otherFile: return "doc"
        case .externalWebPage: return "safari"
        case .webPage: return "chevron.right"
        }
    }

    var accessibilityKindDescription: String {
        switch kind {
        case .pdf: return "Documento PDF"
        case .otherFile: return "Ficheiro"
        case .externalWebPage: return "Página externa"
        case .webPage: return "Página do colégio"
        }
    }
}
