//
//  IceCommands.swift
//  Ice
//

import Cocoa

/// Shared entry for hotkeys, Shortcuts, Siri, AppleScript, and the URL scheme.
@MainActor
enum IceCommands {
    static weak var appState: AppState?

    private static var focusIDs = Set<String>()
    private static var revealIDs = Set<String>()
    private static var groupIDs = Set<String>()
    private static var savedSystem: [String: Bool] = [:]
    private static var menuBarWasVisible = true

    static var focusActive: Bool { !focusIDs.isEmpty || !savedSystem.isEmpty }

    static func toggleFocus() {
        if focusActive {
            endFocus()
        } else {
            beginFocus()
        }
    }

    static func beginFocus() {
        guard let appState else {
            return
        }
        menuBarWasVisible = NSMenu.menuBarVisible()
        var saved: [String: Bool] = [:]
        var changed = false
        for item in SystemMenuExtra.allCases {
            let shown = SystemMenuExtraStore.isShown(item)
            saved[item.rawValue] = shown
            if shown {
                SystemMenuExtraStore.setShown(false, item, reload: false)
                changed = true
            }
        }
        if changed {
            SystemMenuExtraStore.reloadIfChanged()
        }
        savedSystem = saved
        focusIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).filter(isConcealable)
        )
        pushConcealment()
        NSMenu.setMenuBarVisible(false)
        _ = appState
    }

    static func endFocus() {
        guard focusActive else {
            return
        }
        focusIDs = []
        pushConcealment()
        var changed = false
        for item in SystemMenuExtra.allCases {
            let shown = savedSystem[item.rawValue] ?? true
            if SystemMenuExtraStore.isShown(item) != shown {
                SystemMenuExtraStore.setShown(shown, item, reload: false)
                changed = true
            }
        }
        savedSystem = [:]
        if changed {
            SystemMenuExtraStore.reloadIfChanged()
        }
        NSMenu.setMenuBarVisible(menuBarWasVisible)
    }

    static func setGroupMembers(_ bundleIDs: Set<String>) {
        groupIDs = Set(bundleIDs.filter(isConcealable))
        pushConcealment()
    }

    /// Hides normally visible apps while a hidden section is open.
    static func refreshReveal() {
        guard
            let appState,
            appState.settingsManager.generalSettingsManager.hideShownWhenRevealing,
            !appState.settingsManager.generalSettingsManager.useIceBar,
            let hidden = appState.menuBarManager.section(withName: .hidden),
            !hidden.isHidden
        else {
            revealIDs = []
            pushConcealment()
            return
        }
        let layout = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
        revealIDs = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier).filter { id in
                isConcealable(id) && (layout[id] ?? MenuBarConcealer27.Section.visible.rawValue) == MenuBarConcealer27.Section.visible.rawValue
            }
        )
        pushConcealment()
    }

    static func showHidden() {
        appState?.menuBarManager.section(withName: .hidden)?.show()
    }

    static func hideHidden() {
        appState?.menuBarManager.section(withName: .hidden)?.hide()
    }

    static func showIceBarAtMouse() async {
        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else {
            return
        }
        appState?.menuBarManager.iceBarPanel.placeAtMouse = true
        await appState?.menuBarManager.iceBarPanel.show(section: .hidden, on: screen)
    }

    static func applyPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let preset = appState?.menuBarBehaviors.presets.first(where: {
                $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
            })
        else {
            return
        }
        appState?.menuBarBehaviors.apply(preset)
    }

    static func handle(_ url: URL) {
        let host = url.host?.lowercased() ?? ""
        if host == "preset" {
            let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "name" }?
                .value
                ?? String(url.path.drop { $0 == "/" })
            applyPreset(named: name.removingPercentEncoding ?? name)
            return
        }
        handle(command: host)
    }

    static func handle(command: String) {
        let text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("preset:") {
            applyPreset(named: String(text.dropFirst("preset:".count)))
            return
        }
        switch text.lowercased() {
        case "focus":
            toggleFocus()
        case "show-hidden":
            showHidden()
        case "hide-hidden":
            hideHidden()
        case "ice-bar":
            Task { await showIceBarAtMouse() }
        default:
            break
        }
    }

    private static func pushConcealment() {
        guard #available(macOS 27, *) else {
            return
        }
        appState?.menuBarConcealer.setExtraConcealment(focusIDs.union(revealIDs).union(groupIDs))
    }

    private static func isConcealable(_ bundleID: String) -> Bool {
        bundleID != Bundle.main.bundleIdentifier && !bundleID.hasPrefix("com.apple.")
    }
}

enum ScriptRunner {
    static func run(_ path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        let process = Process()
        if FileManager.default.isExecutableFile(atPath: path), !path.hasSuffix(".sh") {
            process.executableURL = URL(fileURLWithPath: path)
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = [path]
        }
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        if semaphore.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            return false
        }
        return process.terminationStatus == 0
    }
}
