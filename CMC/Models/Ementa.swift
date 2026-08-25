import Foundation

/// One monthly canteen menu PDF.
///
/// The track comes from the `h4` heading it sits under — never from the
/// filename, which is inconsistently cased and sometimes misspelled
/// (`CARACAVELOS`, PLAN §2.6). URLs are always taken verbatim from the page;
/// we never synthesise one from a pattern.
nonisolated struct Ementa: Identifiable, Codable, Hashable {
    /// Verbatim from the `h4`, e.g. "Pré-Escolar" or "Geral".
    var track: String
    /// Verbatim link text, e.g. "junho".
    var monthLabel: String
    /// 1...12, when we could work it out.
    var month: Int?
    var year: Int?
    var url: URL

    var id: String { url.absoluteString }

    /// "Junho 2026", falling back to just the label when the date is unknown.
    var displayTitle: String {
        let name = monthLabel.prefix(1).uppercased() + monthLabel.dropFirst()
        guard let year else { return name }
        return "\(name) \(year)"
    }

    /// Sort key: newest first, unknown dates last.
    var sortKey: Int {
        guard let year, let month else { return .min }
        return year * 100 + month
    }

    func isCurrentMonth(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let month, let year else { return false }
        let parts = calendar.dateComponents([.month, .year], from: now)
        return parts.month == month && parts.year == year
    }
}

/// Ementas grouped by track, in the `h4` order the page uses.
///
/// The track names are *not* hardcoded, so a third track appearing on the site
/// does not require a code change (PLAN §4.2).
nonisolated struct EmentaTrack: Identifiable, Codable, Hashable {
    var name: String
    var ementas: [Ementa]
    var id: String { name }
}
