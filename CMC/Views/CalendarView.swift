import SwiftUI

/// The school-year calendar. The most valuable native win, since the source is
/// a 12-month accordion of plain text (PLAN §5.3).
struct CalendarView: View {
    @Environment(CalendarStore.self) private var store

    enum Mode: String, CaseIterable, Identifiable {
        case upcoming = "Próximos"
        case year = "Ano letivo"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .upcoming
    @State private var search = ""
    @State private var eventToAdd: CalendarEvent?
    @State private var exportResult: ICSExport.Result?

    var body: some View {
        NavigationStack {
            Group {
                if !store.hasContent, let error = store.lastError {
                    LoadFailedView(message: error, siteURL: SiteClient.calendarURL) {
                        await store.refresh()
                    }
                } else if !store.hasContent && store.isLoading {
                    ProgressView("A carregar…")
                } else {
                    content
                }
            }
            .navigationTitle("Calendário")
            .toolbar { toolbar }
            .refreshable { await store.refresh() }
            .searchable(text: $search, prompt: "Procurar evento")
        }
        .task { await store.refresh() }
        .sheet(item: $eventToAdd) { event in
            EventEditSheet(event: event)
        }
        .sheet(item: $exportResult) { result in
            ICSExportSheet(result: result)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                exportResult = try? ICSExport.write(store.year)
            } label: {
                Label("Exportar ano", systemImage: "square.and.arrow.up")
            }
            .disabled(!store.hasContent)
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("Vista", selection: $mode) {
                    ForEach(Mode.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if search.isEmpty && mode == .upcoming {
                CalendarSummarySection(store: store)
            }

            switch mode {
            case .upcoming: upcomingSections
            case .year: yearSections
            }

            Section {
                EmptyView()
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    LastUpdatedFooter(date: store.lastUpdated, error: store.lastError)
                    ParseWarningsFooter(warnings: store.warnings)
                }
            }
        }
        .groupedListStyle()
    }

    // MARK: - Próximos

    @ViewBuilder
    private var upcomingSections: some View {
        let events = filtered(search.isEmpty ? store.upcomingEvents() : store.allEvents)
        let grouped = Dictionary(grouping: events, by: \.monthTitle)
        let order = events.map(\.monthTitle).reduced()

        if events.isEmpty {
            Section {
                ContentUnavailableView(
                    search.isEmpty ? "Nada em agenda" : "Sem resultados",
                    systemImage: search.isEmpty ? "calendar" : "magnifyingglass",
                    description: Text(
                        search.isEmpty
                        ? "Não há mais eventos no calendário deste ano letivo."
                        : "Nenhum evento corresponde a «\(search)»."
                    )
                )
            }
        } else {
            ForEach(order, id: \.self) { title in
                Section(title) {
                    ForEach(grouped[title] ?? []) { dated in
                        CalendarEventRow(event: dated.event) { eventToAdd = dated.event }
                    }
                }
            }
        }
    }

    // MARK: - Ano letivo

    @ViewBuilder
    private var yearSections: some View {
        ForEach(store.year.months) { month in
            let events = month.events.filter { matches($0) }
            if !events.isEmpty {
                Section {
                    ForEach(events) { event in
                        CalendarEventRow(event: event) { eventToAdd = event }
                    }
                } header: {
                    Text("\(month.name) \(String(month.year))")
                }
            }
        }
    }

    // MARK: - Search

    private func filtered(_ events: [DatedEvent]) -> [DatedEvent] {
        guard !search.isEmpty else { return events }
        return events.filter { matches($0.event) }
    }

    private func matches(_ event: CalendarEvent) -> Bool {
        guard !search.isEmpty else { return true }
        let key = search.normalizedForMatching()
        return event.titles.contains { $0.normalizedForMatching().contains(key) }
            || event.rawDate.normalizedForMatching().contains(key)
    }
}

extension Array where Element: Hashable {
    /// Distinct values, first-seen order preserved.
    func reduced() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension ICSExport.Result: Identifiable {
    public var id: String { fileURL.absoluteString }
}
