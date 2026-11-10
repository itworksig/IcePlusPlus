//
//  MenuBarBehaviors.swift
//  Ice
//

import Cocoa
import Combine
import CoreLocation
import CoreWLAN
import IOKit.ps

struct MenuBarPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// Bundle identifier to `MenuBarConcealer27.Section` raw value.
    var layout: [String: Int]
    /// System extras that stay off the menu bar.
    var hiddenSystem: [String]
}

struct MenuBarAutomation: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case frontmostApp
        case batteryBelow
        case schedule
        case wifi
        case location
        case date
        case unplugged
        case script
    }

    enum Action: String, Codable {
        case showHidden
        case applyPreset
    }

    var id: UUID
    var enabled: Bool
    var kind: Kind
    var bundleID: String
    var batteryPercent: Int
    var startHour: Int
    var endHour: Int
    /// When the rule matches and the action shows the section, the hidden section is shown.
    var showHidden: Bool
    var action: Action = .showHidden
    var presetID: UUID?
    var wifiName: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var radiusMeters: Double = 200
    var month: Int = 0
    var day: Int = 0
    /// Calendar weekdays, Sunday = 1. Empty matches any day.
    var weekdays: [Int] = []
    var scriptPath: String = ""

    init(id: UUID, enabled: Bool, kind: Kind, bundleID: String, batteryPercent: Int, startHour: Int, endHour: Int, showHidden: Bool, action: Action = .showHidden, presetID: UUID? = nil, wifiName: String = "", latitude: Double = 0, longitude: Double = 0, radiusMeters: Double = 200, month: Int = 0, day: Int = 0, weekdays: [Int] = [], scriptPath: String = "") {
        self.id = id
        self.enabled = enabled
        self.kind = kind
        self.bundleID = bundleID
        self.batteryPercent = batteryPercent
        self.startHour = startHour
        self.endHour = endHour
        self.showHidden = showHidden
        self.action = action
        self.presetID = presetID
        self.wifiName = wifiName
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.month = month
        self.day = day
        self.weekdays = weekdays
        self.scriptPath = scriptPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        kind = try container.decode(Kind.self, forKey: .kind)
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID) ?? ""
        batteryPercent = try container.decodeIfPresent(Int.self, forKey: .batteryPercent) ?? 20
        startHour = try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        endHour = try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 18
        showHidden = try container.decodeIfPresent(Bool.self, forKey: .showHidden) ?? true
        action = try container.decodeIfPresent(Action.self, forKey: .action) ?? .showHidden
        presetID = try container.decodeIfPresent(UUID.self, forKey: .presetID)
        wifiName = try container.decodeIfPresent(String.self, forKey: .wifiName) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        radiusMeters = try container.decodeIfPresent(Double.self, forKey: .radiusMeters) ?? 200
        month = try container.decodeIfPresent(Int.self, forKey: .month) ?? 0
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 0
        weekdays = try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        scriptPath = try container.decodeIfPresent(String.self, forKey: .scriptPath) ?? ""
    }
}

