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
    /// When set, this preset is applied while the connected displays match.
    var displaySignature: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, layout, hiddenSystem, displaySignature
    }

    init(id: UUID, name: String, layout: [String: Int], hiddenSystem: [String], displaySignature: String? = nil) {
        self.id = id
        self.name = name
        self.layout = layout
        self.hiddenSystem = hiddenSystem
        self.displaySignature = displaySignature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        layout = try container.decode([String: Int].self, forKey: .layout)
        hiddenSystem = try container.decode([String].self, forKey: .hiddenSystem)
        displaySignature = try container.decodeIfPresent(String.self, forKey: .displaySignature)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(layout, forKey: .layout)
        try container.encode(hiddenSystem, forKey: .hiddenSystem)
        try container.encodeIfPresent(displaySignature, forKey: .displaySignature)
    }
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
    var startMinute: Int = 0
    var endMinute: Int = 0

    init(id: UUID, enabled: Bool, kind: Kind, bundleID: String, batteryPercent: Int, startHour: Int, endHour: Int, showHidden: Bool, action: Action = .showHidden, presetID: UUID? = nil, wifiName: String = "", latitude: Double = 0, longitude: Double = 0, radiusMeters: Double = 200, month: Int = 0, day: Int = 0, weekdays: [Int] = [], scriptPath: String = "", startMinute: Int = 0, endMinute: Int = 0) {
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
        self.startMinute = startMinute
        self.endMinute = endMinute
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
        startMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
    }
}

struct CapturedPlace: Equatable {
    var latitude: Double
    var longitude: Double
}

/// Saved layouts, show/hide rules, and moving icons out from under the notch.
@MainActor
final class MenuBarBehaviors: ObservableObject {
    @Published var presets: [MenuBarPreset] = []
    @Published var automations: [MenuBarAutomation] = []
    @Published var relieveNotch = false
    @Published var capturedPlace: CapturedPlace?

    func useCurrentLocation() {
        captureLocation { [weak self] place in
            Task { @MainActor in
                self?.capturedPlace = CapturedPlace(
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude
                )
            }
        }
    }

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
                self?.applyMatchingDisplayPreset()
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
            self.applyMatchingDisplayPreset()
            self.relieveNotchIfNeeded()
            self.evaluateAutomations()
        }
    }

    func saveCurrentLayout(named name: String, forCurrentDisplays: Bool = false) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        let stored = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
        let hidden = SystemMenuExtra.allCases.filter { !SystemMenuExtraStore.isShown($0) }.map(\.rawValue)
        presets.append(MenuBarPreset(
            id: UUID(),
            name: trimmed,
            layout: stored,
            hiddenSystem: hidden,
            displaySignature: forCurrentDisplays ? Self.currentDisplaySignature() : nil
        ))
        persist()
    }

    func currentNetworkName() -> String? {
        if sensors.hasStarted {
            sensors.refreshSSID()
        } else {
            sensors.start {}
        }
        return sensors.ssid
    }

    func captureLocation(_ handler: @escaping (CLLocation) -> Void) {
        sensors.captureNextLocation(handler)
    }

    /// Runs one automation immediately from the Ice Bar.
    func run(_ rule: MenuBarAutomation) {
        guard let section = appState?.menuBarManager.section(withName: .hidden) else {
            return
        }
        switch rule.action {
        case .applyPreset:
            if let id = rule.presetID, let preset = presets.first(where: { $0.id == id }) {
                apply(preset)
            }
        case .showHidden:
            if rule.showHidden {
                section.show()
            } else {
                section.hide()
            }
        }
    }

    static func currentDisplaySignature() -> String {
        NSScreen.screens.map { screen in
            let frame = screen.frame
            return "\(Int(frame.width))x\(Int(frame.height))@\(Int(frame.minX)),\(Int(frame.minY))"
        }
        .sorted()
        .joined(separator: "|")
    }

    private var appliedDisplaySignature: String?

    private func applyMatchingDisplayPreset() {
        let signature = Self.currentDisplaySignature()
        guard signature != appliedDisplaySignature else {
            return
        }
        appliedDisplaySignature = signature
        guard let preset = presets.first(where: { $0.displaySignature == signature }) else {
            return
        }
        apply(preset)
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
        if Defaults.bool(forKey: .relieveNotchUserSet) {
            Defaults.ifPresent(key: .relieveNotch, assign: &relieveNotch)
        } else {
            relieveNotch = false
        }
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
        Defaults.set(true, forKey: .relieveNotchUserSet)
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
            let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let start = rule.startHour * 60 + rule.startMinute
            let end = rule.endHour * 60 + rule.endMinute
            if start == end {
                return true
            }
            if start < end {
                return now >= start && now < end
            }
            return now >= start || now < end
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
        let layout = Defaults.object(forKey: .macOS27Layout) as? [String: Int] ?? [:]
        for item in items {
            guard
                let frame = item.axFrame,
                let bundleID = item.bundleID,
                !bundleID.hasPrefix("com.apple."),
                bundleID != Bundle.main.bundleIdentifier,
                notches.contains(where: { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }),
                layout[bundleID] == nil
            else {
                continue
            }
            appState.menuBarConcealer.setSection(.hidden, for: bundleID)
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
    var hasStarted: Bool { started }
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

    func captureNextLocation(_ handler: @escaping (CLLocation) -> Void) {
        onLocation = handler
        guard started else {
            start {}
            return
        }
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if let location {
            onLocation = nil
            handler(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        let place = location
        let once = onLocation
        onLocation = nil
        Task { @MainActor in
            if let place {
                once?(place)
            }
            self.onUpdate?()
        }
    }

    func refreshSSID() {
        ssid = CWWiFiClient.shared().interface()?.ssid()
    }

    private var onLocation: ((CLLocation) -> Void)?
}
