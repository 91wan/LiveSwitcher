import AppKit
import Foundation

struct WPSApplicationSnapshot: Equatable {
    var bundleIdentifier: String?
    var activationPolicy: NSApplication.ActivationPolicy
    var processIdentifier: pid_t
}

final class WPSApplicationMonitor {
    private static let wpsBundleIdentifier = "com.kingsoft.wpsoffice.mac"

    private let lock = NSLock()
    private var cachedProcessIdentifier: pid_t?
    private var notificationTokens: [NSObjectProtocol] = []

    init(
        workspace: NSWorkspace = .shared,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        refresh(using: workspace.runningApplications)

        let launchToken = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self, weak workspace] _ in
            self?.refresh(using: workspace?.runningApplications ?? [])
        }

        let terminateToken = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self, weak workspace] _ in
            self?.refresh(using: workspace?.runningApplications ?? [])
        }

        notificationTokens = [launchToken, terminateToken]
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        notificationTokens.forEach(center.removeObserver)
    }

    var currentProcessIdentifier: pid_t? {
        lock.lock()
        defer { lock.unlock() }
        return cachedProcessIdentifier
    }

    static func preferredPID(from snapshots: [WPSApplicationSnapshot]) -> pid_t? {
        let wpsApps = snapshots.filter { $0.bundleIdentifier == wpsBundleIdentifier }
        return wpsApps.first(where: { $0.activationPolicy == .regular })?.processIdentifier
            ?? wpsApps.first?.processIdentifier
    }

    private func refresh(using applications: [NSRunningApplication]) {
        let snapshots = applications.map {
            WPSApplicationSnapshot(
                bundleIdentifier: $0.bundleIdentifier,
                activationPolicy: $0.activationPolicy,
                processIdentifier: $0.processIdentifier
            )
        }
        let pid = Self.preferredPID(from: snapshots)
        lock.lock()
        cachedProcessIdentifier = pid
        lock.unlock()
    }
}
