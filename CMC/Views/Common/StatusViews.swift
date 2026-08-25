import SwiftUI

/// "Última atualização: há 3 minutos" — shown on every screen, because a broken
/// site degrades to stale data and the user is entitled to know (PLAN §3.4).
struct LastUpdatedFooter: View {
    let date: Date?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            if let date {
                Text("Última atualização: \(date.formatted(.relative(presentation: .named)))")
            } else if error == nil {
                Text("Ainda não atualizado.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Shown when a screen has nothing cached *and* the refresh failed.
struct LoadFailedView: View {
    let message: String
    let siteURL: URL
    var retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Não foi possível carregar", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Tentar novamente") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
            Link("Abrir a página no Safari", destination: siteURL)
        }
    }
}

/// A footnote that appears only when the parser had something to complain about.
/// This is the "the site changed" early-warning a contributor sees first.
struct ParseWarningsFooter: View {
    let warnings: [ParseWarning]

    var body: some View {
        if !warnings.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(warnings) { warning in
                        Text("\(warning.context): \(warning.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } label: {
                Label(
                    "\(warnings.count) \(warnings.count == 1 ? "aviso de leitura" : "avisos de leitura")",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