/// Saved layouts, show/hide rules, and moving icons out from under the notch.
@MainActor
final class MenuBarBehaviors: ObservableObject {
    @Published var presets: [MenuBarPreset] = []
    @Published var automations: [MenuBarAutomation] = []
    @Published var relieveNotch = true

    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()
    private var appliedRuleID: UUID?
    private var timer: Timer?
    private var ruleUndoLayout: [String: Int]?
    private var ruleUndoSystems: [String]?
    private var scriptResults: [String: Bool] = [:]
    private let sensors = MenuBarSensors()

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        load()
        let center = NSWorkspace.shared.notificationCenter
        var c = Set<AnyCancellable>()
        center.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.evaluateAutomations()
            }
            .store(in: &c)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.relieveNotchIfNeeded()
            }
            .store(in: &c)
        cancellables = c
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.evaluateAutomations()
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.relieveNotchIfNeeded()
            self.evaluateAutomations()
        }
    }

    func saveCurrentLayout(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let appState else {
            return
        }
        let stored = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
        let hidden = SystemMenuExtra.allCases.filter { !SystemMenuExtraStore.isShown($0) }.map(\.rawValue)
        presets.append(MenuBarPreset(id: UUID(), name: trimmed, layout: stored, hiddenSystem: hidden))
        persist()
        _ = appState
    }

    func apply(_ preset: MenuBarPreset) {
        guard let appState else {
            return
        }
        if #available(macOS 27, *) {
            appState.menuBarConcealer.replaceLayout(preset.layout)
        }
        let hidden = Set(preset.hiddenSystem)
        var changed = false
        for item in SystemMenuExtra.allCases {
            let shown = !hidden.contains(item.rawValue)
            if SystemMenuExtraStore.isShown(item) != shown {
                SystemMenuExtraStore.setShown(shown, item, reload: false)
                changed = true
            }
        }
        if changed {
            SystemMenuExtraStore.reloadIfChanged()
        }
    }

    func delete(_ preset: MenuBarPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func addAutomation(_ automation: MenuBarAutomation) {
        automations.append(automation)
        persist()
        evaluateAutomations()
    }

    func deleteAutomation(_ automation: MenuBarAutomation) {
        automations.removeAll { $0.id == automation.id }
        if appliedRuleID == automation.id {
            appliedRuleID = nil
        }
        persist()
    }

    func setAutomationEnabled(_ automation: MenuBarAutomation, enabled: Bool) {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else {
            return
        }
        automations[index].enabled = enabled
        persist()
        evaluateAutomations()
    }

    private func load() {
        if let data = Defaults.data(forKey: .menuBarPresets),
           let decoded = try? JSONDecoder().decode([MenuBarPreset].self, from: data) {
            presets = decoded
        }
        if let data = Defaults.data(forKey: .menuBarAutomations),
           let decoded = try? JSONDecoder().decode([MenuBarAutomation].self, from: data) {
            automations = decoded
        }
        Defaults.ifPresent(key: .relieveNotch, assign: &relieveNotch)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            Defaults.set(data, forKey: .menuBarPresets)
        }
        if let data = try? JSONEncoder().encode(automations) {
            Defaults.set(data, forKey: .menuBarAutomations)
        }
        Defaults.set(relieveNotch, forKey: .relieveNotch)
    }

    func updateRelieveNotch(_ enabled: Bool) {
        relieveNotch = enabled
        persist()
        if enabled {
            relieveNotchIfNeeded()
        }
    }

    private func evaluateAutomations() {
        guard let appState, let section = appState.menuBarManager.section(withName: .hidden) else {
            return
        }
        ensureSensors()
        let match = automations.first { $0.enabled && matches($0) }
        if match?.id == appliedRuleID {
            return
        }
        if let match {
            if appliedRuleID == nil, match.action == .applyPreset {
                ruleUndoLayout = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
                ruleUndoSystems = SystemMenuExtra.allCases.filter { !SystemMenuExtraStore.isShown($0) }.map(\.rawValue)
            }
            switch match.action {
            case .applyPreset:
                if let id = match.presetID, let preset = presets.first(where: { $0.id == id }) {
                    apply(preset)
                }
            case .showHidden:
                if match.showHidden {
                    section.show(persistState: false)
                } else {
                    section.hide(persistState: false)
                }
            }
            appliedRuleID = match.id
        } else if appliedRuleID != nil {
            if let saved = ruleUndoLayout {
                if #available(macOS 27, *) {
                    appState.menuBarConcealer.replaceLayout(saved)
                }
                let hidden = Set(ruleUndoSystems ?? [])
                var changed = false
                for item in SystemMenuExtra.allCases {
                    let shown = !hidden.contains(item.rawValue)
                    if SystemMenuExtraStore.isShown(item) != shown {
                        SystemMenuExtraStore.setShown(shown, item, reload: false)
                        changed = true
                    }
                }
                if changed {
                    SystemMenuExtraStore.reloadIfChanged()
                }
                ruleUndoLayout = nil
                ruleUndoSystems = nil
            } else if Defaults.bool(forKey: .showHiddenSection) {
                section.show(persistState: false)
            } else {
                section.hide(persistState: false)
            }
            appliedRuleID = nil
        }
    }

    private func ensureSensors() {
        let needs = automations.contains { $0.enabled && ($0.kind == .wifi || $0.kind == .location) }
        if needs {
            sensors.start { [weak self] in
                self?.evaluateAutomations()
            }
        }
    }

    private func matches(_ rule: MenuBarAutomation) -> Bool {
        switch rule.kind {
        case .frontmostApp:
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            return !rule.bundleID.isEmpty && front == rule.bundleID
        case .batteryBelow:
            guard let percent = batteryPercent() else {
                return false
            }
            return percent <= rule.batteryPercent
        case .schedule:
            let hour = Calendar.current.component(.hour, from: Date())
            if rule.startHour == rule.endHour {
                return true
            }
            if rule.startHour < rule.endHour {
                return hour >= rule.startHour && hour < rule.endHour
            }
            return hour >= rule.startHour || hour < rule.endHour
        case .wifi:
            guard !rule.wifiName.isEmpty, let ssid = sensors.ssid else {
                return false
            }
            return ssid.caseInsensitiveCompare(rule.wifiName) == .orderedSame
        case .location:
            guard let here = sensors.location else {
                return false
            }
            let target = CLLocation(latitude: rule.latitude, longitude: rule.longitude)
            return here.distance(from: target) <= max(rule.radiusMeters, 50)
        case .date:
            let parts = Calendar.current.dateComponents([.month, .day, .weekday], from: Date())
            if rule.month == 0, rule.day == 0, rule.weekdays.isEmpty {
                return false
            }
            if rule.month > 0, parts.month != rule.month {
                return false
            }
            if rule.day > 0, parts.day != rule.day {
                return false
            }
            if !rule.weekdays.isEmpty, let weekday = parts.weekday, !rule.weekdays.contains(weekday) {
                return false
            }
            return true
        case .unplugged:
            return powerIsBattery()
        case .script:
            let path = rule.scriptPath
            guard !path.isEmpty else {
                return false
            }
            if let cached = scriptResults[path] {
                return cached
            }
            Task.detached { [weak self] in
                let ok = ScriptRunner.run(path)
                await MainActor.run {
                    self?.scriptResults[path] = ok
                    self?.evaluateAutomations()
                }
            }
            return false
        }
    }

    private func powerIsBattery() -> Bool {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let state = description[kIOPSPowerSourceStateKey] as? String
                ?? (description[kIOPSPowerSourceStateKey as String] as? String)
            if state == kIOPSBatteryPowerValue as String {
                return true
            }
        }
        return false
    }

    private func batteryPercent() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }
        guard let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let current = (description[kIOPSCurrentCapacityKey] as? Int)
                ?? (description[kIOPSCurrentCapacityKey as String] as? NSNumber)?.intValue
            let max = (description[kIOPSMaxCapacityKey] as? Int)
                ?? (description[kIOPSMaxCapacityKey as String] as? NSNumber)?.intValue
            guard let current, let max, max > 0 else {
                continue
            }
            return Int((Double(current) / Double(max) * 100).rounded())
        }
        return nil
    }

    private func relieveNotchIfNeeded() {
        guard relieveNotch, #available(macOS 27, *), let appState else {
            return
        }
        let notches = NSScreen.screens.compactMap(notchFrameCG)
        guard !notches.isEmpty, MenuBarItemAXDiscovery.isTrusted() else {
            return
        }
        let apps = NSWorkspace.shared.runningApplications
        let items = MenuBarItemAXDiscovery.discoverItems(in: apps)
        for item in items {
            guard let frame = item.axFrame, notches.contains(where: { $0.intersects(frame) }) else {
                continue
            }
            if let extra = SystemMenuExtra.matching(identifier: item.identifier) {
                SystemMenuExtraStore.setShown(false, extra)
                continue
            }
            if let bundleID = item.bundleID {
                appState.menuBarConcealer.setSection(.hidden, for: bundleID)
            }
        }
    }

    /// Notch frame in the same top-left coordinates Accessibility uses.
    private func notchFrameCG(_ screen: NSScreen) -> CGRect? {
        guard let notch = screen.frameOfNotch else {
            return nil
        }
        let bounds = CGDisplayBounds(screen.displayID)
        let cgY = bounds.minY + (screen.frame.maxY - notch.maxY)
        return CGRect(x: notch.minX, y: cgY, width: notch.width, height: notch.height)
    }
}

/// Location and Wi-Fi name. macOS asks for location the first time a rule needs either one.
private final class MenuBarSensors: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var started = false
    private var onUpdate: (() -> Void)?
    private(set) var location: CLLocation?
    private(set) var ssid: String?

    func start(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
        guard !started else {
            refreshSSID()
            return
        }
        started = true
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        refreshSSID()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        Task { @MainActor in
            self.onUpdate?()
        }
    }

    private func refreshSSID() {
        ssid = CWWiFiClient.shared().interface()?.ssid()
    }
}
