//
//  MenuBarAssessmentBackend.swift
//  Ice
//

import Foundation
import ObjectiveC

/// Hides other apps' menu bar items through MenuBarAgent's assessment mode.
///
/// A configuration lists the system items and bundle identifiers that stay on
/// the bar. While the assertion is live, MenuBarAgent removes every other
/// application's items. System items (battery, clock, Wi-Fi, Control Center)
/// are allowlisted by number, so they are never part of the hidden set.
@MainActor
final class MenuBarAssessmentBackend {
    enum Failure: Error, CustomStringConvertible {
        case unavailable
        case rejected(String)
        case timedOut

        var description: String {
            switch self {
            case .unavailable: "MenuBarClientCore is unavailable"
            case .rejected(let reason): "MenuBarAgent rejected the assertion: \(reason)"
            case .timedOut: "MenuBarAgent did not answer within 3 seconds"
            }
        }
    }

    private static let frameworkPath = "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"
    private static let configureSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    private static let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    private static let invalidateSelector = NSSelectorFromString("invalidate")

    /// System status items Ice always leaves on the bar.
    ///
    /// On macOS 27.0 only a handful of these numbers draw anything (battery,
    /// clock, Wi-Fi, Control Center), but later builds accept a wider range.
    /// Allowing 0...63 keeps a newly added system item visible.
    private static let systemItems = (0...63).map { NSNumber(value: $0) } as NSArray

    private static let classes: (configuration: AnyClass, assertion: AnyClass)? = {
        guard
            dlopen(frameworkPath, RTLD_NOW) != nil,
            let configuration = NSClassFromString("MBAssessmentModeConfiguration"),
            let assertion = NSClassFromString("MBAssessmentModeAssertion"),
            configuration.instancesRespond(to: configureSelector),
            assertion.instancesRespond(to: activateSelector),
            assertion.instancesRespond(to: invalidateSelector)
        else {
            return nil
        }
        return (configuration, assertion)
    }()

    static var isAvailable: Bool {
        classes != nil
    }

    func activate(allowedBundleIDs: [String]) async throws -> AnyObject {
        guard
            let classes = Self.classes,
            let configuration = (classes.configuration.alloc() as AnyObject)
                .perform(Self.configureSelector, with: Self.systemItems, with: allowedBundleIDs as NSArray)?
                .takeUnretainedValue(),
            let assertion = (classes.assertion.alloc() as AnyObject)
                .perform(NSSelectorFromString("init"))?
                .takeUnretainedValue()
        else {
            throw Failure.unavailable
        }

        let oneShot = OneShot()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // MenuBarAgent calls this with nil on success, or an NSError.
                // `Any?` matches the measured block signature: a typed NSError
                // parameter crashes when the agent passes a different object.
                let completion: @convention(block) (Any?) -> Void = { error in
                    guard oneShot.claim() else {
                        return
                    }
                    if let error {
                        continuation.resume(throwing: Failure.rejected(String(describing: error)))
                    } else {
                        continuation.resume()
                    }
                }
                _ = assertion.perform(Self.activateSelector, with: configuration, with: completion)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    guard oneShot.claim() else {
                        return
                    }
                    continuation.resume(throwing: Failure.timedOut)
                }
            }
        } catch {
            _ = assertion.perform(Self.invalidateSelector)
            throw error
        }
        return assertion
    }

    func invalidate(_ assertion: AnyObject) {
        _ = assertion.perform(Self.invalidateSelector)
    }
}

/// Lets a completion handler and a timeout share one continuation.
private final class OneShot: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.withLock {
            defer { claimed = true }
            return !claimed
        }
    }
}
