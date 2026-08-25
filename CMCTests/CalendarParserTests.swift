import Testing
import Foundation
@testable import CMC

/// Asserts the invariants of PLAN §2.5 against the checked-in calendar page.
@Suite("Calendar parser")
struct CalendarParserTests {

    private func parsed() throws -> (CalendarYear, [ParseWarning]) {
        CalendarParser.parse(html: try Fixture.html("calendario"))
    }

    @Test("Twelve months, Setembro through Agosto")
    func twelveMonths() throws {
        let (year, _) = try parsed()
        #expect(year.months.count == 12)
        #expect(year.months.first?.name == "Setembro")
        #expect(year.months.last?.name == "Agosto")
        #expect(year.months.map(\.monthNumber) == [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8])
    }

    /// The page renders its accordion twice. If the dedupe ever regresses this
    /// count doubles, which is exactly what this test exists to catch.
    @Test("Exactly 104 events — the accordion is not read twice")
    func eventCountProvesDedupe() throws {
        let (year, _) = try parsed()
        #expect(year.months.reduce(0) { $0 + $1.events.count } == 104)

        // And no month appears twice.
        let names = year.months.map(\.monthNumber)
        #expect(Set(names).count == names.count)
    }

    @Test("Academic year read off the Semestres letivos table")
    func academicYear() throws {
        let (year, _) = try parsed()
        #expect(year.startYear == 2026)
        #expect(year.endYear == 2027)
        // Setembro–Dezembro get the first year, Janeiro–Agosto the second.
        #expect(year.months.first { $0.monthNumber == 9 }?.year == 2026)
        #expect(year.months.first { $0.monthNumber == 1 }?.year == 2027)
    }

    @Test("Both tables are found, and cookie tables are not mistaken for them")
    func tables() throws {
        let (year, _) = try parsed()
        #expect(year.semesters.count == 2)
        #expect(year.semesters.first?.label == "1º")
        #expect(year.semesters.first?.startText.contains("10 de setembro 2026") == true)
        #expect(year.breaks.count >= 5)
        #expect(year.breaks.contains { $0.label == "Natal" })
        // The page also contains cookie-consent tables; none must leak in.
        #expect(!year.breaks.contains { $0.label.lowercased().contains("cookie") })
    }

    /// At least one entry bolds the *event* instead of the date. Parsing by
    /// line position rather than by `<strong>` is what makes this pass.
    @Test("Date is taken from line position, not from <strong>")
    func invertedBoldingIsHandled() throws {
        let (year, _) = try parsed()
        let setembro = try #require(year.months.first { $0.monthNumber == 9 })
        let entry = try #require(setembro.events.first {
            $0.titles.contains { $0.contains("Receção aos novos alunos") }
        })
        #expect(entry.rawDate == "10 de setembro")
        if case .single = entry.dates {} else {
            Issue.record("expected a single date, got \(entry.dates)")
        }
    }

    @Test("No event is dropped and no title is empty")
    func nothingIsSilentlyDropped() throws {
        let (year, _) = try parsed()
        for month in year.months {
            for event in month.events {
                #expect(!event.rawDate.isEmpty, "\(month.name)")
                #expect(!event.titles.isEmpty, "\(month.name) — \(event.rawDate)")
                #expect(!event.titles.contains { $0.isEmpty })
            }
        }
    }

    @Test("En dashes are unescaped, not left as entities")
    func htmlEntitiesAreDecoded() throws {
        let (year, _) = try parsed()
        let titles = year.months.flatMap { $0.events.flatMap(\.titles) }
        #expect(!titles.contains { $0.contains("&#") })
        #expect(!titles.contains { $0.contains("&amp;") })
        #expect(titles.contains { $0.contains("–") }, "expected at least one en dash")
    }

    @Test("Trailing whitespace inside the date element is trimmed")
    func datesAreTrimmed() throws {
        let (year, _) = try parsed()
        for month in year.months {
            for event in month.events {
                #expect(event.rawDate == event.rawDate.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    @Test("Degrades to an empty year with warnings rather than crashing")
    func degradesGracefully() {
        let (year, warnings) = CalendarParser.parse(html: "<html><body>nada</body></html>")
        #expect(year.months.isEmpty)
        #expect(!warnings.isEmpty)
    }
}
