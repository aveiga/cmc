import SwiftUI

/// The two tables at the top of the site's page, promoted to a summary a parent
/// can actually read: semester start/end and the next break (PLAN §5.3).
struct CalendarSummarySection: View {
    let store: CalendarStore

    var body: some View {
        if !store.year.semesters.isEmpty || !store.year.breaks.isEmpty {
            Section("Ano letivo \(store.year.label)") {
                ForEach(store.year.semesters) { row in
                    SummaryRow(
                        title: "\(row.label) Semestre",
                        start: row.startText,
                        end: row.endText
                    )
                }

                if let next = store.nextBreak() {
                    SummaryRow(
                        title: "Próxima pausa: \(next.label)",
                        start: next.startText,
                        end: next.endText
                    )
                }

                NavigationLink("Todas as pausas letivas") {
                    BreaksListView(breaks: store.year.breaks)
                }
            }
        }
    }
}

private struct SummaryRow: View {
    let title: String
    let start: String
    let end: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .top, spacing: 16) {
                labelled("Início", start)
                labelled("Fim", end)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func labelled(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BreaksListView: View {
    let breaks: [CalendarTableRow]

    var body: some View {
        List(breaks) { row in
            SummaryRow(title: row.label, start: row.startText, end: row.endText)
        }
        .groupedListStyle()
        .navigationTitle("Pausas letivas")
        .inlineNavigationTitle()
    }
}
