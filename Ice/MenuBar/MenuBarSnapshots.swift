//
//  MenuBarSnapshots.swift
//  Ice
//

import Cocoa
import Combine

/// Crops the live menu bar into one image per item for the layout page.
@MainActor
final class MenuBarSnapshots: ObservableObject {
    @Published var showItemImages = false
    @Published var showAppBadges = false
    @Published private(set) var byBundle: [String: NSImage] = [:]
    @Published private(set) var byX: [Int: NSImage] = [:]

    private var cancellables = Set<AnyCancellable>()

    func image(for bundleID: String?, frame: CGRect?) -> NSImage? {
        if let bundleID, let image = byBundle[bundleID] {
            return image
        }
        guard let frame else {
            return nil
        }
        return byX[Int(frame.midX.rounded())]
    }

    func performSetup() {
        Defaults.ifPresent(key: .showMenuBarItemImages, assign: &showItemImages)
        Defaults.ifPresent(key: .showAppIconBadges, assign: &showAppBadges)
        loadDisk()
        $showItemImages
            .dropFirst()
            .sink { Defaults.set($0, forKey: .showMenuBarItemImages) }
            .store(in: &cancellables)
        $showAppBadges
            .dropFirst()
            .sink { Defaults.set($0, forKey: .showAppIconBadges) }
            .store(in: &cancellables)
    }

    func recapture() {
        guard
            ScreenCapture.cachedCheckPermissions(),
            let screen = NSScreen.main,
            let window = WindowInfo.getMenuBarWindow(for: screen.displayID),
            let image = ScreenCapture.captureWindow(window.windowID),
            window.frame.width > 1
        else {
            return
        }
        let scale = CGFloat(image.width) / window.frame.width
        let apps = NSWorkspace.shared.runningApplications
        let items = MenuBarItemAXDiscovery.discoverItems(in: apps)
        var bundles: [String: NSImage] = [:]
        var xs: [Int: NSImage] = [:]
        let directory = Self.directory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for item in items {
            guard let frame = item.axFrame, frame.width > 8, frame.width < 280, frame.height > 8, frame.height < 80 else {
                continue
            }
            let crop = CGRect(
                x: (frame.minX - window.frame.minX) * scale,
                y: (frame.minY - window.frame.minY) * scale,
                width: frame.width * scale,
                height: frame.height * scale
            ).integral
            guard crop.width > 2, crop.height > 2, let part = image.cropping(to: crop) else {
                continue
            }
            let nsImage = NSImage(cgImage: part, size: NSSize(width: frame.width, height: frame.height))
            if let bundleID = item.bundleID {
                bundles[bundleID] = nsImage
                write(nsImage, name: "bundle-\(bundleID)", directory: directory)
            }
            let key = Int(frame.midX.rounded())
            xs[key] = nsImage
            write(nsImage, name: "x-\(key)", directory: directory)
        }
        byBundle = bundles
        byX = xs
    }
}

extension MenuBarSnapshots: BindingExposable {}

private extension MenuBarSnapshots {
    func loadDisk() {
        let directory = Self.directory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        var bundles: [String: NSImage] = [:]
        var xs: [Int: NSImage] = [:]
        for file in files {
            guard let image = NSImage(contentsOf: file) else {
                continue
            }
            let name = file.deletingPathExtension().lastPathComponent
            if name.hasPrefix("bundle-") {
                bundles[String(name.dropFirst("bundle-".count))] = image
            } else if name.hasPrefix("x-"), let x = Int(name.dropFirst(2)) {
                xs[x] = image
            }
        }
        byBundle = bundles
        byX = xs
    }

    func write(_ image: NSImage, name: String, directory: URL) {
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            return
        }
        let safe = name.replacingOccurrences(of: "/", with: "-")
        try? png.write(to: directory.appendingPathComponent(safe).appendingPathExtension("png"))
    }

    static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Ice/ItemImages", isDirectory: true)
    }
}
