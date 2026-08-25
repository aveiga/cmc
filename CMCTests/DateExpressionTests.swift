import Testing
import Foundation
@testable import CMC

/// All five date formats from PLAN §2.5, plus the escape hatch.
@Suite("Date expressions")
struct DateExpressionTests {

    private let academicYear = (start: 2026, end: 2027)

    private func parse(_ text: String, month: Int = 9) -> DateExpression {
        DateExpressionParser.parse(text, sectionMonth: month, academicYear: academicYear)
    }

    private func components(_ date: Date) -> (day: Int, month: Int, year: Int) {
        let parts = DateExpressionParser.calendar.dateComponents([.day, .month, .year], from: date)
        return (parts.day!, parts.month!, parts.year!)
    }

    @Test("D de MONTH")
    func single() throws {
        guard case .single(let date) = parse("2 de setembro") else {
            Issue.record("expected .single"); return
        }
        #expect(components(date) == (2, 9, 2026))
    }

    @Test("D a D de MONTH")
    func range() throws {
        guard case .range(let start, let end) = parse("7 a 10 de setembro") else {
            Issue.record("expected .range"); return
        }
        #expect(components(start) == (7, 9, 2026))
        #expect(components(end) == (10, 9, 2026))
    }

    @Test("D e D de MONTH")
    func discrete() throws {
        guard case .discrete(let dates) = parse("27 e 28 de janeiro", month: 1) else {
            Issue.record("expected .discrete"); return
        }
        #expect(dates.count == 2)
        // Janeiro belongs to the second half of the academic year.
        #expect(components(dates[0]) == (27, 1, 2027))
        #expect(components(dates[1]) == (28, 1, 2027))
    }

    @Test("D de MONTH a D de MONTH")
    func crossMonthRange() throws {
        guard case .range(let start, let end) = parse("30 de março a 2 de abril", month: 3) else {
            Issue.record("expected .range"); return
        }
        #expect(components(start) == (30, 3, 2027))
        #expect(components(end) == (2, 4, 2027))
    }

    /// The ambiguous one. Both dates must survive; neither may be chosen.
    @Test("D ou D de MONTH stays ambiguous and is never exportable")
    func eitherOr() throws {
        let expression = parse("8 ou 22 de maio", month: 5)
        guard case .eitherOr(let dates) = expression else {
            Issue.record("expected .eitherOr"); return
        }
        #expect(dates.count == 2)
        #expect(components(dates[0]) == (8, 5, 2027))
        #expect(components(dates[1]) == (22, 5, 2027))

        let event = CalendarEvent(id: "x", rawDate: "8 ou 22 de maio", dates: expression, titles: ["a"])
        #expect(!event.isExportable)
    }

    @Test("Unknown formats are kept verbatim, never dropped")
    func unparsed() throws {
        guard case .unparsed(let text) = parse("Durante todo o mês") else {
            Issue.record("expected .unparsed"); return
        }
        #expect(text == "Durante todo o mês")

        let event = CalendarEvent(id: "x", rawDate: text, dates: .unparsed(text), titles: ["a"])
        #expect(!event.isExportable)
        #expect(event.sortDate == nil)
    }

    @Test("Trailing whitespace and accents do not defeat the parser")
    func tolerance() throws {
        guard case .single(let date) = parse("22 de setembro ") else {
            Issue.record("expected .single"); return
        }
        #expect(components(date) == (22, 9, 2026))

        guard case .single(let march) = parse("3 de março", month: 3) else {
            Issue.record("expected .single for março"); return
        }
        #expect(components(march) == (3, 3, 2027))
    }

    @Test("A December to January range crosses into the next year")
    func yearWrap() throws {
        guard case .range(let start, let end) = parse("30 de dezembro a 2 de janeiro", month: 12) else {
            Issue.record("expected .range"); return
        }
        #expect(components(start) == (30, 12, 2026))
        #expect(components(end) == (2, 1, 2027))
    }

    @Test("Impossible days are not silently rounded")
    func impossibleDate() {
        guard case .unparsed = parse("31 de fevereiro", month: 2) else {
            Issue.record("expected .unparsed for 31 February"); return
        }
    }

    @Test("Every format in the live fixture parses or is flagged")
    func fixtureCoverage() throws {
        let (year, _) = CalendarParser.parse(html: try Fixture.html("calendario"))
        let all = year.months.flatMap(\.events)

        var counts: [String: Int] = [:]
        for event in all {
            switch event.dates {
            case .single: counts["single", default: 0] += 1
            case .range: counts["range", default: 0] += 1
            case .discrete: counts["discrete", default: 0] += 1
            case .eitherOr: counts["eitherOr", default: 0] += 1
            case .unparsed: counts["unparsed", default: 0] += 1
            }
        }

        // Verified against the live page on 2026-08-25.
        #expect(counts["single"] == 80)
        #expect(counts["range"] == 18)      // 16 same-month + 2 cross-month
        #expect(counts["discrete"] == 5)
        #expect(counts["eitherOr"] == 1)
        #expect(counts["unparsed", default: 0] == 0)
    }
}
