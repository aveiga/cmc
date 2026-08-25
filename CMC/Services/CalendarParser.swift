import Foundation
import SwiftSoup

/// Turns `/calendario-geral/` into a `CalendarYear`.
///
/// Two hazards drive the shape of this file (PLAN §2.5):
/// 1. the page renders its accordion **twice** (a `<details>` version and a
///    legacy Elementor one), so months are deduped by name;
/// 2. the date is the **first `<br>`-separated line**, not the bold one — at
///    least one entry inverts the bolding.
nonisolated enum CalendarParser {

    static func parse(html: String, now: Date = Date()) -> (CalendarYear, [ParseWarning]) {
        var warnings: [ParseWarning] = []
        let context = "Calendário"

        guard let document = try? SwiftSoup.parse(html) else {
            return (.empty, [ParseWarning(context, "O HTML do calendário não pôde ser lido.")])
        }

        let tables = (try? document.select(Selectors.table).array()) ?? []
        let semesters = rows(of: tables.first { marker($0, matches: [Selectors.semestersTableMarker]) })
        let breaks = rows(of: tables.first { marker($0, matches: Selectors.breaksTableMarkers) })

        if semesters.isEmpty {
            warnings.append(ParseWarning(context, "Tabela «Semestres letivos» não encontrada."))
        }
        if breaks.isEmpty {
            warnings.append(ParseWarning(context, "Tabela «Pausas letivas» não encontrada."))
        }

        let academicYear = academicYear(from: semesters, now: now)

        let (months, monthWarnings) = parseMonths(document, academicYear: academicYear)
        warnings.append(contentsOf: monthWarnings)

        if months.count != 12 {
            warnings.append(ParseWarning(
                context,
                "Esperados 12 meses no acordeão, encontrados \(months.count)."
            ))
        }

        let year = CalendarYear(
            startYear: academicYear.start,
            endYear: academicYear.end,
            semesters: semesters,
            breaks: breaks,
            months: months
        )
        return (year, warnings)
    }

    // MARK: - Accordion

    private static func parseMonths(
        _ document: Document,
        academicYear: (start: Int, end: Int)
    ) -> ([MonthSection], [ParseWarning]) {
        var warnings: [ParseWarning] = []

        // Prefer the modern `<details>` accordion; fall back to the legacy one
        // only if it has vanished. Never read both — that doubles every event.
        var sources: [(title: Element?, body: Element)] = []
        if let details = try? document.select(Selectors.calendarAccordionItem).array(), !details.isEmpty {
            sources = details.map { (try? $0.select(Selectors.calendarAccordionTitle).first(), $0) }
        } else if let legacy = try? document.select(Selectors.calendarLegacyAccordionItem).array(),
                  !legacy.isEmpty {
            warnings.append(ParseWarning(
                "Calendário",
                "Acordeão moderno ausente; a usar o formato antigo (Selectors.calendarAccordionItem)."
            ))
            sources = legacy.compactMap { item in
                guard let body = try? item.select(Selectors.calendarLegacyAccordionBody).first()
                else { return nil }
                return (try? item.select(Selectors.calendarLegacyAccordionTitle).first(), body)
            }
        } else {
            warnings.append(ParseWarning("Calendário", "Acordeão de meses não encontrado."))
            return ([], warnings)
        }

        var months: [MonthSection] = []
        var seenMonths = Set<Int>()

        for (titleElement, body) in sources {
            let name = ((try? titleElement?.text())?.flatMap { $0.cleaned() }) ?? ""
            guard let monthNumber = DateExpressionParser.month(named: name) else {
                if !name.isEmpty {
                    warnings.append(ParseWarning("Calendário", "Mês «\(name)» não reconhecido."))
                }
                continue
            }
            // Belt and braces against the double-render hazard.
            guard seenMonths.insert(monthNumber).inserted else { continue }

            let year = monthNumber >= 9 ? academicYear.start : academicYear.end
            let (events, eventWarnings) = parseEvents(
                in: body, monthName: name, monthNumber: monthNumber,
                year: year, academicYear: academicYear
            )
            warnings.append(contentsOf: eventWarnings)

            months.append(MonthSection(
                name: name, monthNumber: monthNumber, year: year, events: events
            ))
        }

        return (months, warnings)
    }

    private static func parseEvents(
        in body: Element,
        monthName: String,
        monthNumber: Int,
        year: Int,
        academicYear: (start: Int, end: Int)
    ) -> ([CalendarEvent], [ParseWarning]) {
        var warnings: [ParseWarning] = []
        var events: [CalendarEvent] = []

        let paragraphs = (try? body.select(Selectors.calendarEntry).array()) ?? []
        for (index, paragraph) in paragraphs.enumerated() {
            let lines = linesSplitByBreaks(in: paragraph)
            guard let rawDate = lines.first else { continue }   // empty <p>: skip silently
            let titles = Array(lines.dropFirst())

            guard !titles.isEmpty else {
                warnings.append(ParseWarning(
                    "Calendário/\(monthName)",
                    "Entrada «\(rawDate)» sem descrição; ignorada."
                ))
                continue
            }

            let expression = DateExpressionParser.parse(
                rawDate, sectionMonth: monthNumber, academicYear: academicYear
            )
            if case .unparsed = expression {
                warnings.append(ParseWarning(
                    "Calendário/\(monthName)",
                    "Data «\(rawDate)» em formato desconhecido; mostrada tal como está."
                ))
            }

            events.append(CalendarEvent(
                id: "\(year)-\(monthNumber)-\(index)",
                rawDate: rawDate,
                dates: expression,
                titles: titles
            ))
        }

        return (events, warnings)
    }

    /// Splits an element's contents on `<br>`, which is how the page separates
    /// the date line from its event lines. Returns non-empty, cleaned lines.
    static func linesSplitByBreaks(in element: Element) -> [String] {
        var lines: [String] = []
        var current = ""

        func flush() {
            let line = current.decodingHTMLEntities().cleaned()
            if !line.isEmpty { lines.append(line) }
            current = ""
        }

        for node in element.getChildNodes() {
            if let text = node as? TextNode {
                current += text.getWholeText()
            } else if let child = node as? Element {
                if child.tagName().lowercased() == "br" {
                    flush()
                } else {
                    // Nested <strong>/<span>: keep their text, and honour any
                    // <br> inside them too.
                    let nested = linesSplitByBreaks(in: child)
                    if nested.count > 1 {
                        current += nested[0]
                        flush()
                        lines.append(contentsOf: nested.dropFirst())
                    } else {
                        current += nested.first ?? ""
                    }
                }
            }
        }
        flush()
        return lines
    }
}
