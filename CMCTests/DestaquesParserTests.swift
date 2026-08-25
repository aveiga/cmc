import Testing
import Foundation
@testable import CMC

/// Asserts the invariants of PLAN §2.4 against the checked-in homepage.
@Suite("Destaques parser")
struct DestaquesParserTests {

    private func parsed() throws -> ([Destaque], [ParseWarning]) {
        DestaquesParser.parse(html: try Fixture.html("homepage"))
    }

    @Test("Reads every destaque from the homepage")
    func readsAllItems() throws {
        let (destaques, warnings) = try parsed()
        // The site served 9 items when PLAN was written and 10 on 2026-08-25;
        // the widget cap is not fixed, so assert a healthy range, not a number.
        #expect(destaques.count >= 9)
        #expect(warnings.isEmpty)
    }

    /// The single most important invariant in the project: the destination URL
    /// exists *only* in this HTML (PLAN §2.2). A destaque without one is useless.
    @Test("Every destaque has a usable URL")
    func everyItemHasAURL() throws {
        let (destaques, _) = try parsed()
        for destaque in destaques {
            #expect(destaque.url.scheme?.hasPrefix("http") == true, "\(destaque.title)")
            #expect(!destaque.title.isEmpty)
        }
    }

    @Test("Titles and CTA labels match the live page")
    func readsTitlesAndLabels() throws {
        let (destaques, _) = try parsed()
        let first = try #require(destaques.first)
        #expect(first.title == "Circular")
        #expect(first.ctaLabel == "Agosto 2026")
        #expect(first.url.lastPathComponent == "Circular-de-agosto-2026-1.pdf")
    }

    @Test("Classifies PDF, internal and external targets")
    func classifiesKinds() throws {
        let (destaques, _) = try parsed()
        let kinds = Dictionary(grouping: destaques, by: \.kind)
        #expect(kinds[.pdf]?.isEmpty == false, "expected at least one PDF")
        #expect(kinds[.webPage]?.isEmpty == false, "expected at least one internal page")
        // "Banco de Resumos" lives on bancoderesumos.marista-carcavelos.org.
        #expect(destaques.contains { $0.kind == .externalWebPage })
    }

    @Test("Ignores the destacados_home carousel")
    func ignoresCarousel() throws {
        let (destaques, _) = try parsed()
        // Carousel tiles link to bomdiamaristas.pt / genially — none must appear.
        #expect(!destaques.contains { $0.url.host()?.contains("bomdiamaristas") == true })
        #expect(!destaques.contains { $0.url.host()?.contains("genial") == true })
    }

    @Test("Returns a warning instead of crashing on unusable HTML")
    func degradesGracefully() {
        let (destaques, warnings) = DestaquesParser.parse(html: "<html><body>nada</body></html>")
        #expect(destaques.isEmpty)
        #expect(!warnings.isEmpty)
    }

    @Test("Joins API dates onto scraped items by title")
    func mergesAPIMetadata() throws {
        let (destaques, _) = try parsed()
        let posts = try JSONDecoder().decode(
            [SiteClient.Post].self,
            from: try Fixture.data("ultima_hora", extension: "json")
        )
        let merged = DestaquesParser.merging(destaques, with: posts)

        #expect(merged.count == destaques.count)
        #expect(merged.first?.postID == 224727)
        #expect(merged.first?.publishedAt != nil)
        // Links must survive the join untouched.
        #expect(merged.map(\.url) == destaques.map(\.url))
    }

    @Test("Keeps the scraped list when the API join finds nothing")
    func mergeIsOptional() throws {
        let (destaques, _) = try parsed()
        #expect(DestaquesParser.merging(destaques, with: []) == destaques)
    }
}
