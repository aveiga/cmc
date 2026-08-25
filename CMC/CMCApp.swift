import SwiftUI
import UserNotifications

/// CMC — an unofficial, read-only companion app for the Colégio Marista de
/// Carcavelos website. See `PLAN.md` for the design record.
@main
struct CMCApp: App {

    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    @State private var destaques = DestaquesStore()
    @State private var calendar = CalendarStore()
    @State private var ementas = EmentasStore()
    @State private var notifications = NotificationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(destaques)
                .environment(calendar)
                .environment(ementas)
                .environment(notifications)
                .tint(.accentColor)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // The foreground diff is what actually makes notifications
            // dependable — the background task is only a latency win (PLAN §6.2).
            Task {
                await notifications.refreshAuthorizationStatus()
                await notifications.checkForNewDestaques()
            }
            BackgroundRefresh.schedule()
        }
    }
}

/// Only two jobs: register the background task before launch finishes, and
/// route a notification tap to the Destaques tab.
#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundRefresh.register()
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}
#else
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        BackgroundRefresh.register()
        UNUserNotificationCenter.current().delegate = self
    }
}
#endif

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show the banner even while the app is open — a new Destaque is worth an
    /// interruption, and the list behind it may not be refreshed yet.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // The background poll has no URL by design (PLAN §3.1), so we simply
        // land the user on the list, which does have them.
        await MainActor.run {
            NotificationCenter.default.post(name: .openDestaques, object: nil)
        }
    }
}
