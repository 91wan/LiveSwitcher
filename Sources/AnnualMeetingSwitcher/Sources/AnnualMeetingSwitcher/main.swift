import AppKit
import SwiftUI

// Entry point: delegates to LiveSwitcherApp
private let liveSwitcherLaunchCoordinator = LiveSwitcherLaunchCoordinator()

NSApplication.shared.setActivationPolicy(.regular)
liveSwitcherLaunchCoordinator.install()
LiveSwitcherApp.main()
