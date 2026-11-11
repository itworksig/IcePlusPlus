//
//  AdvancedSettingsPane.swift
//  Ice
//

import SwiftUI

struct AdvancedSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var maxSliderLabelWidth: CGFloat = 0

    private var menuBarManager: MenuBarManager {
        appState.menuBarManager
    }

    private var manager: AdvancedSettingsManager {
        appState.settingsManager.advancedSettingsManager
    }

    private func formattedToSeconds(_ interval: TimeInterval) -> LocalizedStringKey {
        let formatted = interval.formatted()
        return if interval == 1 {
            LocalizedStringKey(formatted + " second")
        } else {
            LocalizedStringKey(formatted + " seconds")
        }
    }

    var body: some View {
        IceForm {
            IceSection {
                hideApplicationMenus
                showSectionDividers
                showAllSectionsOnUserDrag
                showContextMenuOnRightClick
            }
            IceSection {
                enableAlwaysHiddenSection
                canToggleAlwaysHiddenSection
            }
            IceSection {
                showOnHoverDelaySlider
                tempShowIntervalSlider
            }
            IceSection("Permissions") {
                allPermissions
            }
            MenuBarBehaviorSettings(behaviors: appState.menuBarBehaviors)
        }
    }

    @ViewBuilder
    private var hideApplicationMenus: some View {
        Toggle("Hide application menus when showing menu bar items", isOn: manager.bindings.hideApplicationMenus)
            .annotation("Make more room in the menu bar by hiding the left application menus if needed")
    }

    @ViewBuilder
    private var showSectionDividers: some View {
        Toggle("Show section dividers", isOn: manager.bindings.showSectionDividers)
            .annotation {
                HStack(spacing: 2) {
                    Text("Insert divider items")
                    if let nsImage = ControlItemImage.builtin(.chevronLarge).nsImage(for: appState) {
                        HStack(spacing: 0) {
                            Text("(")
                                .font(.body.monospaced().bold())
                            Image(nsImage: nsImage)
                                .padding(.horizontal, -2)
                            Text(")")
                                .font(.body.monospaced().bold())
                        }
                    }
                    Text("between sections")
                }
            }
    }

    @ViewBuilder
    private var enableAlwaysHiddenSection: some View {
        Toggle("Enable always-hidden section", isOn: manager.bindings.enableAlwaysHiddenSection)
    }

    @ViewBuilder
    private var canToggleAlwaysHiddenSection: some View {
        if manager.enableAlwaysHiddenSection {
            Toggle("Always-hidden section can be shown", isOn: manager.bindings.canToggleAlwaysHiddenSection)
                .annotation {
                    if appState.settingsManager.generalSettingsManager.showOnClick {
                        Text("Option + click one of Ice++'s menu bar items, or inside an empty area of the menu bar to show the section")
                    } else {
                        Text("Option + click one of Ice++'s menu bar items to show the section")
                    }
                }
        }
    }

    @ViewBuilder
    private var showOnHoverDelaySlider: some View {
        IceLabeledContent {
            IceSlider(
                formattedToSeconds(manager.showOnHoverDelay),
                value: manager.bindings.showOnHoverDelay,
                in: 0...1,
                step: 0.1
            )
        } label: {
            Text("Show on hover delay")
                .frame(minHeight: 24)
                .frame(minWidth: maxSliderLabelWidth, alignment: .leading)
                .onFrameChange { frame in
                    maxSliderLabelWidth = max(maxSliderLabelWidth, frame.width)
                }
        }
        .annotation("The amount of time to wait before showing on hover")
    }

    @ViewBuilder
    private var tempShowIntervalSlider: some View {
        IceLabeledContent {
            IceSlider(
                formattedToSeconds(manager.tempShowInterval),
                value: manager.bindings.tempShowInterval,
                in: 0...30,
                step: 1
            )
        } label: {
            Text("Temporarily shown item delay")
                .frame(minHeight: 24)
                .frame(minWidth: maxSliderLabelWidth, alignment: .leading)
                .onFrameChange { frame in
                    maxSliderLabelWidth = max(maxSliderLabelWidth, frame.width)
                }
        }
        .annotation("The amount of time to wait before hiding temporarily shown menu bar items")
    }

    @ViewBuilder
    private var showAllSectionsOnUserDrag: some View {
        Toggle("Show all sections when Command + dragging menu bar items", isOn: manager.bindings.showAllSectionsOnUserDrag)
    }

    @ViewBuilder
    private var showContextMenuOnRightClick: some View {
        Toggle("Show context menu on right click", isOn: manager.bindings.showContextMenuOnRightClick)
    }

    @ViewBuilder
    private var allPermissions: some View {
        ForEach(appState.permissionsManager.allPermissions) { permission in
            IceLabeledContent {
                if permission.hasPermission {
                    Label {
                        Text("Permission Granted")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                } else {
                    Button("Grant Permission") {
                        permission.performRequest()
                    }
                }
            } label: {
                Text(LocalizedStringKey(permission.title))
            }
            .frame(height: 22)
        }
    }
}

