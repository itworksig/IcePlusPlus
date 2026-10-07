//
//  AppLanguage.swift
//  Ice
//

import AppKit

/// The language Ice presents its interface in.
///
/// Stored in the app's `AppleLanguages` override, which macOS reads once at
/// launch. Changing it takes effect the next time Ice starts.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// The override currently stored for this app.
    static var resolved: AppLanguage {
        guard let first = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first else {
            return .system
        }
        if first.hasPrefix("zh-Hans") || first == "zh-CN" {
            return .simplifiedChinese
        }
        if first.hasPrefix("en") {
            return .english
        }
        return .system
    }

    /// Writes the override. Pass ``system`` to follow the macOS language again.
    func apply() {
        switch self {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .english, .simplifiedChinese:
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
        // The process is about to quit. Flush now so the new instance reads
        // the override instead of the previous language.
        UserDefaults.standard.synchronize()
    }

    /// Quits Ice and opens it again so the new language is loaded.
    ///
    /// The running instance stays up when the new one cannot be opened.
    @MainActor
    static func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error {
                Logger(category: "AppLanguage").error("Could not relaunch Ice: \(error.localizedDescription)")
                return
            }
            guard app != nil else {
                return
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
