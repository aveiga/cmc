import Testing
import Foundation
@testable import CMC

/// Asserts the invariants of PLAN §2.6 against the checked-in ementas page.
@Suite("Ementas parser")
struct EmentasParserTests {

    private func parsed() throws -> ([EmentaTrack], [ParseWarning]) {
        EmentasParser.parse(html: try Fixture.html("ementas"))
    }

    @Test("Both tracks are present, in page order")
    func tracks() throws {
        let (tracks, warnings) = try parsed()
        #expect(tracks.map(\.name) == ["Pré-Escolar", "Geral"])
        #expect(warnings.isEmpty)
    }

    /// The filenames are inconsistently cased and one is misspelled
    /// (`CARACAVELOS`). The track must come from the `h4`, never the filename.
    @Test("Track comes from the heading, not the filename")
    func trackFromHeading() throws {
        let (tracks, _) = try parsed()
        let geral = try #require(tracks.first { $0.name == "Geral" })
        #expect(geral.ementas.contains { $0.url.lastPathComponent.contains("CARACAVELOS") })
        #expect(geral.ementas.allSatisfy { $0.track == "Geral" })
    }

    /// The filename month and the upload path month disagree:
    /// `…JUNHO-2026.pdf` lives under `/2026/05/`. The filename wins.
    @Test("Filename month beats the upload path")
    func filenameMonthWins() throws {
        let (tracks, _) = try parsed()
        let all = tracks.flatMap(\.ementas)

        let junho = try #require(all.first { $0.url.lastPathComponent.contains("JUNHO") })
        #expect(junho.url.path.contains("/2026/05/"))   // uploaded in May…
        #expect(junho.month == 6)                        // …but it is the June menu
        #expect(junho.year == 2026)
        #expect(junho.displayTitle == "Junho 2026")
    }

    @Test("Every month is dated and sorted newest first")
    func datedAndSorted() throws {
        let (tracks, _) = try parsed()
        for track in tracks {
            #expect(track.ementas.count == 2)
            #expect(track.ementas.allSatisfy { $0.month != nil && $0.year != nil })
            #expect(track.ementas.map(\.sortKey) == track.ementas.map(\.sortKey).sorted(by: >))
        }
    }

    @Test("URLs are taken verbatim and never synthesised")
    func urlsAreVerbatim() throws {
        let (tracks, _) = try parsed()
        let urls = Set(tracks.flatMap(\.ementas).map(\.url.absoluteString))
        #expect(urls.contains("https://marista-carcavelos.globaleduca.com/wp-content/uploads/2026/05/Ementa-geral-CARACAVELOS-JUNHO-2026.pdf"))
        #expect(urls.count == 4)
    }

    @Test("The footer's h4 headings do not become tracks")
    func footerHeadingsIgnored() throws {
        let (tracks, _) = try parsed()
        #expect(!tracks.contains { $0.name.uppercased() == "SOMOS" })
        #expect(!tracks.contains { $0.name.uppercased().contains("RESERVADA") })
    }

    @Test("An empty page is an empty result, not a crash and not a guess")
    func emptyPage() {
        let (tracks, warnings) = EmentasParser.parse(html: "<html><body><h2>Ementas</h2></body></html>")
        #expect(tracks.isEmpty)
        #expect(!warnings.isEmpty)
    }

    @Test("A December upload for a January menu lands in the next year")
    func yearRollover() {
        let (month, year) = EmentasParser.monthAndYear(
            filename: "Ementa-geral-Carcavelos-JANEIRO.pdf",
            linkText: "janeiro",
            uploadPath: "/wp-content/uploads/2026/12/Ementa-geral-Carcavelos-JANEIRO.pdf"
        )
        #expect(month == 1)
        #expect(year == 2027)
    }
}
