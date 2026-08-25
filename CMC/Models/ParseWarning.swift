import Foundation

/// A non-fatal problem noticed while parsing the site.
///
/// Parsers never throw on partial failure (PLAN §3.4): they return everything
/// they understood plus a list of these, so one broken entry can never blank a
/// screen. Warnings are surfaced in the debug-facing "Diagnóstico" surface and
/// are what a contributor reads first when the site has changed.
nonisolated struct ParseWarning: Codable, Hashable, Identifiable {
    /// Where the problem was noticed, e.g. `"Calendário/Maio"`.
    let context: String
    /// What went wrong, in plain language.
    let message: String

    var id: String { "\(context)|\(message)" }

    init(_ context: String, _ message: String) {
        self.context = context
        self.message = message
    }
}
