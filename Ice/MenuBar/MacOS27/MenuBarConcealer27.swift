//
//  MenuBarConcealer27.swift
//  Ice
//

import Cocoa

/// Hides menu bar apps on macOS 27 without stretching a status item.
///
/// macOS 27.2 parks a status item whose length fills the status area off the
/// bottom of the screen (measured: length 739 on a 771pt area becomes the
/// frame `(0, -33, 755, 33)`). That blank item pushes every other icon out of
/// the bar, and the Ice Bar then has nothing left to show. Assessment mode
/// removes only the apps the user assigned to a hidden section.
@MainActor
final class MenuBarConcealer27 {
    /// Where an app's menu bar item belongs. Missing apps stay visible.
    enum Section: Int {
        case visible = 0
        case hidden = 1
        case alwaysHidden = 2
    }

    /// An app the Ice Bar should list because it is assigned to a hidden section.
    struct IceBarEntry {
        let bundleID: String
        let name: String
        let icon: NSImage?
        let pid: pid_t
    }

    private let backend = MenuBarAssessmentBackend()
    private let logger = Logger(category: "MenuBarConcealer27")
    private weak var appState: AppState?
    private var observers = [NSObjectProtocol]()
    private var applyChain: Task<Void, Never>?
    private var liveToken: AnyObject?
    private var applied = Set<String>()
    /// Bundle identifiers passed to the live assertion. A new app is hidden
    /// until this list is refreshed, even when it is not meant to be concealed.
    private var appliedAllow = [String]()
    private var temporarilyShown = Set<String>()
    private var isReleased = false

    /// The section recorded for an app. Apps with no entry are visible.
    func sectionKind(for bundleID: String) -> MenuBarItemAXDiscovery.SectionKind {
        switch layout[bundleID] {
        case .hidden: .hidden
        case .alwaysHidden: .alwaysHidden
        default: .visible
        }
    }

    /// Whether the app is currently removed from the menu bar.
    func isConcealed(_ bundleID: String) -> Bool {
        applied.contains(bundleID)
    }

    /// Running apps assigned to Hidden or Always Hidden, for the layout editor.
    func iceBarEntries() -> [IceBarEntry] {
        iceBarEntries(in: nil)
    }

    /// Running apps for one Ice Bar section. Pass nil to include both hidden
    /// sections. Always Hidden must not show up on the Hidden bar.
    func iceBarEntries(in sectionName: MenuBarSection.Name?) -> [IceBarEntry] {
        let wanted: Section? = switch sectionName {
        case .hidden: .hidden
        case .alwaysHidden: .alwaysHidden
        case .visible, nil: nil
        }
        return layout.compactMap { bundleID, section in
            if let wanted {
                guard section == wanted else {
                    return nil
                }
            } else {
                guard section == .hidden || section == .alwaysHidden else {
                    return nil
                }
            }
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
                return nil
            }
            return IceBarEntry(
                bundleID: bundleID,
                name: app.localizedName ?? bundleID,
                icon: app.icon,
                pid: app.processIdentifier
            )
        }
    }

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        guard MenuBarAssessmentBackend.isAvailable else {
            logger.error("MenuBarClientCore assertions are unavailable, so items will not be hidden")
            return
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.update()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.releaseAll()
            }
        })
        update()
    }

    /// Remembers which section an app belongs to and applies it.
    func setSection(_ section: Section, for bundleID: String) {
        guard isConcealable(bundleID) else {
            return
        }
        var stored = layout
        if section == .visible {
            stored.removeValue(forKey: bundleID)
        } else {
            stored[bundleID] = section
        }
        layout = stored
        update()
    }

    /// Puts one concealed app back on the bar long enough to open its menu.
    func temporarilyShow(_ bundleID: String) {
        temporarilyShown.insert(bundleID)
        update()
    }

    /// Hides an app that was temporarily shown, if its section is still collapsed.
    func endTemporaryShow(_ bundleID: String) {
        temporarilyShown.remove(bundleID)
        update()
    }

    /// Recomputes the hidden set from the layout and the section toggles.
    func update() {
        let conceal = desiredConcealSet()
        let previous = applyChain
        applyChain = Task { [weak self] in
            await previous?.value
            await self?.apply(conceal)
        }
    }

    /// Drops every assertion so quitting Ice restores the menu bar immediately.
    func releaseAll() {
        isReleased = true
        applyChain?.cancel()
        applyChain = nil
        if let liveToken {
            backend.invalidate(liveToken)
            self.liveToken = nil
        }
        applied = []
        appliedAllow = []
    }

    private var layout: [String: Section] {
        get {
            let stored = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
            return stored.compactMapValues(Section.init(rawValue:))
        }
        set {
            let raw = newValue.mapValues(\.rawValue)
            Defaults.set(raw, forKey: .macOS27Layout)
        }
    }

    private func desiredConcealSet() -> Set<String> {
        guard let appState else {
            return []
        }
        var conceal = Set<String>()
        for (bundleID, section) in layout {
            guard isConcealable(bundleID), section != .visible else {
                continue
            }
            let name: MenuBarSection.Name = section == .alwaysHidden ? .alwaysHidden : .hidden
            guard
                let menuSection = appState.menuBarManager.section(withName: name),
                menuSection.controlItem.isAddedToMenuBar,
                menuSection.controlItem.state == .hideItems
            else {
                continue
            }
            conceal.insert(bundleID)
        }
        conceal.subtract(temporarilyShown)
        return conceal
    }

    /// System items and Ice itself must stay on the bar. Hiding `com.apple.*`
    /// would try to remove Control Center, which assessment mode will not do,
    /// and hiding Ice removes the only control that can bring items back.
    private func isConcealable(_ bundleID: String) -> Bool {
        bundleID != Bundle.main.bundleIdentifier && !bundleID.hasPrefix("com.apple.")
    }

    private func apply(_ conceal: Set<String>) async {
        guard !isReleased else {
            return
        }
        if conceal.isEmpty {
            guard liveToken != nil else {
                return
            }
            if let liveToken {
                backend.invalidate(liveToken)
                self.liveToken = nil
            }
            applied = []
            appliedAllow = []
            return
        }
        let allowList = allowedBundleIDs(concealing: conceal)
        guard conceal != applied || allowList != appliedAllow else {
            return
        }
        do {
            let token = try await backend.activate(allowedBundleIDs: allowList)
            guard !isReleased else {
                backend.invalidate(token)
                return
            }
            let previous = liveToken
            liveToken = token
            applied = conceal
            appliedAllow = allowList
            if let previous {
                backend.invalidate(previous)
            }
            logger.info("Concealed \(conceal.count) menu bar apps")
        } catch {
            logger.error("Could not conceal menu bar apps: \(error)")
        }
    }

    /// Apps that stay on the bar: everything running, except the concealed set.
    /// Ice is always included so its chevrons remain clickable.
    private func allowedBundleIDs(concealing conceal: Set<String>) -> [String] {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        var allow = running.subtracting(conceal)
        if let own = Bundle.main.bundleIdentifier {
            allow.insert(own)
        }
        return allow.sorted()
    }
}
