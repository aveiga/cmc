import Foundation
import UserNotifications
import Observation

/// Local notifications for newly published Destaques.
///
/// The diff runs against the cheap `ultima_hora` REST API (PLAN §6.3), which
/// gives stable integer ids but no URLs — the notification's job is only to say
/// *"«Circular» foi publicado"* and open the app.
@Observable
final class NotificationService {

    static let shared = NotificationService()

    private enum Keys {
        static let seenIDs = "seenDestaqueIDs"
        static let enabled = "notificationsEnabled"
        static let hasAskedForPermission = "hasAskedForNotificationPermission"
    }

    private let defaults: UserDefaults

    /// The store is injectable so the diff can be unit-tested against two
    /// fixture snapshots without touching the user's real state.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The user's own switch, independent of the system permission.
    var isEnabled: Bool {
        get { defaults.object(forKey: Keys.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.enabled) }
    }

    /// True once we have shown the system prompt, so we never show it twice.
    var hasAskedForPermission: Bool {
        get { defaults.bool(forKey: Keys.hasAskedForPermission) }
        set { defaults.set(newValue, forKey: Keys.hasAskedForPermission) }
    }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var seenIDs: Set<Int> {
        get { Set(defaults.array(forKey: Keys.seenIDs) as? [Int] ?? []) }
        set { defaults.set(Array(newValue).sorted(by: >).prefix(200).map { $0 }, forKey: Keys.seenIDs) }
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requested **in context** — after the user has seen the Destaques list,
    /// never on cold launch (PLAN §6.2).
    @discardableResult
    func requestPermission() async -> Bool {
        hasAskedForPermission = true
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        if granted { isEnabled = true }
        return granted
    }

    // MARK: - The diff

    /// Compares the site's newest posts against what we have already seen and
    /// posts a notification for anything new.
    ///
    /// Runs both from the background task and on every foreground — the
    /// foreground run is what makes the feature dependable (PLAN §6.2).
    /// - Returns: the posts that were new.
    @discardableResult
    func checkForNewDestaques() async -> [SiteClient.Post] {
        guard let posts = try? await SiteClient.recentPosts() else { return [] }
        return await process(posts: posts)
    }

    /// The pure half of the diff, so it can be unit-tested against two fixture
    /// snapshots without touching the network.
    @discardableResult
    func process(posts: [SiteClient.Post]) async -> [SiteClient.Post] {
        guard !posts.isEmpty else { return [] }

        let known = seenIDs
        let newPosts = posts.filter { !known.contains($0.id) }
        seenIDs = known.union(posts.map(\.id))

        // First run seeds the seen-set silently: a fresh install must never
        // fire thirteen notifications at once (PLAN §6.2).
        guard !known.isEmpty, !newPosts.isEmpty else { return [] }
        guard isEnabled, authorizationStatus == .authorized else { return newPosts }

        await postNotification(for: newPosts)
        return newPosts
    }

    private func postNotification(for posts: [SiteClient.Post]) async {
        let content = UNMutableNotificationContent()
        content.sound = .default

        if posts.count == 1, let post = posts.first {
            content.title = "Novo destaque"
            content.body = post.titleText
            content.userInfo = ["postID": post.id]
        } else {
            // Several at once collapse into one summary rather than a burst.
            content.title = "\(posts.count) novos destaques"
            content.body = posts.prefix(3).map(\.titleText).joined(separator: " · ")
        }

        let request = UNNotificationRequest(
            identifier: "destaques-\(posts.map(\.id).sorted().map(String.init).joined(separator: "-"))",
            content: content,
            trigger: nil   // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Called on first launch so an install does not announce the backlog.
    func seedIfNeeded() async {
        guard seenIDs.isEmpty else { return }
        guard let posts = try? await SiteClient.recentPosts() else { return }
        seenIDs = Set(posts.map(\.id))
    }
}
