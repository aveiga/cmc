import Foundation
#if os(iOS)
import BackgroundTasks
#endif

/// Best-effort daily check for new Destaques.
///
/// **iOS cannot guarantee a daily morning fetch for an app with no server**
/// (PLAN §6.1). `BGAppRefreshTask` only takes an *earliest* begin date; iOS
/// decides when — or whether — to run it. This is a latency optimisation, not
/// the guarantee. The foreground diff in `CMCApp` is what actually makes the
/// feature dependable.
///
/// macOS has no `BGTaskScheduler`, so there both calls are no-ops and the
/// foreground diff is the whole mechanism.
enum BackgroundRefresh {

    /// Called once, at launch, before the app finishes launching.
    static func register() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SiteClient.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handle(task)
        }
        #endif
    }

    /// Asks iOS to run us again after roughly 07:00 tomorrow.
    static func schedule() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: SiteClient.backgroundTaskIdentifier)
        request.earliestBeginDate = nextMorning()
        // Throws in the simulator and when the app is not permitted to
        // schedule; neither is worth surfacing to the user.
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    #if os(iOS)
    private static func handle(_ task: BGAppRefreshTask) {
        // Reschedule first, so a crash or timeout below cannot end the chain.
        schedule()

        let work = Task {
            await NotificationService.shared.refreshAuthorizationStatus()
            await NotificationService.shared.checkForNewDestaques()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    #endif

    /// 07:00 local tomorrow — the earliest we would like to be woken.
    static func nextMorning(after now: Date = Date(), hour: Int = 7) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(
            bySettingHour: hour, minute: 0, second: 0, of: tomorrow
        ) ?? now.addingTimeInterval(24 * 60 * 60)
    }
}
