// Compile with the production MenuBarConcealer27.swift. These doubles isolate
// its asynchronous assertion lifecycle from MenuBarAgent and saved preferences.
import Cocoa

@MainActor final class MenuBarAssessmentBackend {
    static let isAvailable = true
    static var activations = 0
    static var invalidations = 0
    static var delayNextActivation = false
    static var pending: CheckedContinuation<Void, Never>?

    func activate(allowedBundleIDs: [String]) async throws -> AnyObject {
        Self.activations += 1
        if Self.delayNextActivation {
            Self.delayNextActivation = false
            await withCheckedContinuation { Self.pending = $0 }
        }
        return NSObject()
    }
    func invalidate(_ assertion: AnyObject) { Self.invalidations += 1 }
}
struct Logger {
    init(category: String) {}
    func info(_ message: String) {}
    func error(_ message: String) {}
}
enum MenuBarItemAXDiscovery {
    enum SectionKind { case visible, hidden, alwaysHidden }
}
enum MenuBarSection {
    enum Name { case visible, hidden, alwaysHidden }
}
@MainActor enum Defaults {
    enum Key { case macOS27Layout }
    static var layout: Any?
    static func object(forKey: Key) -> Any? { layout }
    static func set(_ value: Any?, forKey: Key) { layout = value }
}
@MainActor final class AppState {
    let menuBarManager = Manager()
    final class Manager {
        let hidden = Section()
        let alwaysHidden = Section()
        func section(withName name: MenuBarSection.Name) -> Section? {
            name == .alwaysHidden ? alwaysHidden : hidden
        }
    }
    final class Section {
        let controlItem = Control()
    }
    final class Control {
        enum State { case hideItems, showItems }
        var isAddedToMenuBar = true
        var state = State.hideItems
    }
}

@main struct ConcealmentRegressionTests {
    @MainActor static func main() async {
        let app = AppState()
        let subject = MenuBarConcealer27(appState: app)
        subject.setSection(.hidden, for: "test.hidden")
        await subject.waitForPendingChanges()
        precondition(subject.isConcealed("test.hidden"))
        precondition(MenuBarAssessmentBackend.activations == 1)

        precondition(subject.suspendForNotificationCenter())
        precondition(!subject.suspendForNotificationCenter())
        precondition(MenuBarAssessmentBackend.invalidations == 1)
        subject.setSection(.alwaysHidden, for: "test.new")
        await subject.waitForPendingChanges()
        precondition(MenuBarAssessmentBackend.activations == 1, "A queued update must not restrict Notification Center")
        subject.resumeAfterNotificationCenter()
        await subject.waitForPendingChanges()
        precondition(subject.isConcealed("test.hidden"))
        precondition(subject.isConcealed("test.new"), "Resume must use the latest layout")

        // An activation already in flight must be invalidated when it completes
        // during a notification interaction, rather than becoming the live token.
        MenuBarAssessmentBackend.delayNextActivation = true
        subject.setSection(.hidden, for: "test.inflight")
        while MenuBarAssessmentBackend.pending == nil { await Task.yield() }
        precondition(subject.suspendForNotificationCenter())
        let beforeCompletion = MenuBarAssessmentBackend.invalidations
        MenuBarAssessmentBackend.pending?.resume()
        MenuBarAssessmentBackend.pending = nil
        await subject.waitForPendingChanges()
        precondition(MenuBarAssessmentBackend.invalidations == beforeCompletion + 1)
        precondition(!subject.isConcealed("test.inflight"))

        // Quitting while suspended must not resurrect an assertion when the
        // notification interaction's deferred cleanup eventually runs.
        subject.releaseAll()
        let beforeQuit = MenuBarAssessmentBackend.activations
        subject.resumeAfterNotificationCenter()
        subject.update()
        await subject.waitForPendingChanges()
        precondition(MenuBarAssessmentBackend.activations == beforeQuit)
        print("PASS: suspension, pending updates, latest-layout restoration, in-flight activation, quit")
    }
}
