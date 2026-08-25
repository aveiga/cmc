import SwiftUI

/// Top-level navigation: a tab bar, because Destaques / Calendário / Ementas
/// are three peer destinations. A hamburger drawer is an Android/web pattern
/// the HIG steers away from (PLAN §5.1).
struct RootView: View {
    enum Tab: Hashable { case destaques, calendario, ementas }

    @State private var selection: Tab = .destaques

    var body: some View {
        TabView(selection: $selection) {
            DestaquesView()
                .tabItem { Label("Destaques", systemImage: "sparkles") }
                .tag(Tab.destaques)

            CalendarView()
                .tabItem { Label("Calendário", systemImage: "calendar") }
                .tag(Tab.calendario)

            EmentasView()
                .tabItem { Label("Ementas", systemImage: "fork.knife") }
                .tag(Tab.ementas)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDestaques)) { _ in
            selection = .destaques
        }
    }
}

extension Notification.Name {
    /// Posted when the user taps a "novo destaque" notification.
    static let openDestaques = Notification.Name("openDestaques")
}
