//
//  SystemMenuExtras.swift
//  Ice
//

import Cocoa

/// Clock, Wi-Fi, battery, and Control Center are separate menu bar items that
/// share one system process. Assessment mode can only hide whole apps, so
/// these use the menu bar visibility switch Control Center already stores.
enum SystemMenuExtra: String, CaseIterable, Identifiable, Codable {
    case wifi = "WiFi"
    case battery = "Battery"
    case clock = "Clock"
    case controlCenter = "BentoBox-0"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .battery: "Battery"
        case .clock: "Clock"
        case .controlCenter: "Control Center"
        }
    }

    /// `AXIdentifier` values seen on the menu bar.
    var axIdentifiers: Set<String> {
        switch self {
        case .wifi: ["com.apple.menuextra.wifi"]
        case .battery: ["com.apple.menuextra.battery"]
        case .clock: ["com.apple.menuextra.clock"]
        case .controlCenter: ["com.apple.menuextra.controlcenter"]
        }
    }

    static func matching(identifier: String?) -> SystemMenuExtra? {
        guard let identifier else {
            return nil
        }
        return allCases.first { $0.axIdentifiers.contains(identifier) }
    }
}

enum SystemMenuExtraStore {
    private static let domainName = "com.apple.controlcenter"

    static func isShown(_ item: SystemMenuExtra) -> Bool {
        let key = visibilityKey(item)
        guard let domain = UserDefaults.standard.persistentDomain(forName: domainName),
              let value = domain[key]
        else {
            return true
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let flag = value as? Bool {
            return flag
        }
        return true
    }

    /// Writes the menu bar visibility switch. Control Center reloads once,
    /// and only when the value actually changes.
    static func setShown(_ shown: Bool, _ item: SystemMenuExtra, reload: Bool = true) {
        guard isShown(item) != shown else {
            return
        }
        var domain = UserDefaults.standard.persistentDomain(forName: domainName) ?? [:]
        domain[visibilityKey(item)] = shown
        UserDefaults.standard.setPersistentDomain(domain, forName: domainName)
        if reload {
            reloadControlCenter()
        }
    }

    static func reloadIfChanged() {
        reloadControlCenter()
    }

    private static func visibilityKey(_ item: SystemMenuExtra) -> String {
        "NSStatusItem VisibleCC \(item.rawValue)"
    }

    private static func reloadControlCenter() {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.controlcenter"
        ).first else {
            return
        }
        app.terminate()
    }
}
