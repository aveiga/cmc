import Foundation
import Observation

/// Loads the canteen menus and remembers the last good set.
@Observable
final class EmentasStore {

    private(set) var tracks: [EmentaTrack] = []
    private(set) var warnings: [ParseWarning] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var lastError: String?
    /// True once a refresh has completed, so an empty page reads as
    /// "sem ementas publicadas" rather than "ainda a carregar".
    private(set) var hasLoadedOnce = false

    private let cache = Cache<[EmentaTrack]>("ementas.json")

    init() {
        if let entry = cache.load() {
            tracks = entry.value
            lastUpdated = entry.savedAt
            hasLoadedOnce = true
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let html = try await SiteClient.ementasHTML()
            let (parsed, parseWarnings) = await Task.detached {
                EmentasParser.parse(html: html)
            }.value

            // An empty result here is a legitimate state, not a failure: the
            // school leaves this page stale for months at a time (PLAN §2.6).
            tracks = parsed
            warnings = parseWarnings
            lastUpdated = Date()
            lastError = nil
            hasLoadedOnce = true
            cache.save(parsed, at: lastUpdated!)
        } catch {
            lastError = error.localizedDescription
            hasLoadedOnce = true
        }
    }
}
