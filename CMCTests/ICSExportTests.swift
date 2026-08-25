import Testing
import Foundation
@testable import CMC

/// The `.ics` export must never guess a date on the user's behalf (PLAN §5.3).
@Suite("ICS export")
struct ICSExportTests {

    private func year() throws -> CalendarYear {
        CalendarParser.parse(html: try Fixture.html("calendario")).0
    }

    @Test("Ambiguous and unreadable events are excluded, and counted")
    func skipsAmbiguousEvents() throws {
        let year = try year()
        let result = try ICSExport.write(year)
        let expectedSkips = year.months
            .flatMap(\.events)
            .filter { !$0.isExportable }
            .count

        #expect(expectedSkips == 1, "the fixture has exactly one «ou» entry")
        #expect(result.skippedCount == expectedSkips)
        #expect(result.exportedCount > 100)
    }

    @Test("Produces a well-formed calendar file")
    func wellFormed() throws {
        let result = try ICSExport.write(try year())
        let text = try String(contentsOf: result.fileURL, encoding: .utf8)

        #expect(text.hasPrefix("BEGIN:VCALENDAR"))
        #expect(text.hasSuffix("END:VCALENDAR"))
        #expect(text.contains("\r\n"), "RFC 5545 requires CRLF line endings")

        let begins = text.components(separatedBy: "BEGIN:VEVENT").count - 1
        let ends = text.components(separatedBy: "END:VEVENT").count - 1
        #expect(begins == ends)
        #expect(begins == result.exportedCount)

        // The ambiguous entry must not appear anywhere in the file.
        #expect(!text.contains("8 ou 22 de maio"))
    }

    @Test("All-day events use an exclusive DTEND")
    func exclusiveEnd() throws {
        let date = DateExpressionParser.calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 2, hour: 12)
        )!
        let year = CalendarYear(
            startYear: 2026, endYear: 2027, semesters: [], breaks: [],
            months: [MonthSection(name: "Setembro", monthNumber: 9, year: 2026, events: [
                CalendarEvent(id: "e1", rawDate: "2 de setembro",
                              dates: .single(date), titles: ["Início"])
            ])]
        )
        let text = try String(contentsOf: ICSExport.write(year).fileURL, encoding: .utf8)
        #expect(text.contains("DTSTART;VALUE=DATE:20260902"))
        #expect(text.contains("DTEND;VALUE=DATE:20260903"))
    }

    @Test("Two discrete days become two separate events")
    func discreteDaysSplit() throws {
        let calendar = DateExpressionParser.calendar
        let a = calendar.date(from: DateComponents(year: 2027, month: 1, day: 27, hour: 12))!
        let b = calendar.date(from: DateComponents(year: 2027, month: 1, day: 28, hour: 12))!
        let year = CalendarYear(
            startYear: 2026, endYear: 2027, semesters: [], breaks: [],
            months: [MonthSection(name: "Janeiro", monthNumber: 1, year: 2027, events: [
                CalendarEvent(id: "e1", rawDate: "27 e 28 de janeiro",
                              dates: .discrete([a, b]), titles: ["Provas"])
            ])]
        )
        let result = try ICSExport.write(year)
        #expect(result.exportedCount == 2)
        let text = try String(contentsOf: result.fileURL, encoding: .utf8)
        #expect(text.contains("DTSTART;VALUE=DATE:20270127"))
        #expect(text.contains("DTSTART;VALUE=DATE:20270128"))
    }
}
