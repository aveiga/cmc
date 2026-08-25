import Foundation
import SwiftSoup

/// The two three-column tables at the top of `/calendario-geral/` — "Semestres
/// letivos" and "Pausas letivas" — plus the academic year read off them.
///
/// Split out of `CalendarParser` only to keep both files small.
nonisolated extension CalendarParser {



    /// True when the table's very first cell contains one of `markers`. Tables
    /// are never picked by index: the page also carries several unrelated
    /// cookie-consent tables.
    static func marker(_ table: Element, matches markers: [String]) -> Bool {
        guard let firstCell = try? table.select(Selectors.tableCell).first(),
              let text = try? firstCell.text() else { return false }
        let key = text.normalizedForMatching()
        return markers.contains { key.contains($0.normalizedForMatching()) }
    }

    /// Reads a three-column table, skipping its header row.
    static func rows(of table: Element?) -> [CalendarTableRow] {
        guard let table, let rows = try? table.select(Selectors.tableRow).array() else { return [] }

        return rows.dropFirst().compactMap { row in
            guard let cells = try? row.select(Selectors.tableCell).array(), cells.count >= 3
            else { return nil }
            let label = ((try? cells[0].text())?.cleaned()) ?? ""
            guard !label.isEmpty else { return nil }
            return CalendarTableRow(
                label: label,
                startLines: linesSplitByBreaks(in: cells[1]),
                endLines: linesSplitByBreaks(in: cells[2])
            )
        }
    }

    // MARK: - Academic year

    /// Reads the school year off the "Semestres letivos" table, falling back to
    /// today's date if that table has gone.
    static func academicYear(
        from semesters: [CalendarTableRow],
        now: Date
    ) -> (start: Int, end: Int) {
        let text = semesters.map { "\($0.label) \($0.startText) \($0.endText)" }.joined(separator: " ")
        let years = allYears(in: text)
        if let first = years.min(), let last = years.max(), last > first {
            return (first, last)
        }

        let calendar = DateExpressionParser.calendar
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        return month >= 9 ? (year, year + 1) : (year - 1, year)
    }

    private static func allYears(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: Selectors.yearPattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).flatMap { Int(text[$0]) }
        }
    }
}
