import Foundation
import SwiftSoup

/// Turns the homepage HTML into `Destaque`s.
///
/// Pure function, no I/O. Never throws on partial failure: an item we cannot
/// read is reported as a warning and skipped, the rest still make it through.
nonisolated enum DestaquesParser {

    static func parse(html: String) -> ([Destaque], [ParseWarning]) {
        var warnings: [ParseWarning] = []
        let context = "Destaques"

        guard let document = try? SwiftSoup.parse(html) else {
            return ([], [ParseWarning(context, "O HTML da página inicial não pôde ser lido.")])
        }

        guard let widget = try? document.select(Selectors.destaquesWidget).first() else {
            return ([], [ParseWarning(
                context,
                "Secção «Destaques» não encontrada (Selectors.destaquesWidget)."
            )])
        }

        guard let items = try? widget.select(Selectors.destaqueItem), !items.isEmpty() else {
            return ([], [ParseWarning(
                context,
                "Nenhum destaque na secção (Selectors.destaqueItem)."
            )])
        }

        var destaques: [Destaque] = []
        var seen = Set<String>()

        for (index, item) in items.array().enumerated() {
            let position = index + 1

            let title = (try? item.select(Selectors.destaqueTitle).first()?.text())?
                .flatMap { $0.cleaned() } ?? ""

            guard let anchor = try? item.select(Selectors.destaqueLink).first(),
                  let href = try? anchor.attr("href"),
                  let url = URL(string: href.cleaned()),
                  url.scheme?.hasPrefix("http") == true
            else {
                warnings.append(ParseWarning(
                    context,
                    "Destaque \(position) («\(title.isEmpty ? "sem título" : title)») sem link utilizável."
                ))
                continue
            }

            guard !title.isEmpty else {
                warnings.append(ParseWarning(context, "Destaque \(position) sem título; ignorado."))
                continue
            }

            // The same target appearing twice would give us duplicate ids.
            guard seen.insert(url.absoluteString).inserted else { continue }

            let cta = (try? anchor.text())?.cleaned()

            destaques.append(Destaque(
                postID: nil,
                title: title,
                ctaLabel: (cta?.isEmpty ?? true) ? nil : cta,
                url: url,
                publishedAt: nil
            ))
        }

        if destaques.isEmpty {
            warnings.append(ParseWarning(context, "A secção existe mas nenhum destaque foi lido."))
        }

        return (destaques, warnings)
    }

    /// Fills in `postID` and `publishedAt` from the REST API by matching titles.
    ///
    /// The API cannot give us URLs (PLAN §2.2), so this is strictly a
    /// nice-to-have: if the join fails we keep the scraped list untouched.
    /// Homepage order matches API order, so position is used as a tiebreaker
    /// when two posts share a title.
    static func merging(_ destaques: [Destaque], with posts: [SiteClient.Post]) -> [Destaque] {
        guard !posts.isEmpty else { return destaques }

        var remaining = posts
        return destaques.map { destaque in
            let key = destaque.title.normalizedForMatching()
            guard let index = remaining.firstIndex(where: {
                $0.titleText.normalizedForMatching() == key
            }) else { return destaque }

            let post = remaining.remove(at: index)
            var merged = destaque
            merged.postID = post.id
            merged.publishedAt = post.publishedAt
            return merged
        }
    }
}

nonisolated extension String {
    /// Case- and accent-insensitive key, so "Avaliação Externa" from the API
    /// still matches "Avaliacao Externa" if the site ever changes its encoding.
    func normalizedForMatching() -> String {
        cleaned()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_PT"))
    }
}
