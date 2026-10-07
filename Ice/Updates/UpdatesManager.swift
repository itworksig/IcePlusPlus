//
//  UpdatesManager.swift
//  Ice
//

import Sparkle
import SwiftUI

/// Manager for app updates.
@MainActor
final class UpdatesManager: NSObject, ObservableObject {
    /// UserDefaults key for the last GitHub release check.
    private static let lastCheckDefaultsKey = "IcePlusPlusLastUpdateCheck"

    /// How long to wait between automatic checks.
    private static let automaticCheckInterval: TimeInterval = 60 * 60 * 24

    /// A Boolean value that indicates whether the user can check for updates.
    @Published var canCheckForUpdates = false

    /// The date of the last update check.
    @Published var lastUpdateCheckDate: Date?

    /// Short status shown under the Check for Updates button.
    @Published var updateStatus: String?

    /// True while a check or download is in progress.
    @Published var isCheckingForUpdates = false

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// Delayed automatic check.
    private var automaticCheckTask: Task<Void, Never>?

    /// The underlying updater controller.
    ///
    /// Sparkle is not started. Its feed is still signed for the upstream key,
    /// so it would reject releases from this fork, and a debug build hangs
    /// inside Sparkle's own check. The toggles stay stored in Sparkle's defaults.
    private(set) lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    /// The underlying updater.
    var updater: SPUUpdater {
        updaterController.updater
    }

    /// A Boolean value that indicates whether to automatically check for updates.
    var automaticallyChecksForUpdates: Bool {
        get {
            updater.automaticallyChecksForUpdates
        }
        set {
            let changed = updater.automaticallyChecksForUpdates != newValue
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
            if changed {
                scheduleAutomaticCheck()
            }
        }
    }

    /// A Boolean value that indicates whether to automatically download updates.
    var automaticallyDownloadsUpdates: Bool {
        get {
            updater.automaticallyDownloadsUpdates
        }
        set {
            objectWillChange.send()
            updater.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Creates an updates manager with the given app state.
    init(appState: AppState) {
        self.appState = appState
        super.init()
        if let stored = UserDefaults.standard.object(forKey: Self.lastCheckDefaultsKey) as? Date {
            lastUpdateCheckDate = stored
        }
    }

    /// Sets up the manager.
    func performSetup() {
        _ = updaterController
        canCheckForUpdates = true
        if lastUpdateCheckDate == nil {
            lastUpdateCheckDate = updater.lastUpdateCheckDate
        }
        scheduleAutomaticCheck()
    }

    /// Checks GitHub for a release newer than this build.
    @objc func checkForUpdates() {
        guard !isCheckingForUpdates else {
            return
        }
        automaticCheckTask?.cancel()
        Task {
            await self.runCheck(userInitiated: true)
        }
    }

    /// Schedules one check when automatic checks are on and the last one is old.
    private func scheduleAutomaticCheck() {
        automaticCheckTask?.cancel()
        guard automaticallyChecksForUpdates else {
            return
        }
        automaticCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, !Task.isCancelled else {
                return
            }
            if let last = self.lastUpdateCheckDate,
               Date().timeIntervalSince(last) < Self.automaticCheckInterval {
                return
            }
            await self.runCheck(userInitiated: false)
        }
    }

    /// Compares the installed version with the latest GitHub release.
    private func runCheck(userInitiated: Bool) async {
        guard !isCheckingForUpdates else {
            return
        }
        isCheckingForUpdates = true
        defer {
            isCheckingForUpdates = false
        }
        if userInitiated {
            presentSettings()
            updateStatus = String(localized: "Checking for updates…")
        }
        recordCheckDate()

        let installedRaw = Constants.versionString
        guard let installed = ReleaseVersion(installedRaw) else {
            if userInitiated {
                show(String(localized: "Could not check for updates."))
            }
            return
        }

        let release: GitHubRelease
        do {
            release = try await GitHubUpdates.latest()
        } catch UpdateFailure.noRelease {
            let message = Self.format(
                "No published release yet. You are running %@.",
                installed.display
            )
            updateStatus = message
            if userInitiated {
                show(message)
            }
            return
        } catch {
            Logger.updates.error("Update check failed: \(error.localizedDescription)")
            if userInitiated {
                show(
                    String(localized: "Could not check for updates."),
                    detail: error.localizedDescription
                )
            }
            return
        }

        guard let remote = ReleaseVersion(release.tagName) else {
            Logger.updates.error("Release tag is not a version: \(release.tagName)")
            if userInitiated {
                show(String(localized: "Could not check for updates."))
            }
            return
        }

        if remote > installed {
            let message = Self.format(
                "Version %@ is now available. You are running %@.",
                remote.display,
                installed.display
            )
            updateStatus = message
            if !userInitiated, !automaticallyDownloadsUpdates {
                appState?.userNotificationManager.addRequest(
                    with: .updateCheck,
                    title: String(localized: "A new update is available"),
                    body: Self.format("Version %@ is now available", remote.display)
                )
            }
            let shouldDownload = userInitiated || automaticallyDownloadsUpdates
            guard shouldDownload, askToInstall(message: message, release: release) else {
                return
            }
            await downloadAndInstall(release, newerThan: installed)
        } else {
            let message = Self.format("Ice++ %@ is up to date.", installed.display)
            updateStatus = message
            if userInitiated {
                show(message)
            }
        }
    }

    /// Downloads the Apple silicon build and replaces this app.
    private func downloadAndInstall(_ release: GitHubRelease, newerThan installed: ReleaseVersion) async {
        let version = ReleaseVersion(release.tagName)?.display ?? release.tagName
        updateStatus = Self.format("Downloading version %@…", version)
        do {
            let app = try await GitHubUpdates.downloadApp(
                from: release,
                expectedBundleIdentifier: Constants.bundleIdentifier,
                newerThan: installed
            )
            try GitHubUpdates.spawnReplacement(
                app: app,
                destination: Bundle.main.bundleURL
            )
            NSApp.terminate(nil)
        } catch UpdateFailure.missingAsset {
            updateStatus = String(localized: "The release has no Apple silicon download.")
            show(
                String(localized: "The release has no Apple silicon download."),
                detail: nil,
                open: release.htmlURL
            )
        } catch {
            Logger.updates.error("Update install failed: \(error.localizedDescription)")
            updateStatus = String(localized: "The update could not be installed.")
            show(
                String(localized: "The update could not be installed."),
                detail: error.localizedDescription
            )
        }
    }

    /// Opens About so the check status is visible.
    private func presentSettings() {
        guard let appState else {
            return
        }
        appState.navigationState.settingsNavigationIdentifier = .about
        appState.activate(withPolicy: .regular)
        appState.openSettingsWindow()
    }

    /// Asks before replacing the running app.
    private func askToInstall(message: String, release: GitHubRelease) -> Bool {
        presentSettings()
        let alert = NSAlert()
        alert.messageText = String(localized: "A new update is available")
        alert.informativeText = message
        alert.addButton(withTitle: String(localized: "Install and Relaunch"))
        alert.addButton(withTitle: String(localized: "Later"))
        if GitHubUpdates.preferredAsset(in: release) == nil {
            alert.addButton(withTitle: String(localized: "Open Release Page"))
        }
        let response = alert.runModal()
        if response == .alertThirdButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
            return false
        }
        return response == .alertFirstButtonReturn
    }

