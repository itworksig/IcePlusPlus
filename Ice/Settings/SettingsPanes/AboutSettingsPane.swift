//
//  AboutSettingsPane.swift
//  Ice
//

import SwiftUI

struct AboutSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL

    private var updatesManager: UpdatesManager {
        appState.updatesManager
    }

    private var lastUpdateCheckString: String {
        if let date = updatesManager.lastUpdateCheckDate {
            date.formatted(date: .abbreviated, time: .standard)
        } else {
            String(localized: "Never")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                summary
                updates
                project
            }
            .padding(32)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            if let nsImage = Bundle.main.appIconImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Ice++")
                    .font(.system(size: 28, weight: .semibold))
                Text("Version \(Constants.versionString)")
                    .foregroundStyle(.secondary)
                Text(Constants.copyrightString)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 12)
            Button("Quit Ice++") {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ice++ hides menu bar items and opens them again in the Ice Bar.")
            Text("Releases are built for Apple silicon and published on GitHub as Ice-arm64.dmg and Ice.zip.")
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var updates: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updates")
                .font(.headline)
            Text("Check for Updates compares this copy with the latest GitHub release. Only a higher version is offered.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(
                "Automatically check for updates",
                isOn: updatesManager.bindings.automaticallyChecksForUpdates
            )
            Toggle(
                "Automatically download updates",
                isOn: updatesManager.bindings.automaticallyDownloadsUpdates
            )
            .disabled(!updatesManager.automaticallyChecksForUpdates)
            HStack {
                Button("Check for Updates") {
                    updatesManager.checkForUpdates()
                }
                .disabled(updatesManager.isCheckingForUpdates)
                Spacer()
                Text("Last checked: \(lastUpdateCheckString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let status = updatesManager.updateStatus {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var project: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Project")
                .font(.headline)
            linkButton("GitHub Repository", url: AboutLink.repository)
            linkButton("Latest Release", url: AboutLink.releases)
            linkButton("Report a Bug", url: AboutLink.issues)
        }
    }

    @ViewBuilder
    private func linkButton(_ title: LocalizedStringKey, url: URL?) -> some View {
        Button(title) {
            guard let url else {
                return
            }
            openURL(url)
        }
        .buttonStyle(.link)
        .disabled(url == nil)
    }
}

private enum AboutLink {
    static let repository = URL(string: "https://github.com/itworksig/IcePlusPlus")
    static let releases = URL(string: "https://github.com/itworksig/IcePlusPlus/releases/latest")
    static let issues = URL(string: "https://github.com/itworksig/IcePlusPlus/issues")
}
