import SwiftUI

/// One calendar entry: a date badge on the leading edge, the event title(s)
/// beside it.
///
/// The date is always shown **verbatim from the site** — a `.eitherOr` reads
/// "8 ou 22 de maio" and an `.unparsed` shows its raw text. We never resolve an
/// ambiguity on the user's behalf (PLAN §5.3).
struct CalendarEventRow: View {
    let event: CalendarEvent
    var addToCalendar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DateBadge(event: event)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(event.titles.enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(event.rawDate)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !event.isExportable {
                    Label(unexportableReason, systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .swipeActions(edge: .trailing) {
            if event.isExportable {
                Button(action: addToCalendar) {
                    Label("Adicionar", systemImage: "calendar.badge.plus")
                }
                .tint(.accentColor)
            }
        }
        .contextMenu {
            Button(action: addToCalendar) {
                Label("Adicionar ao Calendário", systemImage: "calendar.badge.plus")
            }
            .disabled(!event.isExportable)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.rawDate). \(event.titles.joined(separator: ". "))")
        .accessibilityActions {
            if event.isExportable {
                Button("Adicionar ao Calendário", action: addToCalendar)
            }
        }
    }

    private var unexportableReason: String {
        switch event.dates {
        case .eitherOr: return "Data ambígua — não pode ser adicionada automaticamente."
        case .unparsed: return "Data em formato não reconhecido."
        default: return ""
        }
    }
}

/// The leading date badge. Compact for a single day, a small range otherwise,
/// and a question mark when the site's text did not parse.
private struct DateBadge: View {
    let event: CalendarEvent

    var body: some View {
        VStack(spacing: 1) {
            switch event.dates {
            case .single(let date):
                day(date)
                month(date)
            case .range(let start, let end):
                Text("\(dayNumber(start))–\(dayNumber(end))")
                    .font(.headline)
                    .monospacedDigit()
                month(start)
            case .discrete(let dates), .eitherOr(let dates):
                Text(dates.map(dayNumber).joined(separator: separator))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let first = dates.first { month(first) }
            case .unparsed:
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 54)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private var separator: String {
        if case .eitherOr = event.dates { return "/" }
        return "·"
    }

    private func day(_ date: Date) -> some View {
        Text(dayNumber(date))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
    }

    private func month(_ date: Date) -> some View {
        Text(date.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "pt_PT"))))
            .font(.caption2)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private func dayNumber(_ date: Date) -> String {
        String(DateExpressionParser.calendar.component(.day, from: date))
    }
}
