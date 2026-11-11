//
//  MenuBarConfigurationArchive.swift
//  Ice
//

import Cocoa

enum MenuBarConfigurationArchive {
    private static var domain: String {
        Bundle.main.bundleIdentifier ?? "com.itworksig.iceplusplus"
    }

    static func backupIfStale() {
        let directory = backupDirectory()
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let existing = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        if existing.contains(where: { $0.lastPathComponent.contains(today) }) {
            return
        }
        _ = writeBackup(named: "auto-\(today)")
        let sorted = existing.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for extra in sorted.dropFirst(4) {
            try? FileManager.default.removeItem(at: extra)
        }
    }

    @discardableResult
    static func export(to url: URL) -> Bool {
        guard let data = plistData() else {
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Replaces the saved settings. The caller relaunches so every manager reloads.
    static func importReplacing(from url: URL) throws {
        _ = writeBackup(named: "before-import-\(timestamp())")
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        UserDefaults.standard.setPersistentDomain(plist, forName: domain)
        UserDefaults.standard.synchronize()
    }

    static func restoreLatestBackup() throws {
        let files = ((try? FileManager.default.contentsOfDirectory(at: backupDirectory(), includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "plist" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        guard let latest = files.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try importReplacing(from: latest)
    }

    static func reset() {
        _ = writeBackup(named: "before-reset-\(timestamp())")
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }

    static func exportPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.nameFieldStringValue = "Ice-Configuration.plist"
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            _ = export(to: url)
        }
    }

    static func importPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            do {
                try importReplacing(from: url)
                Task { @MainActor in
                    AppLanguage.relaunch()
                }
            } catch {
                return
            }
        }
    }

    static func restoreAndRelaunch() {
        do {
            try restoreLatestBackup()
            Task { @MainActor in
                AppLanguage.relaunch()
            }
        } catch {
            return
        }
    }

    static func resetAndRelaunch() {
        reset()
        Task { @MainActor in
            AppLanguage.relaunch()
        }
    }

    private static func plistData() -> Data? {
        let domain = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        return try? PropertyListSerialization.data(fromPropertyList: domain, format: .xml, options: 0)
    }

    @discardableResult
    private static func writeBackup(named name: String) -> URL? {
        let directory = backupDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name).appendingPathExtension("plist")
        guard let data = plistData() else {
            return nil
        }
        try? data.write(to: url, options: .atomic)
        return url
    }

    private static func backupDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Ice/Backups", isDirectory: true)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    }
}
