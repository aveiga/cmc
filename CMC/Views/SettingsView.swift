import SwiftUI
import UserNotifications

/// A small settings surface: the notifications toggle and an honest note about
/// what this app is.
struct SettingsView: View {
    @Environment(NotificationService.self) private var notifications
    @State private var isEnabled = true

    var body: some View {
        List {
            Section {
                Toggle("Notificar novos destaques", isOn: $isEnabled)
                    .disabled(notifications.authorizationStatus == .denied)
                    .onChange(of: isEnabled) { _, newValue in
                        notifications.isEnabled = newValue
                        if newValue, notifications.authorizationStatus == .notDetermined {
                            Task { await notifications.requestPermission() }
                        }
                    }

                if notifications.authorizationStatus == .denied, Platform.canOpenNotificationSettings {
                    Button("Abrir as Definições do sistema") {
                        Platform.openNotificationSettings()
                    }
                }
            } header: {
                Text("Notificações")
            } footer: {
                Text(footerText)
            }

            Section {
                Link("Abrir o site do colégio", destination: SiteClient.homepageURL)
            } header: {
                Text("Sobre")
            } footer: {
                Text("Aplicação **não oficial**. Sem qualquer afiliação, patrocínio ou ligação ao Colégio Marista de Carcavelos. Todos os conteúdos pertencem ao Colégio e são lidos do seu site público.")
            }
        }
        .navigationTitle("Definições")
        .inlineNavigationTitle()
        .task {
            await notifications.refreshAuthorizationStatus()
            isEnabled = notifications.isEnabled && notifications.authorizationStatus == .authorized
        }
    }

    private var footerText: String {
        switch notifications.authorizationStatus {
        case .denied:
            return "As notificações estão desativadas nas Definições do sistema."
        default:
            // Say what the OS actually guarantees, not what we would like it to.
            return "A aplicação verifica se há novos destaques uma vez por dia, quando o iOS o permitir, e sempre que a abrir. O sistema não garante uma hora fixa."
        }
    }
}
