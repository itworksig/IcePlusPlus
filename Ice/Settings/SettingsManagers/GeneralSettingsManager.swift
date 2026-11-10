//
//  GeneralSettingsManager.swift
//  Ice
//

import Combine
import Foundation

@MainActor
final class GeneralSettingsManager: ObservableObject {
    /// A Boolean value that indicates whether the Ice icon
    /// should be shown.
    @Published var showIceIcon = true

    /// An icon to show in the menu bar, with a different image
    /// for when items are visible or hidden.
    @Published var iceIcon: ControlItemImageSet = .defaultIceIcon

    /// A Boolean value that indicates whether the Ice icon's
    /// hidden and visible images should be swapped, so the
    /// arrow points the opposite way when hidden.
    @Published var reverseIceIcon = false

    /// The last user-selected custom Ice icon.
    @Published var lastCustomIceIcon: ControlItemImageSet?

    /// A Boolean value that indicates whether custom Ice icons
    /// should be rendered as template images.
    @Published var customIceIconIsTemplate = false

    /// A Boolean value that indicates whether to show hidden items
    /// in a separate bar below the menu bar.
    @Published var useIceBar = false

    /// The location where the Ice Bar appears.
    @Published var iceBarLocation: IceBarLocation = .dynamic

    /// Corner radius of the Ice Bar, independent of the menu bar shape.
    @Published var iceBarCornerRadius: Double = 14

    /// Whether the Ice Bar tints its glass.
    @Published var iceBarTintEnabled = false

    /// Ice Bar tint as RRGGBB.
    @Published var iceBarTintHex = "FFFFFF"

    /// Whether a second color fades across the Ice Bar.
    @Published var iceBarGradientEnabled = false

    /// End color of the Ice Bar gradient, as RRGGBB.
    @Published var iceBarGradientEndHex = "8E8E93"

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer clicks in an empty
    /// area of the menu bar.
    @Published var showOnClick = true

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer hovers over an
    /// empty area of the menu bar.
    @Published var showOnHover = false

    /// A Boolean value that indicates whether the hidden section
    /// should be shown or hidden when the user scrolls in the
    /// menu bar.
    @Published var showOnScroll = true

    /// While the hidden section is open, conceal apps that normally stay visible.
    @Published var hideShownWhenRevealing = false

    /// The offset to apply to the menu bar item spacing and padding.
    @Published var itemSpacingOffset: Double = 0

    /// A Boolean value that indicates whether the hidden section
    /// should automatically rehide.
    @Published var autoRehide = true

    /// A strategy that determines how the auto-rehide feature works.
    @Published var rehideStrategy: RehideStrategy = .smart

    /// A time interval for the auto-rehide feature when its rule
    /// is ``RehideStrategy/timed``.
    @Published var rehideInterval: TimeInterval = 15

    /// Encoder for properties.
    private let encoder = JSONEncoder()