private struct MenuBarBehaviorSettings: View {
    @ObservedObject var behaviors: MenuBarBehaviors
    @State private var presetName = ""
    @State private var bindDisplays = true
    @State private var frontmostBundle = ""
    @State private var batteryPercent = 20.0
    @State private var startTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var endTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @State private var draftKind = MenuBarAutomation.Kind.frontmostApp
    @State private var draftAction = MenuBarAutomation.Action.showHidden
    @State private var showHidden = true
    @State private var wifiName = ""
    @State private var latitude = 0.0
    @State private var longitude = 0.0
    @State private var radius = 200.0
    @State private var month = 0
    @State private var day = 0
    @State private var weekdays = ""
    @State private var scriptPath = ""
    @State private var presetID: UUID?

    var body: some View {
        IceSection("System icons") {
            ForEach(SystemMenuExtra.allCases) { item in
                Toggle(LocalizedStringKey(item.title), isOn: Binding(
                    get: { SystemMenuExtraStore.isShown(item) },
                    set: { SystemMenuExtraStore.setShown($0, item) }
                ))
            }
        }
        IceSection("Notch") {
            Toggle("Move icons out from under the notch", isOn: Binding(
                get: { behaviors.relieveNotch },
                set: { behaviors.updateRelieveNotch($0) }
            ))
            Text("Off unless you turn it on. Only a third-party icon whose center is under the notch is moved. The clock and Wi-Fi stay.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        IceSection("Presets") {
            TextField("Preset name", text: $presetName)
            Toggle("Apply when these displays are connected", isOn: $bindDisplays)
            Button("Save current layout") {
                behaviors.saveCurrentLayout(named: presetName, forCurrentDisplays: bindDisplays)
                presetName = ""
            }
            .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            ForEach(behaviors.presets) { preset in
                HStack {
                    Text(preset.name)
                    if preset.displaySignature != nil {
                        Text("This display setup")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Apply") { behaviors.apply(preset) }
                    Button("Delete") { behaviors.delete(preset) }
                }
            }
        }
        IceSection("Automations") {
            Picker("When", selection: $draftKind) {
                ForEach(MenuBarAutomation.Kind.allCases, id: \.self) { kind in
                    Text(kindTitle(kind)).tag(kind)
                }
            }
            Picker("Then", selection: $draftAction) {
                Text("Show or hide the hidden section").tag(MenuBarAutomation.Action.showHidden)
                Text("Apply a preset").tag(MenuBarAutomation.Action.applyPreset)
            }
            if draftKind == .frontmostApp {
                Picker("Frontmost app", selection: $frontmostBundle) {
                    Text("Choose an app").tag("")
                    ForEach(runningApps, id: \.bundleID) { app in
                        Text(app.name).tag(app.bundleID)
                    }
                }
            }
            if draftKind == .batteryBelow {
                Slider(value: $batteryPercent, in: 5...90, step: 5) {
                    Text("Battery")
                }
            }
            if draftKind == .schedule {
                DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            if draftKind == .wifi {
                HStack {
                    Text(wifiName.isEmpty ? String(localized: "Current network") : wifiName)
                    Spacer()
                    Button("Use current network") {
                        wifiName = behaviors.currentNetworkName() ?? ""
                    }
                }
            }
            if draftKind == .location {
                HStack {
                    Text(locationSummary)
                    Spacer()
                    Button("Use current location") {
                        behaviors.useCurrentLocation()
                    }
                }
                .onChange(of: behaviors.capturedPlace) { _, place in
                    guard let place else {
                        return
                    }
                    latitude = place.latitude
                    longitude = place.longitude
                }
                TextField("Radius in meters", value: $radius, format: .number)
            }
            if draftKind == .date {
                TextField("Month (0 = any)", value: $month, format: .number)
                TextField("Day (0 = any)", value: $day, format: .number)
                TextField("Weekdays, Sunday = 1", text: $weekdays)
            }
            if draftKind == .script {
                HStack {
                    Text(scriptPath.isEmpty ? String(localized: "No script chosen") : scriptPath)
                        .lineLimit(1)
                    Spacer()
                    Button("Choose script") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK {
                            scriptPath = panel.url?.path ?? ""
                        }
                    }
                }
            }
            if draftAction == .showHidden {
                Toggle("Show the hidden section", isOn: $showHidden)
            }
            if draftAction == .applyPreset {
                Picker("Preset", selection: $presetID) {
                    Text("None").tag(UUID?.none)
                    ForEach(behaviors.presets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
            }
            Button("Add automation") {
                behaviors.addAutomation(draftRule())
            }
            ForEach(behaviors.automations) { rule in
                HStack {
                    Toggle(rule.enabled ? "On" : "Off", isOn: Binding(
                        get: { rule.enabled },
                        set: { behaviors.setAutomationEnabled(rule, enabled: $0) }
                    ))
                    ruleLabel(rule)
                    Spacer()
                    Button("Delete") { behaviors.deleteAutomation(rule) }
                }
            }
        }
        IceSection("Configuration") {
            Button("Export configuration") { MenuBarConfigurationArchive.exportPanel() }
            Button("Import configuration") { MenuBarConfigurationArchive.importPanel() }
            Button("Restore latest backup") { MenuBarConfigurationArchive.restoreAndRelaunch() }
            Button("Reset configuration") { MenuBarConfigurationArchive.resetAndRelaunch() }
        }
    }

    private func draftRule() -> MenuBarAutomation {
        MenuBarAutomation(
            id: UUID(),
            enabled: true,
            kind: draftKind,
            bundleID: frontmostBundle.trimmingCharacters(in: .whitespaces),
            batteryPercent: Int(batteryPercent),
            startHour: Calendar.current.component(.hour, from: startTime),
            endHour: Calendar.current.component(.hour, from: endTime),
            showHidden: showHidden,
            action: draftAction,
            presetID: presetID,
            wifiName: wifiName.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radius,
            month: month,
            day: day,
            weekdays: weekdays.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) },
            scriptPath: scriptPath.trimmingCharacters(in: .whitespaces),
            startMinute: Calendar.current.component(.minute, from: startTime),
            endMinute: Calendar.current.component(.minute, from: endTime)
        )
    }

    private var runningApps: [(name: String, bundleID: String)] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier, seen.insert(bundleID).inserted else {
                return nil
            }
            return (app.localizedName ?? bundleID, bundleID)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var locationSummary: String {
        if latitude == 0, longitude == 0 {
            return String(localized: "Current location")
        }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }

    private func kindTitle(_ kind: MenuBarAutomation.Kind) -> LocalizedStringKey {
        switch kind {
        case .frontmostApp: "Frontmost app"
        case .batteryBelow: "Battery level"
        case .schedule: "Time of day"
        case .wifi: "Wi-Fi network"
        case .location: "Current location"
        case .date: "Date"
        case .unplugged: "Unplugged"
        case .script: "Script"
        }
    }

    @ViewBuilder
    private func ruleLabel(_ rule: MenuBarAutomation) -> some View {
        switch rule.kind {
        case .frontmostApp:
            Text(rule.bundleID)
        case .batteryBelow:
            Text("Battery ≤ \(rule.batteryPercent)%")
        case .schedule:
            Text(String(format: "%d:%02d–%d:%02d", rule.startHour, rule.startMinute, rule.endHour, rule.endMinute))
        case .wifi:
            Text(rule.wifiName)
        case .location:
            Text("Current location")
        case .date:
            Text("Date")
        case .unplugged:
            Text("On battery")
        case .script:
            Text(rule.scriptPath)
        }
    }
}

#if !ICE_CLI_BUILD
#Preview {
    AdvancedSettingsPane()
        .fixedSize()
        .environmentObject(AppState())
}
#endif
