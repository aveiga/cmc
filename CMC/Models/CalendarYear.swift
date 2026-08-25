import Foundation

/// The whole school-year calendar, as scraped from `/calendario-geral/`.
nonisolated struct CalendarYear: Codable, Hashable {
    /// e.g. 2026 → 2027, read off the "Semestres letivos" table.
    var startYear: Int
    var endYear: Int
    /// The "Semestres letivos" table.
    var semesters: [CalendarTableRow]
    /// The "Pausas letivas" table (the site has also called it "Interrupções letivas").
    var breaks: [CalendarTableRow]
    /// Twelve sections in site order, Setembro → Agosto.
    var months: [MonthSection]

    var label: String { "\(startYear)/\(endYear)" }

    static let empty = CalendarYear(
        startYear: 0, endYear: 0, semesters: [], breaks: [], months: []
    )
}

/// A row of either of the two three-column tables: label / Início / Fim.
///
/// One type for both tables because they have exactly the same shape. Cells can
/// hold several lines — e.g. *"4 de junho 2027 – 9º, 11º e 12º anos"* on its own
/// line — so each side is kept as an array rather than flattened into a string.
nonisolated struct CalendarTableRow: Identifiable, Codable, Hashable {
    var label: String
    var startLines: [String]
    var endLines: [String]

    var id: String { label }

    var startText: String { startLines.joined(separator: "\n") }
    var endText: String { endLines.joined(separator: "\n") }
}

/// One month of the site's accordion.
nonisolated struct MonthSection: Identifiable, Codable, Hashable {
    /// Title Case, verbatim from the accordion header, e.g. "Setembro".
    var name: String
    /// 1...12.
    var monthNumber: Int
    /// Resolved from the academic year: Setembro–Dezembro → first year,
    /// Janeiro–Agosto → second (PLAN §2.5).
    var year: Int
    var events: [CalendarEvent]

    var id: String { "\(year)-\(monthNumber)" }
}

/// A single `<p>` of the accordion: one date line plus one or more event lines.
nonisolated struct CalendarEvent: Identifiable, Codable, Hashable {
    var id: String
    /// The date line verbatim, e.g. "8 ou 22 de maio". Always shown to the user,
    /// whatever `dates` managed to parse — an ugly row beats a missing one.
    var rawDate: String
    var dates: DateExpression
    /// One or more event titles sharing that date.
    var titles: [String]

    /// Used for ordering and for the "Próximos" filter. `nil` for `.unparsed`.
    var sortDate: Date? { dates.firstDate }

    /// The last day this event is relevant, so a running range stays in "Próximos".
    var lastDate: Date? { dates.lastDate }

    /// `.eitherOr` and `.unparsed` must not be exported — we would be guessing
    /// a date on the user's behalf (PLAN §5.3).
    var isExportable: Bool {
        switch dates {
        case .single, .range, .discrete: return true
        case .eitherOr, .unparsed: return false
        }
    }
}

/// The five date shapes the calendar page actually uses (PLAN §2.5), plus an
/// escape hatch.
///
/// `.unparsed` is load-bearing: an unrecognised format must still be displayed
/// verbatim, never dropped.
nonisolated enum DateExpression: Codable, Hashable {
    /// "2 de setembro"
    case single(Date)
    /// "7 a 10 de setembro", "30 de março a 2 de abril" — inclusive
    case range(Date, Date)
    /// "27 e 28 de janeiro" — two discrete days
    case discrete([Date])
    /// "8 ou 22 de maio" — genuinely ambiguous. Surface both, never pick one.
    case eitherOr([Date])
    /// Anything we did not recognise. Carries the raw text.
    case unparsed(String)

    var firstDate: Date? {
        switch self {
        case .single(let d): return d
        case .range(let a, _): return a
        case .discrete(let ds), .eitherOr(let ds): return ds.min()
        case .unparsed: return nil
        }
    }

    var lastDate: Date? {
        switch self {
        case .single(let d): return d
        case .range(_, let b): return b
        case .discrete(let ds), .eitherOr(let ds): return ds.max()
        case .unparsed: return nil
        }
    }

    /// Every concrete day this expression names, for `.ics` export.
    var allDates: [Date] {
        switch self {
        case .single(let d): return [d]
        case .range(let a, let b): return [a, b]
        case .discrete(let ds), .eitherOr(let ds): return ds
        case .unparsed: return []
        }
    }
}
