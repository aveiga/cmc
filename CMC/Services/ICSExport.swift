import Foundation

/// Writes the school year out as an `.ics` file for the share sheet.
///
/// Ambiguous entries (`8 ou 22 de maio`) and ones we could not parse are
/// **deliberately excluded** — exporting them would mean choosing a date on the
/// user's behalf (PLAN §5.3). The count of what was left out is reported so the
/// UI can say so out loud.
nonisolated enum ICSExport {

    struct Result {
        let fileURL: URL
        let exportedCount: Int
        /// Events skipped because their date is ambiguous or unreadable.
        let skippedCount: Int
    }

    /// Exports a single event, for platforms without `EKEventEditViewController`.
    static func write(event: CalendarEvent) throws -> Result {
        let wrapper = CalendarYear(
            startYear: 0, endYear: 0, semesters: [], breaks: [],
            months: [MonthSection(name: "", monthNumber: 1, year: 0, events: [event])]
        )
        return try write(wrapper, filename: "Evento-CMC.ics")
    }

    static func write(
        _ year: CalendarYear,
        filename: String? = nil
    ) throws -> Result {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//CMC//Calendario Marista Carcavelos//PT",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:Calendário CMC \(year.label)",
        ]

        var exported = 0
        var skipped = 0

        for month in year.months {
            for event in month.events {
                guard event.isExportable,
                      let start = event.sortDate,
                      let end = event.lastDate else {
                    skipped += 1
                    continue
                }

                switch event.dates {
                case .discrete(let dates):
                    // Two separate days, not a range: one VEVENT each.
                    for date in dates {
                        lines += vevent(event: event, start: date, endInclusive: date, uidSuffix: "\(date.timeIntervalSince1970)")
                        exported += 1
                    }
                default:
                    lines += vevent(event: event, start: start, endInclusive: end, uidSuffix: "")
                    exported += 1
                }
            }
        }

        lines.append("END:VCALENDAR")

        let name = filename ?? "Calendario-CMC-\(year.startYear)-\(year.endYear).ics"
        // Each export gets its own temp directory: the filename is derived from the school
        // year, so two exports of the same year would otherwise overwrite one another at a
        // shared path. Keeping the directory unique preserves the readable share filename.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try lines.joined(separator: "\r\n").data(using: .utf8)?.write(to: url, options: .atomic)
        return Result(fileURL: url, exportedCount: exported, skippedCount: skipped)
    }

    // MARK: - Serialisation

    private static func vevent(
        event: CalendarEvent, start: Date, endInclusive: Date, uidSuffix: String
    ) -> [String] {
        // All-day VEVENTs use an exclusive DTEND, so add a day.
        let calendar = DateExpressionParser.calendar
        let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: endInclusive) ?? endInclusive

        return [
            "BEGIN:VEVENT",
            "UID:\(event.id)\(uidSuffix.isEmpty ? "" : "-" + uidSuffix)@cmc.app",
            "DTSTAMP:\(timestamp(Date()))",
            "DTSTART;VALUE=DATE:\(day(start))",
            "DTEND;VALUE=DATE:\(day(exclusiveEnd))",
            "SUMMARY:\(escape(event.titles.joined(separator: " · ")))",
            "DESCRIPTION:\(escape("Calendário do Colégio Marista de Carcavelos — \(event.rawDate)"))",
            "TRANSP:TRANSPARENT",
            "END:VEVENT",
        ]
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = DateExpressionParser.calendar.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    /// RFC 5545 text escaping.
    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
