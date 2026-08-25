import Testing
import Foundation
@testable import CMC

/// The new-item diff, tested against two snapshots of the API (PLAN §7, M7).
@Suite("Destaques diff")
struct NotificationDiffTests {

    private func post(_ id: Int, _ title: String) -> SiteClient.Post {
        SiteClient.Post(
            id: id,
            date: "2026-08-18T12:00:41",
            title: .init(rendered: title)
        )
    }

    /// A fresh install must never announce the whole backlog.
    @Test("First run seeds silently")
    func firstRunIsSilent() async {
        let service = makeService()
        let seeded = await service.process(posts: [post(1, "A"), post(2, "B")])
        #expect(seeded.isEmpty)
    }

    @Test("A later snapshot reports only what is new")
    func reportsOnlyNewItems() async {
        let service = makeService()
        _ = await service.process(posts: [post(1, "A"), post(2, "B")])

        let new = await service.process(posts: [post(3, "C"), post(1, "A"), post(2, "B")])
        #expect(new.map(\.id) == [3])
        #expect(new.first?.titleText == "C")
    }

    @Test("An unchanged snapshot reports nothing")
    func noChangeNoNotification() async {
        let service = makeService()
        _ = await service.process(posts: [post(1, "A")])
        let again = await service.process(posts: [post(1, "A")])
        #expect(again.isEmpty)
    }

    @Test("An empty or failed response changes nothing")
    func emptyResponseIsSafe() async {
        let service = makeService()
        _ = await service.process(posts: [post(1, "A")])
        #expect(await service.process(posts: []).isEmpty)
        // The seen set survives, so the next real snapshot still diffs correctly.
        #expect(await service.process(posts: [post(2, "B")]).map(\.id) == [2])
    }

    @Test("HTML entities in API titles are decoded")
    func decodesTitles() {
        #expect(post(1, "Aula &amp; Estudo").titleText == "Aula & Estudo")
        #expect(post(1, "Provas &#8211; 9º ano").titleText == "Provas – 9º ano")
    }

    @Test("WordPress dates are read as Lisbon local time")
    func parsesDates() throws {
        let date = try #require(post(1, "A").publishedAt)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        #expect(parts.year == 2026)
        #expect(parts.month == 8)
        #expect(parts.day == 18)
        #expect(parts.hour == 12)
    }

    /// Each test gets its own `UserDefaults` suite, so the suite's tests stay
    /// isolated from each other and from the user's real state.
    private func makeService(_ name: String = #function) -> NotificationService {
        let suite = "CMCTests.\(name).\(UUID().uuidString)"
        return NotificationService(defaults: UserDefaults(suiteName: suite)!)
    }
}
