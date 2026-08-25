import SwiftUI

/// The canteen menus, one section per track.
///
/// The track names come from the page's `h4`s and are never hardcoded, so a
/// third track appearing needs no code change (PLAN §4.2).
struct EmentasView: View {
    @Environment(EmentasStore.self) private var store
    @State private var opener = DestaqueOpener()

    var body: some View {
        NavigationStack {
            Group {
                if store.tracks.isEmpty, let error = store.lastError {
                    LoadFailedView(message: error, siteURL: SiteClient.ementasURL) {
                        await store.refresh()
                    }
                } else if store.tracks.isEmpty && !store.hasLoadedOnce {
                    ProgressView("A carregar…")
                } else if store.tracks.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Ementas")
            .refreshable { await store.refresh() }
            .destaqueSheets(opener)
        }
        .task { await store.refresh() }
    }

    /// The school leaves this page stale for months, so this is a normal state,
    /// not an error — and it still leaves the user a way forward (PLAN §5.4).
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sem ementas publicadas", systemImage: "fork.knife")
        } description: {
            Text("O colégio ainda não publicou ementas nesta página.")
        } actions: {
            Link("Abrir a página no Safari", destination: SiteClient.ementasURL)
        }
    }

    private var list: some View {
        List {
            ForEach(store.tracks) { track in
                Section(track.name) {
                    ForEach(track.ementas) { ementa in
                        EmentaRow(ementa: ementa)
                            .contentShape(Rectangle())
                            .onTapGesture { opener.open(ementa) }
                            .contextMenu {
                                ShareLink(item: ementa.url) {
                                    Label("Partilhar", systemImage: "square.and.arrow.up")
                                }
                                Link(destination: ementa.url) {
                                    Label("Abrir no Safari", systemImage: "safari")
                                }
                            }
                    }
                }
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
}

struct EmentaRow: View {
    let ementa: Ementa

    private var isCurrent: Bool { ementa.isCurrentMonth() }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(ementa.displayTitle)
                .font(.body)
                .fontWeight(isCurrent ? .semibold : .regular)

            if isCurrent {
                Text("Este mês")
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isCurrent
            ? "\(ementa.displayTitle), ementa deste mês, PDF"
            : "\(ementa.displayTitle), PDF"
        )
        .accessibilityHint("Toque duas vezes para abrir.")
        .accessibilityAddTraits(.isButton)
    }
}
