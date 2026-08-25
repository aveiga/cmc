import Foundation
import SwiftSoup

/// Turns the ementas page into tracks of monthly PDFs.
///
/// The track always comes from the `h4` a link sits under — never from the
/// filename, which is inconsistently cased and sometimes misspelled
/// (`Ementa-geral-CARACAVELOS-JUNHO-2026.pdf`, PLAN §2.6). URLs are used
/// verbatim; none is ever synthesised from a pattern.
nonisolated enum EmentasParser {

    static func parse(html: String) -> ([EmentaTrack], [ParseWarning]) {
        var warnings: [ParseWarning] = []
        let context = "Ementas"

        guard let document = try? SwiftSoup.parse(html),
              let body = document.body() else {
            return ([], [ParseWarning(context, "O HTML da página de ementas não pôde ser lido.")])
        }

        // Walk the document in order, remembering the last heading seen. The
        // page footer has more `h4`s but no PDF links, so they simply never
        // collect anything — no class names needed, which is one less thing
        // Elementor can break.
        var currentTrack: String?
        var order: [String] = []
        var grouped: [String: [Ementa]] = [:]
        var seen = Set<String>()

        let elements = (try? body.getAllElements().array()) ?? []
        for element in elements {
            switch element.tagName().lowercased() {
            case Selectors.ementaTrackHeading:
                let text = (try? element.text())?.cleaned() ?? ""
                currentTrack = text.isEmpty ? nil : text

            case "a":
                guard let href = try? element.attr("href") else { continue }
                guard let url = URL(string: href.cleaned()),
                      url.pathExtension.lowercased() == "pdf" else { continue }
                guard seen.insert(url.absoluteString).inserted else { continue }

                guard let track = currentTrack else {
                    warnings.append(ParseWarning(
                        context,
                        "PDF «\(url.lastPathComponent)» sem cabeçalho de secção; ignorado."
                    ))
                    continue
                }

                let label = ((try? element.text())?.cleaned()).flatMap { $0.isEmpty ? nil : $0 }
                    ?? url.deletingPathExtension().lastPathComponent

                let (month, year) = monthAndYear(filename: url.lastPathComponent,
                                                 linkText: label,
                                                 uploadPath: url.path)
                if month == nil {
                    warnings.append(ParseWarning(
                        context,
                        "Não foi possível determinar o mês de «\(url.lastPathComponent)»."
                    ))
                }

                if order.last != track && !order.contains(track) { order.append(track) }
                grouped[track, default: []].append(Ementa(
                    track: track,
                    monthLabel: label,
                    month: month,
                    year: year,
                    url: url
                ))

            default:
                continue
            }
        }

        let tracks = order.compactMap { name -> EmentaTrack? in
            guard let items = grouped[name], !items.isEmpty else { return nil }
            // Newest first; the current month, if present, therefore sorts to the top.
            return EmentaTrack(name: name, ementas: items.sorted { $0.sortKey > $1.sortKey })
        }

        if tracks.isEmpty {
            warnings.append(ParseWarning(context, "Nenhuma ementa encontrada na página."))
        }

        return (tracks, warnings)
    }

    // MARK: - Dating a menu

    /// Works out which month a menu is for.
    ///
    /// The filename's month and the upload path's month **disagree**
    /// (`…JUNHO-2026.pdf` lives under `/2026/05/`), so we trust the filename
    /// when it parses and fall back to the link text plus the upload year.
    static func monthAndYear(
        filename: String,
        linkText: String,
        uploadPath: String
    ) -> (month: Int?, year: Int?) {
        let haystack = filename.normalizedForMatching()
        let filenameMonth = Selectors.monthNames.firstIndex {
            haystack.contains($0.normalizedForMatching())
        }.map { $0 + 1 }

        let filenameYear = firstYear(in: filename)

        // `/wp-content/uploads/2026/05/…` — the month the file was uploaded,
        // which is usually the month *before* the menu it contains.
        let pathParts = uploadPath.split(separator: "/").map(String.init)
        let uploadYear = pathParts.compactMap { Int($0) }.first { (2000...2100).contains($0) }

        let linkMonth = Selectors.monthNames.firstIndex {
            linkText.normalizedForMatching() == $0.normalizedForMatching()
        }.map { $0 + 1 }

        let month = filenameMonth ?? linkMonth
        var year = filenameYear ?? uploadYear

        // A menu uploaded in December for January belongs to the next year.
        if filenameYear == nil, let month, let uploadMonth = uploadMonth(in: pathParts),
           uploadMonth == 12, month == 1 {
            year = (uploadYear ?? 0) + 1
        }

        return (month, year)
    }

    private static func uploadMonth(in pathParts: [String]) -> Int? {
        guard let yearIndex = pathParts.firstIndex(where: {
            guard let value = Int($0) else { return false }
            return (2000...2100).contains(value)
        }), pathParts.indices.contains(yearIndex + 1) else { return nil }
        return Int(pathParts[yearIndex + 1])
    }

    private static func firstYear(in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: Selectors.yearPattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matched = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[matched])
    }
}
