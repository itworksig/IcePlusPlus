//
//  IceAppIntents.swift
//  Ice
//

import AppIntents

struct ToggleFocusModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Focus Mode"
    static var description = IntentDescription("Hides or restores the whole menu bar.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IceCommands.toggleFocus()
        return .result()
    }
}

struct ShowHiddenSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Hidden Menu Bar Items"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IceCommands.showHidden()
        return .result()
    }
}

struct HideHiddenSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Hide Hidden Menu Bar Items"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IceCommands.hideHidden()
        return .result()
    }
}

struct ShowIceBarIntent: AppIntent {
    static var title: LocalizedStringResource = "Show the Ice Bar"
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await IceCommands.showIceBarAtMouse()
        return .result()
    }
}

struct ApplyIcePresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply an Ice++ Preset"
    static var openAppWhenRun = false

    @Parameter(title: "Preset name")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult {
        IceCommands.applyPreset(named: name)
        return .result()
    }
}

struct IceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleFocusModeIntent(),
            phrases: [
                "Toggle focus mode in \(.applicationName)",
                "Hide the menu bar with \(.applicationName)"
            ],
            shortTitle: "Focus Mode",
            systemImageName: "rectangle.topthird.inset.filled"
        )
        AppShortcut(
            intent: ShowIceBarIntent(),
            phrases: [
                "Show the Ice Bar with \(.applicationName)"
            ],
            shortTitle: "Ice Bar",
            systemImageName: "menubar.rectangle"
        )
    }
}
