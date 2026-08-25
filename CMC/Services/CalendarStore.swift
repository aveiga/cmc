import Foundation
import Observation

/// Loads the school-year calendar and remembers the last good one.
@Observable
final class CalendarStore {

    private(set) var year: CalendarYear = .empty
    private(set) var warnings: [ParseWarning] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let cache = Cache<CalendarYear>("calendario.json")

    var hasContent: Bool { !year.months.isEmpty }

    init() {
        if let entry = cache.load() {
            year = entry.value
            lastUpdated = entry.savedAt
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let html = try await SiteClient.calendarHTML()
            let (parsed, parseWarnings) = await Task.detached {
                CalendarParser.parse(html: html)
            }.value

            guard !parsed.months.isEmpty else {
                lastError = "O calendário do site não pôde ser lido."
                warnings = parseWarnings
                return
            }

            year = parsed
            warnings = parseWarnings
            lastUpdated = Date()
            lastError = nil
            cache.save(parsed, at: lastUpdated!)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Derived views of the year

    /// Every event, flattened and ordered. `.unparsed` events keep their
    /// month's position so they are never lost, only approximately placed.
    var allEvents: [DatedEvent] {
        year.months.flatMap { month in
            month.events.map { DatedEvent(event: $0, month: month) }
        }
        .sorted { $0.ordering < $1.ordering }
    }

    /// Today and onwards. A range that has started but not ended still counts.
    func upcomingEvents(now: Date = Date()) -> [DatedEvent] {
        let calendar = DateExpressionParser.calendar
        let today = calendar.startOfDay(for: now)
        return allEvents.filter { dated in
            guard let last = dated.event.lastDate ?? dated.event.sortDate else {
                // Undated entries: keep them while their month is not over.
                return dated.monthEnd >= today
            }
            return last >= today
        }
    }

    func nextBreak(now: Date = Date()) -> CalendarTableRow? {
        year.breaks.first { row in
            guard let end = firstDate(in: row.endText) ?? firstDate(in: row.startText)
            else { return false }
            return end >= DateExpressionParser.calendar.startOfDay(for: now)
        }
    }

    /// Reads "21 de dezembro 2026" out of a table cell.
    func firstDate(in text: String) -> Date? {
        guard let groups = DateExpressionParser.capture(
            text.normalizedForMatching(), Selectors.fullDatePattern
        ), groups.count == 3,
              let day = Int(groups[0]),
              let month = DateExpressionParser.month(named: groups[1]),
              let year = Int(groups[2]) else { return nil }

        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        components.hour = 12
        return DateExpressionParser.calendar.date(from: components)
    }
}

/// An event paired with the month section it came from, so the UI can group and
/// sort even when the date itself did not parse.
struct DatedEvent: Identifiable, Hashable {
    let event: CalendarEvent
    let month: MonthSection

    var id: String { event.id }

    /// Sort key: the real date when we have one, otherwise the first of the
    /// month it was listed under.
    var ordering: Date {
        event.sortDate ?? monthStart
    }

    var monthStart: Date {
        var components = DateComponents()
        components.year = month.year
        components.month = month.monthNumber
        components.day = 1
        components.hour = 12
        return DateExpressionParser.calendar.date(from: components) ?? .distantFuture
    }

    var monthEnd: Date {
        let calendar = DateExpressionParser.calendar
        guard let range = calendar.range(of: .day, in: .month, for: monthStart),
              let last = calendar.date(bySetting: .day, value: range.upperBound - 1, of: monthStart)
        else { return monthStart }
        return last
    }

    /// "Setembro 2026" — the section header in the chronological list.
    var monthTitle: String { "\(month.name) \(month.year)" }
}
