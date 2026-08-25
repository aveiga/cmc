import Foundation

/// The only place URLs are built and the only place `URLSession` is called.
///
/// Everything here is read-only: the app never posts to the site (PLAN §1).
nonisolated enum SiteClient {

    static let host = "marista-carcavelos.globaleduca.com"
    static let baseURL = URL(string: "https://\(host)/")!

    /// The background identifier declared in `Config/Info.plist`.
    static let backgroundTaskIdentifier = "com.andreveiga.cmc.destaques-refresh"

    // MARK: - Pages

    static var homepageURL: URL { baseURL }
    static var calendarURL: URL { baseURL.appendingPathComponent("calendario-geral") }
    static var ementasURL: URL {
        baseURL.appendingPathComponent("oferecemos/refeitorio-ementas")
    }

    static func isSiteHost(_ url: URL) -> Bool {
        url.host()?.lowercased().hasSuffix(host) ?? false
    }

    // MARK: - Session

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        // The site sends `cache-control: max-age=0` and no ETag (PLAN §2.1), so
        // the URL cache buys us nothing and only risks serving stale HTML.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func html(from url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        try check(response, url: url)
        // The site declares UTF-8; fall back to Latin-1 rather than failing,
        // because a mis-declared page should still render.
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .isoLatin1) { return text }
        throw SiteError.undecodable(url)
    }

    static func homepageHTML() async throws -> String {
        try await html(from: homepageURL)
    }

    static func calendarHTML() async throws -> String {
        try await html(from: calendarURL)
    }

    static func ementasHTML() async throws -> String {
        try await html(from: ementasURL)
    }

    // MARK: - `ultima_hora` REST API

    /// A trimmed `ultima_hora` post. Deliberately has no URL: the API does not
    /// expose one (PLAN §2.2) and the daily poll does not need one (PLAN §3.1).
    struct Post: Codable, Hashable, Identifiable {
        struct Rendered: Codable, Hashable { let rendered: String }
        let id: Int
        let date: String
        let title: Rendered

        var titleText: String { title.rendered.decodingHTMLEntities() }
        var publishedAt: Date? { SiteClient.wordPressDateFormatter.date(from: date) }
    }

    /// WordPress returns local time with no zone marker, e.g. `2026-08-18T12:00:41`.
    static let wordPressDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Lisbon")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    /// The cheap, stable path used by the daily poll — a few hundred bytes of
    /// JSON instead of 579 KB of HTML (PLAN §6.3).
    static func recentPosts(limit: Int = 20) async throws -> [Post] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("wp-json/wp/v2/ultima_hora"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "orderby", value: "date"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: String(limit)),
            URLQueryItem(name: "_fields", value: "id,date,title"),
        ]
        let url = components.url!
        let (data, response) = try await session.data(from: url)
        try check(response, url: url)
        return try JSONDecoder().decode([Post].self, from: data)
    }

    // MARK: - Downloads

    /// Downloads a file to a temporary location so QuickLook can preview it.
    /// The returned URL keeps the original filename, which QuickLook uses to
    /// pick a preview handler and which the share sheet shows to the user.
    static func downloadToTemporaryFile(_ url: URL) async throws -> URL {
        let (temp, response) = try await session.download(from: url)
        try check(response, url: url)
        let name = url.lastPathComponent.isEmpty ? "ficheiro" : url.lastPathComponent
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let file = destination.appendingPathComponent(name)
        try FileManager.default.moveItem(at: temp, to: file)
        return file
    }

    // MARK: - Errors

    enum SiteError: LocalizedError {
        case httpStatus(Int, URL)
        case undecodable(URL)

        var errorDescription: String? {
            switch self {
            case .httpStatus(let code, _):
                return "O site respondeu com o erro \(code)."
            case .undecodable:
                return "Não foi possível ler a resposta do site."
            }
        }
    }

    private static func check(_ response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw SiteError.httpStatus(http.statusCode, url)
        }
    }
}

nonisolated extension String {
    /// WordPress renders titles with HTML entities (`&#8211;`, `&amp;`).
    /// Cheap, allocation-light unescaping of the entities the site actually uses.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }
        var out = self
        let simple = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#039;": "'", "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
            "&#8211;": "–", "&ndash;": "–", "&#8212;": "—", "&mdash;": "—",
            "&#8216;": "\u{2018}", "&#8217;": "\u{2019}",
            "&#8220;": "\u{201C}", "&#8221;": "\u{201D}",
            "&hellip;": "…", "&#8230;": "…",
        ]
        for (entity, replacement) in simple {
            out = out.replacingOccurrences(of: entity, with: replacement)
        }
        return out
    }

    /// Trims whitespace, non-breaking spaces and stray newlines. The site leaves
    /// trailing whitespace inside date elements ("22 de setembro ").
    func cleaned() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