    /// Shows a short result. When `url` is set, the first button opens it.
    private func show(_ message: String, detail: String? = nil, open url: URL? = nil) {
        updateStatus = message
        let alert = NSAlert()
        alert.messageText = message
        if let detail, !detail.isEmpty {
            alert.informativeText = detail
        }
        if url != nil {
            alert.addButton(withTitle: String(localized: "Open Release Page"))
            alert.addButton(withTitle: String(localized: "OK"))
        }
        if alert.runModal() == .alertFirstButtonReturn, let url {
            NSWorkspace.shared.open(url)
        }
    }

    private func recordCheckDate() {
        let now = Date()
        lastUpdateCheckDate = now
        UserDefaults.standard.set(now, forKey: Self.lastCheckDefaultsKey)
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return String(format: template, arguments: arguments)
    }
}

private extension Logger {
    static let updates = Logger(category: "Updates")
}

// MARK: UpdatesManager: SPUUpdaterDelegate
extension UpdatesManager: SPUUpdaterDelegate {
    /// Never show Sparkle's "check for updates automatically?" permission prompt.
    ///
    /// Ice runs as a background app (LSUIElement), so it is not active when
    /// Sparkle presents that dialog and the dialog can never process the
    /// response: its buttons and checkbox stay frozen, the choice is never
    /// saved, and the prompt reappears on every launch until the user force
    /// quits (jordanbaird/Ice#681). Ice already exposes the same choice with
    /// its "Automatically check/download updates" toggles in Settings, so the
    /// prompt is redundant as well as broken.
    @objc(updaterShouldPromptForPermissionToCheckForUpdates:)
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        false
    }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.requestAuthorization()
    }
}

// MARK: UpdatesManager: SPUStandardUserDriverDelegate
extension UpdatesManager: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        if NSApp.isActive {
            return immediateFocus
        } else {
            // Sparkle cannot present interactive UI while Ice sits in the
            // background (LSUIElement): the dialog shows but never dismisses
            // (jordanbaird/Ice#681). Activate first so the update alert works.
            appState?.activate(withPolicy: .regular)
            return true
        }
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard let appState else {
            return
        }
        if handleShowingUpdate {
            // Sparkle is presenting the update alert itself, so activate for
            // the same reason as above.
            appState.activate(withPolicy: .regular)
        } else if !state.userInitiated {
            appState.userNotificationManager.addRequest(
                with: .updateCheck,
                title: String(localized: "A new update is available"),
                body: String(localized: "Version \(update.displayVersionString) is now available")
            )
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.removeDeliveredNotifications(with: [.updateCheck])
    }
}

// MARK: UpdatesManager: BindingExposable
extension UpdatesManager: BindingExposable { }
