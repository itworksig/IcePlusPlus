//
//  NotificationCenterAccess27.swift
//  Ice
//

import Cocoa

/// Notification Center observes MenuBarAgent's visibility restrictions, including
/// our assessment assertion. Merely allowing the clock does not allow its panel.
/// Release our assertion for the interaction, then restore the latest layout.
@MainActor
final class NotificationCenterAccess27 {
    private var interaction: Task<Void, Never>?

    func handleClick(at point: CGPoint, concealer: MenuBarConcealer27) {
        guard interaction == nil,
              clock(at: point) != nil,
              concealer.suspendForNotificationCenter() else {
            return
        }
        interaction = Task { [weak self, weak concealer] in
            defer {
                concealer?.resumeAfterNotificationCenter()
                self?.interaction = nil
            }
            // Invalidation travels over XPC. The original click can arrive before
            // Notification Center observes it. Retry the native action only if
            // that click did not already open the panel (otherwise we'd close it).
            await concealer?.waitForPendingChanges()
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if !Self.isPanelOpen(), let clock = self?.clock(at: point) {
                // Releasing the assertion rebuilds MenuBarAgent's remote views.
                // The element from mouse-down can already be invalid here.
                let result = AXUIElementPerformAction(clock, kAXPressAction as CFString)
                Logger(category: "NotificationCenterAccess27").info("Clock action result: \(result.rawValue)")
            }
            var sawPanel = false
            var absentSamples = 0
            let openingDeadline = Date().addingTimeInterval(3)
            while !Task.isCancelled {
                let open = Self.isPanelOpen()
                if open {
                    sawPanel = true
                    absentSamples = 0
                } else if sawPanel {
                    absentSamples += 1
                    // Debounce AX updates while notifications/widgets refresh.
                    if absentSamples >= 3 { break }
                } else if Date() >= openingDeadline {
                    break
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func stop() {
        interaction?.cancel()
        interaction = nil
    }

    private func clock(at point: CGPoint) -> AXUIElement? {
        // Avoid accessibility IPC for ordinary clicks elsewhere on the desktop.
        guard NSScreen.screens.contains(where: {
            let bounds = CGDisplayBounds($0.displayID)
            return point.y >= bounds.minY && point.y < bounds.minY + 44
                && point.x >= bounds.minX && point.x <= bounds.maxX
        }) else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var hit: AXUIElement?
        AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit)
        var current = hit
        for _ in 0..<6 {
            guard let element = current else { break }
            if Self.attribute(element, kAXIdentifierAttribute) as? String == "com.apple.menuextra.clock" {
                return element
            }
            current = Self.element(Self.attribute(element, kAXParentAttribute))
        }
        // On macOS 27 a hit can resolve to the hosting menu bar rather than
        // its remote clock child. Search only the system hosts in that case.
        for bundleID in ["com.apple.MenuBarAgent", "com.apple.controlcenter"] {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
                let root = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(root, 0.1)
                let windows = Self.attribute(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
                var remaining = 200
                for window in windows {
                    if let clock = Self.findClock(window, at: point, depth: 6, remaining: &remaining) {
                        return clock
                    }
                }
            }
        }
        return nil
    }

    private static func findClock(_ root: AXUIElement, at point: CGPoint, depth: Int, remaining: inout Int) -> AXUIElement? {
        guard depth > 0, remaining > 0 else { return nil }
        remaining -= 1
        if attribute(root, kAXIdentifierAttribute) as? String == "com.apple.menuextra.clock",
           let position = attribute(root, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
           let size = attribute(root, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() {
            var origin = CGPoint.zero
            var extent = CGSize.zero
            // swiftlint:disable force_cast
            if AXValueGetValue(position as! AXValue, .cgPoint, &origin),
               AXValueGetValue(size as! AXValue, .cgSize, &extent),
               CGRect(origin: origin, size: extent).contains(point) {
                return root
            }
            // swiftlint:enable force_cast
        }
        let children = attribute(root, kAXChildrenAttribute) as? [AXUIElement] ?? []
        for child in children {
            if let clock = findClock(child, at: point, depth: depth - 1, remaining: &remaining) { return clock }
        }
        return nil
    }

    /// Desktop widgets and notification banners also belong to NotificationCenter.
    /// Only the panel contains the widget editor; window ownership/title alone
    /// would keep the assertion suspended forever on a desktop with widgets.
    private static func isPanelOpen() -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.notificationcenterui"
        ).first else { return false }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.1)
        let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] ?? []
        var remaining = 250
        return windows.contains { containsPanel($0, depth: 6, remaining: &remaining) }
    }

    private static func containsPanel(_ root: AXUIElement, depth: Int, remaining: inout Int) -> Bool {
        guard depth > 0, remaining > 0 else { return false }
        remaining -= 1
        if attribute(root, kAXIdentifierAttribute) as? String == "widget-editor-button" {
            return true
        }
        let children = attribute(root, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.contains { containsPanel($0, depth: depth - 1, remaining: &remaining) }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement)
    }
}
