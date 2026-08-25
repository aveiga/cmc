import Foundation

/// Reads the calendar page's date lines, which carry no year and come in five
/// shapes (PLAN §2.5).
///
/// Anything it does not recognise becomes `.unparsed`, which the UI still shows
/// verbatim. It never guesses: `8 ou 22 de maio` stays ambiguous all the way to
/// the screen.
nonisolated enum DateExpressionParser {

    /// Portugal. Dates are built at midday so that a timezone shift can never
    /// move an all-day event onto the previous or next day.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .current
        return calendar
    }

    /// - Parameters:
    ///   - text: the raw date line, e.g. `"30 de março a 2 de abril"`.
    ///   - sectionMonth: the accordion month the line was found under (1...12),
    ///     used only to place a year on months the line itself names.
    ///   - academicYear: the school year, e.g. 2026 → 2027.
    static func parse(
        _ text: String,
        sectionMonth: Int,
        academicYear: (start: Int, end: Int)
    ) -> DateExpression {
        let line = text.cleaned()
        let key = line.normalizedForMatching()

        func year(for month: Int) -> Int {
            // Setembro–Dezembro belong to the first year, Janeiro–Agosto to the
            // second (PLAN §2.5).
            month >= 9 ? academicYear.start : academicYear.end
        }

        func date(day: Int, month: Int, yearOverride: Int? = nil) -> Date? {
            var components = DateComponents()
            components.day = day
            components.month = month
            components.year = yearOverride ?? year(for: month)
            components.hour = 12
            guard let date = calendar.date(from: components),
                  calendar.component(.day, from: date) == day else { return nil }
            return date
        }

        // "30 de março a 2 de abril" — most specific first.
        if let m = capture(key, Selectors.dateCrossMonthRange),
           let startDay = Int(m[0]), let startMonth = month(named: m[1]),
           let endDay = Int(m[2]), let endMonth = month(named: m[3]) {
            let startYear = year(for: startMonth)
            // A range that wraps December → January lands in the next year.
            let endYear = endMonth < startMonth ? startYear + 1 : year(for: endMonth)
            if let start = date(day: startDay, month: startMonth, yearOverride: startYear),
               let end = date(day: endDay, month: endMonth, yearOverride: endYear) {
                return .range(start, end)
            }
        }

        // "7 a 10 de setembro"
        if let m = capture(key, Selectors.dateRange),
           let startDay = Int(m[0]), let endDay = Int(m[1]), let month = month(named: m[2]),
           let start = date(day: startDay, month: month), let end = date(day: endDay, month: month) {
            return .range(start, end)
        }

        // "27 e 28 de janeiro"
        if let m = capture(key, Selectors.dateDiscrete),
           let first = Int(m[0]), let second = Int(m[1]), let month = month(named: m[2]),
           let a = date(day: first, month: month), let b = date(day: second, month: month) {
            return .discrete([a, b])
        }

        // "8 ou 22 de maio" — genuinely ambiguous; both are surfaced, neither chosen.
        if let m = capture(key, Selectors.dateEitherOr),
           let first = Int(m[0]), let second = Int(m[1]), let month = month(named: m[2]),
           let a = date(day: first, month: month), let b = date(day: second, month: month) {
            return .eitherOr([a, b])
        }

        // "2 de setembro"
        if let m = capture(key, Selectors.dateSingle),
           let day = Int(m[0]), let month = month(named: m[1]),
           let value = date(day: day, month: month) {
            return .single(value)
        }

        _ = sectionMonth  // kept in the signature: a future format may need it.
        return .unparsed(line)
    }

    // MARK: - Helpers

    static func month(named name: String) -> Int? {
        let key = name.normalizedForMatching()
        return Selectors.monthNames.firstIndex { $0.normalizedForMatching() == key }
            .map { $0 + 1 }
    }

    /// Returns the capture groups of the first match, or `nil`.
    static func capture(_ text: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}
