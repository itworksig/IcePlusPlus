//
//  MenuBarAppearanceSettingsPane.swift
//  Ice
//

import SwiftUI

struct MenuBarAppearanceSettingsPane: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MenuBarAppearanceEditor(location: .settings)
            .environmentObject(appState.appearanceManager)
    }
}

#if !ICE_CLI_BUILD
#Preview {
    MenuBarAppearanceSettingsPane()
        .environmentObject(AppState())
}
#endif