    /// Decoder for properties.
    private let decoder = JSONDecoder()

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        loadInitialState()
        configureCancellables()
        // The $itemSpacingOffset sink only fires on change, and loading runs
        // before it subscribes — sync once so spacingManager never starts at
        // a stale 0 while a stored offset exists.
        appState?.spacingManager.offset = Int(itemSpacingOffset)
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .showIceIcon, assign: &showIceIcon)
        Defaults.ifPresent(key: .reverseIceIcon, assign: &reverseIceIcon)
        Defaults.ifPresent(key: .customIceIconIsTemplate, assign: &customIceIconIsTemplate)
        Defaults.ifPresent(key: .useIceBar, assign: &useIceBar)
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showOnScroll, assign: &showOnScroll)
        Defaults.ifPresent(key: .hideShownWhenRevealing, assign: &hideShownWhenRevealing)
        Defaults.ifPresent(key: .itemSpacingOffset, assign: &itemSpacingOffset)
        Defaults.ifPresent(key: .autoRehide, assign: &autoRehide)
        Defaults.ifPresent(key: .rehideInterval, assign: &rehideInterval)

        Defaults.ifPresent(key: .iceBarLocation) { rawValue in
            if let location = IceBarLocation(rawValue: rawValue) {
                iceBarLocation = location
            }
        }
        Defaults.ifPresent(key: .iceBarCornerRadius, assign: &iceBarCornerRadius)
        Defaults.ifPresent(key: .iceBarTintEnabled, assign: &iceBarTintEnabled)
        Defaults.ifPresent(key: .iceBarTintHex, assign: &iceBarTintHex)
        Defaults.ifPresent(key: .iceBarGradientEnabled, assign: &iceBarGradientEnabled)
        Defaults.ifPresent(key: .iceBarGradientEndHex, assign: &iceBarGradientEndHex)
        Defaults.ifPresent(key: .rehideStrategy) { rawValue in
            if let strategy = RehideStrategy(rawValue: rawValue) {
                rehideStrategy = strategy
            }
        }

        if let data = Defaults.data(forKey: .iceIcon) {
            do {
                iceIcon = try decoder.decode(ControlItemImageSet.self, from: data)
            } catch {
                Logger.generalSettingsManager.error("Error decoding Ice icon: \(error)")
            }
            if case .custom = iceIcon.name {
                lastCustomIceIcon = iceIcon
            }
        }
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showIceIcon
            .receive(on: DispatchQueue.main)
            .sink { showIceIcon in
                Defaults.set(showIceIcon, forKey: .showIceIcon)
            }
            .store(in: &c)

        $iceIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] iceIcon in
                guard let self else {
                    return
                }
                if case .custom = iceIcon.name {
                    lastCustomIceIcon = iceIcon
                }
                do {
                    let data = try encoder.encode(iceIcon)
                    Defaults.set(data, forKey: .iceIcon)
                } catch {
                    Logger.generalSettingsManager.error("Error encoding Ice icon: \(error)")
                }
            }
            .store(in: &c)

        $customIceIconIsTemplate
            .receive(on: DispatchQueue.main)
            .sink { isTemplate in
                Defaults.set(isTemplate, forKey: .customIceIconIsTemplate)
            }
            .store(in: &c)

        $reverseIceIcon
            .receive(on: DispatchQueue.main)
            .sink { reverseIceIcon in
                Defaults.set(reverseIceIcon, forKey: .reverseIceIcon)
            }
            .store(in: &c)

        $useIceBar
            .receive(on: DispatchQueue.main)
            .sink { useIceBar in
                Defaults.set(useIceBar, forKey: .useIceBar)
            }
            .store(in: &c)

        $iceBarLocation
            .receive(on: DispatchQueue.main)
            .sink { location in
                Defaults.set(location.rawValue, forKey: .iceBarLocation)
            }
            .store(in: &c)

        $iceBarCornerRadius
            .sink { Defaults.set($0, forKey: .iceBarCornerRadius) }
            .store(in: &c)
        $iceBarTintEnabled
            .sink { Defaults.set($0, forKey: .iceBarTintEnabled) }
            .store(in: &c)
        $iceBarTintHex
            .sink { Defaults.set($0, forKey: .iceBarTintHex) }
            .store(in: &c)
        $iceBarGradientEnabled
            .sink { Defaults.set($0, forKey: .iceBarGradientEnabled) }
            .store(in: &c)
        $iceBarGradientEndHex
            .sink { Defaults.set($0, forKey: .iceBarGradientEndHex) }
            .store(in: &c)

        $showOnClick
            .receive(on: DispatchQueue.main)
            .sink { showOnClick in
                Defaults.set(showOnClick, forKey: .showOnClick)
            }
            .store(in: &c)

        $showOnHover
            .receive(on: DispatchQueue.main)
            .sink { showOnHover in
                Defaults.set(showOnHover, forKey: .showOnHover)
            }
            .store(in: &c)

        $showOnScroll
            .receive(on: DispatchQueue.main)
            .sink { showOnScroll in
                Defaults.set(showOnScroll, forKey: .showOnScroll)
            }
            .store(in: &c)

        $hideShownWhenRevealing
            .sink { enabled in
                Defaults.set(enabled, forKey: .hideShownWhenRevealing)
                IceCommands.refreshReveal()
            }
            .store(in: &c)

        $itemSpacingOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] offset in
                Defaults.set(offset, forKey: .itemSpacingOffset)
                appState?.spacingManager.offset = Int(offset)
            }
            .store(in: &c)

        $autoRehide
            .receive(on: DispatchQueue.main)
            .sink { autoRehide in
                Defaults.set(autoRehide, forKey: .autoRehide)
            }
            .store(in: &c)

        $rehideStrategy
            .receive(on: DispatchQueue.main)
            .sink { strategy in
                Defaults.set(strategy.rawValue, forKey: .rehideStrategy)
            }
            .store(in: &c)

        $rehideInterval
            .receive(on: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .rehideInterval)
            }
            .store(in: &c)

        cancellables = c
    }
}

// MARK: GeneralSettingsManager: BindingExposable
extension GeneralSettingsManager: BindingExposable { }

// MARK: - Logger
private extension Logger {
    static let generalSettingsManager = Logger(category: "GeneralSettingsManager")
}
