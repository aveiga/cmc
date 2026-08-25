import SwiftUI
import UserNotifications

/// The home screen: the site's "Destaques" list, rendered natively.
struct DestaquesView: View {
    @Environment(DestaquesStore.self) private var store
    @Environment(NotificationService.self) private var notifications

    @State private var opener = DestaqueOpener()
    @State private var showNotificationPrompt = false

    var body: some View {
        NavigationStack {
            Group {
                if store.destaques.isEmpty, let error = store.lastError {
                    LoadFailedView(message: error, siteURL: SiteClient.homepageURL) {
                        await store.refresh()
                    }
                } else if store.destaques.isEmpty && store.isLoading {
                    ProgressView("A carregar…")
                } else {
                    list
                }
            }
            .navigationTitle("Destaques")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Definições", systemImage: "gearshape")
                    }
                }
            }
            .refreshable { await store.refresh() }
            .destaqueSheets(opener)
        }
        .task {
            await store.refresh()
            await maybeAskAboutNotifications()
        }
        .alert("Avisamos quando houver novidades?", isPresented: $showNotificationPrompt) {
            Button("Agora não", role: .cancel) {}
            Button("Ativar") { Task { await notifications.requestPermission() } }
        } message: {
            Text("Enviamos uma notificação sempre que o colégio publicar um novo destaque. Uma verificação por dia, nada mais.")
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(store.destaques) { destaque in
                    DestaqueRow(destaque: destaque)
                        .contentShape(Rectangle())
                        .onTapGesture { opener.open(destaque) }
                        .contextMenu {
                            Button {
                                Platform.copyToClipboard(destaque.url)
                            } label: {
                                Label("Copiar link", systemImage: "link")
                            }
                            ShareLink(item: destaque.url) {
                                Label("Partilhar", systemImage: "square.and.arrow.up")
                            }
                            Link(destination: destaque.url) {
                                Label("Abrir no Safari", systemImage: "safari")
                            }
                        }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    LastUpdatedFooter(date: store.lastUpdated, error: store.lastError)
                    ParseWarningsFooter(warnings: store.warnings)
                }
                .padding(.top, 4)
            }
        }
        .groupedListStyle()
    }

    /// In context — only after the list is on screen and only once (PLAN §6.2).
    private func maybeAskAboutNotifications() async {
        await notifications.refreshAuthorizationStatus()
        await notifications.seedIfNeeded()
        guard !store.destaques.isEmpty,
              !notifications.hasAskedForPermission,
              notifications.authorizationStatus == .notDetermined else { return }
        try? await Task.sleep(for: .seconds(1.5))
        showNotificationPrompt = true
    }
}

struct DestaqueRow: View {
    let destaque: Destaque

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: destaque.symbolName)
                .foregroundStyle(.tint)
                .font(.body)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(destaque.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let cta = destaque.ctaLabel {
                    Text(cta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let date = destaque.publishedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Toque duas vezes para abrir.")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [destaque.title]
        if let cta = destaque.ctaLabel { parts.append(cta) }
        parts.append(destaque.accessibilityKindDescription)
        return parts.joined(separator: ", ")
    }
}
