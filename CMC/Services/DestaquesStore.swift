import Foundation
import Observation

/// Loads the Destaques list and remembers the last good one.
///
/// Adding a screen means copying this file and its view (PLAN §9) — the three
/// stores are deliberately near-identical rather than sharing a generic base.
@Observable
final class DestaquesStore {

    private(set) var destaques: [Destaque] = []
    private(set) var warnings: [ParseWarning] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    /// Set when a refresh failed *and* we had something cached to fall back to.
    private(set) var lastError: String?

    private let cache = Cache<[Destaque]>("destaques.json")

    init() {
        if let entry = cache.load() {
            destaques = entry.value
            lastUpdated = entry.savedAt
        }
    }

    /// Shows cached content immediately and replaces it only when a refresh
    /// actually succeeds.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let html = try await SiteClient.homepageHTML()
            let (scraped, parseWarnings) = await Task.detached {
                DestaquesParser.parse(html: html)
            }.value

            guard !scraped.isEmpty else {
                lastError = "A secção «Destaques» do site não pôde ser lida."
                warnings = parseWarnings
                return
            }

            // The API cannot give us URLs, only dates and ids — a nice-to-have.
            // If it fails, keep the scraped list exactly as it is (PLAN §4.1).
            let merged: [Destaque]
            if let posts = try? await SiteClient.recentPosts() {
                merged = DestaquesParser.merging(scraped, with: posts)
            } else {
                merged = scraped
            }

            destaques = merged
            warnings = parseWarnings
            lastUpdated = Date()
            lastError = nil
            cache.save(merged, at: lastUpdated!)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Used by the notification deep link: find the row matching a post id.
    func destaque(withPostID id: Int) -> Destaque? {
        destaques.first { $0.postID == id }
    }
}
