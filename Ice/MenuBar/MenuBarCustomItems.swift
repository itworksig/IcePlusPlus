//
//  MenuBarCustomItems.swift
//  Ice
//

import Cocoa
import Combine
import SwiftUI

struct MenuBarCustomItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case widget
        case group
        case spacer
    }

    enum Action: String, Codable {
        case none
        case openURL
        case script
    }

    var id: UUID
    var kind: Kind
    var title: String
    /// SF Symbol name, emoji, or spacer label.
    var symbol: String
    var width: Double
    var action: Action
    var actionValue: String
    /// Apps represented by a group. They leave the menu bar while the group exists.
    var memberBundleIDs: [String]
}

@MainActor
final class MenuBarCustomItems: NSObject, ObservableObject {
    @Published private(set) var items: [MenuBarCustomItem] = []

    private weak var appState: AppState?
    private var statusItems: [UUID: NSStatusItem] = [:]
    private let target = StatusItemTarget()

    init(appState: AppState) {
        self.appState = appState
        super.init()
        target.onPress = { [weak self] id, member in
            Task { @MainActor in
                self?.activate(id: id, member: member)
            }
        }
    }

    func performSetup() {
        if let data = Defaults.data(forKey: .menuBarCustomItems),
           let decoded = try? JSONDecoder().decode([MenuBarCustomItem].self, from: data) {
            items = decoded
        }
        install()
    }

    func add(_ item: MenuBarCustomItem) {
        items.append(item)
        persist()
        install()
    }

    func delete(_ item: MenuBarCustomItem) {
        items.removeAll { $0.id == item.id }
        persist()
        install()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            Defaults.set(data, forKey: .menuBarCustomItems)
        }
    }

    private func install() {
        for (id, statusItem) in statusItems where !items.contains(where: { $0.id == id }) {
            NSStatusBar.system.removeStatusItem(statusItem)
            statusItems[id] = nil
        }
        for item in items {
            let statusItem = statusItems[item.id] ?? NSStatusBar.system.statusItem(withLength: length(for: item))
            statusItems[item.id] = statusItem
            statusItem.length = length(for: item)
            guard let button = statusItem.button else {
                continue
            }
            button.identifier = NSUserInterfaceItemIdentifier(item.id.uuidString)
            button.image = nil
            button.title = ""
            button.menu = nil
            button.target = nil
            button.action = nil
            switch item.kind {
            case .spacer:
                button.title = item.symbol
            case .widget:
                if let image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: item.title) {
                    image.size = NSSize(width: 18, height: 18)
                    button.image = image
                } else {
                    button.title = item.symbol.isEmpty ? item.title : item.symbol
                }
                button.target = target
                button.action = #selector(StatusItemTarget.press(_:))
            case .group:
                if let image = NSImage(systemSymbolName: item.symbol.isEmpty ? "square.grid.2x2" : item.symbol, accessibilityDescription: item.title) {
                    image.size = NSSize(width: 18, height: 18)
                    button.image = image
                } else {
                    button.title = item.title
                }
                button.menu = menu(for: item)
            }
        }
        let members = Set(items.filter { $0.kind == .group }.flatMap(\.memberBundleIDs))
        IceCommands.setGroupMembers(members)
    }

    private func length(for item: MenuBarCustomItem) -> CGFloat {
        if item.kind == .spacer {
            return CGFloat(min(max(item.width, 8), 400))
        }
        return NSStatusItem.squareLength
    }

    private func menu(for item: MenuBarCustomItem) -> NSMenu {
        let menu = NSMenu()
        for bundleID in item.memberBundleIDs where !bundleID.isEmpty {
            let name = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName ?? bundleID
            let entry = NSMenuItem(title: name, action: #selector(StatusItemTarget.openMember(_:)), keyEquivalent: "")
            entry.target = target
            entry.representedObject = ["id": item.id.uuidString, "bundle": bundleID]
            menu.addItem(entry)
        }
        return menu
    }

    private func activate(id: String, member: String?) {
        guard let item = items.first(where: { $0.id.uuidString == id }) else {
            return
        }
        if let member {
            guard #available(macOS 27, *) else {
                return
            }
            let generation = appState?.menuBarConcealer.temporarilyShow(member) ?? 0
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                self.appState?.menuBarConcealer.endTemporaryShow(member, generation: generation)
            }
            return
        }
        switch item.action {
        case .none:
            break
        case .openURL:
            if let url = URL(string: item.actionValue) {
                NSWorkspace.shared.open(url)
            }
        case .script:
            let path = item.actionValue
            Task.detached {
                _ = ScriptRunner.run(path)
            }
        }
    }
}

private final class StatusItemTarget: NSObject {
    var onPress: ((String, String?) -> Void)?

    @objc func press(_ sender: NSStatusBarButton) {
        onPress?(sender.identifier?.rawValue ?? "", nil)
    }

    @objc func openMember(_ sender: NSMenuItem) {
        let info = sender.representedObject as? [String: String]
        onPress?(info?["id"] ?? "", info?["bundle"])
    }
}

struct MenuBarCustomItemEditor: View {
    @ObservedObject var model: MenuBarCustomItems
    @State private var title = ""
    @State private var symbol = ""
    @State private var width = 24.0
    @State private var actionValue = ""
    @State private var members = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your items")
                .font(.headline)
            TextField("Title", text: $title)
            TextField("Symbol, emoji, or spacer text", text: $symbol)
            HStack {
                Text("Spacer width")
                Slider(value: $width, in: 8...200, step: 4)
            }
            TextField("URL or script path", text: $actionValue)
            Text("A group is an Ice icon. Choosing an app brings that app back to the menu bar. macOS cannot merge another app's icon into this one.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Add app to group", selection: Binding(
                get: { "" },
                set: { bundleID in
                    guard !bundleID.isEmpty else {
                        return
                    }
                    var ids = members.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if !ids.contains(bundleID) {
                        ids.append(bundleID)
                    }
                    members = ids.joined(separator: ", ")
                }
            )) {
                Text("Choose an app").tag("")
                ForEach(runningApps, id: \.bundleID) { app in
                    Text(app.name).tag(app.bundleID)
                }
            }
            if !members.isEmpty {
                Text(members)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Add widget") { add(.widget) }
                Button("Add group") { add(.group) }
                Button("Add spacer") { add(.spacer) }
            }
            ForEach(model.items) { item in
                HStack {
                    if item.title.isEmpty {
                        Text(customKindTitle(item.kind))
                    } else {
                        Text(item.title)
                    }
                    Spacer()
                    Button("Delete") { model.delete(item) }
                }
            }
        }
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

    private func customKindTitle(_ kind: MenuBarCustomItem.Kind) -> LocalizedStringKey {
        switch kind {
        case .widget: "Widget"
        case .group: "Group"
        case .spacer: "Spacer"
        }
    }

    private func add(_ kind: MenuBarCustomItem.Kind) {
        let action: MenuBarCustomItem.Action = actionValue.hasPrefix("http") || actionValue.hasPrefix("iceplusplus:") ? .openURL : (actionValue.isEmpty ? .none : .script)
        model.add(MenuBarCustomItem(
            id: UUID(),
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines),
            width: width,
            action: kind == .widget ? action : .none,
            actionValue: actionValue.trimmingCharacters(in: .whitespacesAndNewlines),
            memberBundleIDs: members.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        ))
        title = ""
        symbol = ""
        actionValue = ""
        members = ""
    }
}
