import SwiftUI

/// The handful of places iOS and macOS genuinely differ.
///
/// This app is designed for iOS and follows the iOS HIG (PLAN §5). The macOS
/// build exists so the project can be built, run and tested without an iOS
/// simulator installed. Keeping every `#if os(...)` here and in the three sheet
/// files means the screens themselves stay platform-free and readable.
enum Platform {

    static func copyToClipboard(_ url: URL) {
        #if os(iOS)
        UIPasteboard.general.url = url
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }

    /// Opens a URL — or a downloaded file — outside the app.
    static func openExternally(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// iOS can deep-link into its own notification settings; macOS cannot.
    static var canOpenNotificationSettings: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    static func openNotificationSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

extension View {
    /// `.insetGrouped` on iOS — the style every stock iOS list uses.
    @ViewBuilder
    func groupedListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.inset)
        #endif
    }

    /// An inline (small) navigation title. macOS has no large-title mode.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Keeps the navigation bar's background opaque. iOS only: `.navigationBar`
    /// does not exist on macOS.
    @ViewBuilder
    func opaqueNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }

    /// A floor on a sheet's size, for macOS windows only. On iOS a sheet is
    /// already the width of the screen, and forcing a wider frame overflows it
    /// on both sides — which clips the leading and trailing toolbar buttons.
    @ViewBuilder
    func macWindowSize(minWidth: CGFloat, minHeight: CGFloat) -> some View {
        #if os(iOS)
        self
        #else
        frame(minWidth: minWidth, minHeight: minHeight)
        #endif
    }

    /// Half-height sheet on iOS; macOS sizes its sheets itself.
    @ViewBuilder
    func mediumSheet() -> some View {
        #if os(iOS)
        presentationDetents([.medium])
        #else
        frame(minWidth: 420, minHeight: 320)
        #endif
    }
}
