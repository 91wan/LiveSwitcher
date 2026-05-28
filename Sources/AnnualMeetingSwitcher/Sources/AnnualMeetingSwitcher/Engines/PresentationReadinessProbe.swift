import AppKit
import ApplicationServices
import Foundation

enum PresentationReadinessSeverity: Equatable {
    case notApplicable
    case ready
    case warning
    case blocked
}

enum PresentationAutomationPermission: Equatable {
    case allowed
    case denied
    case unknown
}

enum PresentationReadinessResult: Equatable {
    case notPresentation
    case ready(String)
    case missingApp(String)
    case permissionDenied(String)
    case fileBroken(String)
    case unknown(String)

    var severity: PresentationReadinessSeverity {
        switch self {
        case .notPresentation:
            return .notApplicable
        case .ready:
            return .ready
        case .permissionDenied, .unknown:
            return .warning
        case .missingApp, .fileBroken:
            return .blocked
        }
    }

    var dotLabel: String? {
        switch self {
        case .notPresentation:
            return nil
        case .ready:
            return "Ready"
        case .permissionDenied, .unknown:
            return "Review"
        case .missingApp, .fileBroken:
            return "Blocked"
        }
    }

    var operatorMessage: String {
        switch self {
        case .notPresentation:
            return "No presentation readiness check required."
        case .ready(let appName):
            return "\(appName) is ready for this presentation."
        case .missingApp(let appName):
            return "\(appName) is not installed."
        case .permissionDenied(let appName):
            return "Automation permission for \(appName) needs review in System Settings."
        case .fileBroken(let reason):
            return reason
        case .unknown(let reason):
            return reason
        }
    }
}

struct PresentationReadinessEnvironment {
    var directProbe: ((ProgramItem) -> PresentationReadinessResult)?
    var fileExists: (URL) -> Bool
    var applicationDisplayName: (String) -> String
    var applicationInstalled: (String) -> Bool
    var automationPermission: (String) -> PresentationAutomationPermission
    var usesCache: Bool

    init(_ directProbe: @escaping (ProgramItem) -> PresentationReadinessResult) {
        self.directProbe = directProbe
        self.fileExists = { _ in false }
        self.applicationDisplayName = { $0 }
        self.applicationInstalled = { _ in false }
        self.automationPermission = { _ in .unknown }
        self.usesCache = false
    }

    init(
        fileExists: @escaping (URL) -> Bool,
        applicationDisplayName: @escaping (String) -> String,
        applicationInstalled: @escaping (String) -> Bool,
        automationPermission: @escaping (String) -> PresentationAutomationPermission,
        usesCache: Bool
    ) {
        self.directProbe = nil
        self.fileExists = fileExists
        self.applicationDisplayName = applicationDisplayName
        self.applicationInstalled = applicationInstalled
        self.automationPermission = automationPermission
        self.usesCache = usesCache
    }

    static let live = PresentationReadinessEnvironment(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        applicationDisplayName: { bundleID in
            bundleID == PresentationReadinessProbe.wpsBundleIdentifier ? "WPS Office" : "Keynote"
        },
        applicationInstalled: { bundleID in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        },
        automationPermission: { bundleID in
            PresentationReadinessProbe.liveAutomationPermission(forBundleIdentifier: bundleID)
        },
        usesCache: true
    )
}

struct PresentationReadinessSummary: Equatable {
    let readyCount: Int
    let warningCount: Int
    let blockedCount: Int

    var hasPresentationItems: Bool {
        readyCount + warningCount + blockedCount > 0
    }

    var displayText: String {
        "\(readyCount) ready · \(warningCount) warn · \(blockedCount) blocked"
    }

    var statusKind: StudioTheme.StatusKind {
        if blockedCount > 0 {
            return .fail
        }
        if warningCount > 0 {
            return .warn
        }
        if readyCount > 0 {
            return .ready
        }
        return .idle
    }

    static func make(
        items: [ProgramItem],
        environment: PresentationReadinessEnvironment = .live
    ) -> PresentationReadinessSummary {
        var readyCount = 0
        var warningCount = 0
        var blockedCount = 0

        for item in items {
            switch PresentationReadinessProbe.probe(item: item, environment: environment).severity {
            case .ready:
                readyCount += 1
            case .warning:
                warningCount += 1
            case .blocked:
                blockedCount += 1
            case .notApplicable:
                continue
            }
        }

        return PresentationReadinessSummary(
            readyCount: readyCount,
            warningCount: warningCount,
            blockedCount: blockedCount
        )
    }
}

enum PresentationReadinessProbe {
    static let keynoteBundleIdentifier = "com.apple.iWork.Keynote"
    static let wpsBundleIdentifier = AppConfiguration.wpsBundleIdentifier

    static func probe(
        item: ProgramItem,
        environment: PresentationReadinessEnvironment = .live
    ) -> PresentationReadinessResult {
        if let directProbe = environment.directProbe {
            return directProbe(item)
        }

        let key = cacheKey(for: item)
        if environment.usesCache,
           let cached = PresentationReadinessCache.shared.result(for: key) {
            return cached
        }

        let result = uncachedProbe(item: item, environment: environment)
        if environment.usesCache {
            PresentationReadinessCache.shared.store(result, for: key)
        }
        return result
    }

    static func liveAutomationPermission(forBundleIdentifier bundleIdentifier: String) -> PresentationAutomationPermission {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        let status = AEDeterminePermissionToAutomateTarget(
            descriptor.aeDesc,
            typeWildCard,
            typeWildCard,
            false
        )

        switch status {
        case noErr:
            return .allowed
        case OSStatus(errAEEventNotPermitted), OSStatus(errAEEventWouldRequireUserConsent):
            return .denied
        default:
            return .unknown
        }
    }

    private static func uncachedProbe(
        item: ProgramItem,
        environment: PresentationReadinessEnvironment
    ) -> PresentationReadinessResult {
        switch item.sourceKind {
        case .keynote:
            guard let sourceURL = item.sourceURL else {
                return .fileBroken("Keynote file missing")
            }
            guard environment.fileExists(sourceURL) else {
                return .fileBroken("File missing")
            }
            return appReadiness(bundleID: keynoteBundleIdentifier, environment: environment)

        case .pptx:
            guard let sourceURL = item.sourceURL else {
                return .fileBroken("PPTX file missing")
            }
            guard environment.fileExists(sourceURL) else {
                return .fileBroken("File missing")
            }
            if environment.applicationInstalled(wpsBundleIdentifier) {
                return appReadiness(bundleID: wpsBundleIdentifier, environment: environment)
            }
            if environment.applicationInstalled(keynoteBundleIdentifier) {
                return appReadiness(bundleID: keynoteBundleIdentifier, environment: environment)
            }
            return .missingApp("WPS Office / Keynote")

        case .activeDeck:
            return appReadiness(bundleID: keynoteBundleIdentifier, environment: environment)

        case .media, .html, .agendaMarker, .unsupported:
            return .notPresentation
        }
    }

    private static func appReadiness(
        bundleID: String,
        environment: PresentationReadinessEnvironment
    ) -> PresentationReadinessResult {
        let appName = environment.applicationDisplayName(bundleID)
        guard environment.applicationInstalled(bundleID) else {
            return .missingApp(appName)
        }

        switch environment.automationPermission(bundleID) {
        case .allowed:
            return .ready(appName)
        case .denied:
            return .permissionDenied(appName)
        case .unknown:
            return .unknown("\(appName) automation permission is not confirmed.")
        }
    }

    private static func cacheKey(for item: ProgramItem) -> String {
        [
            item.id.uuidString,
            item.sourceURL?.path ?? "",
            item.sourceKind.displayCacheKey
        ].joined(separator: "|")
    }
}

private final class PresentationReadinessCache {
    static let shared = PresentationReadinessCache()

    private let lock = NSLock()
    private let ttl: TimeInterval = 5
    private var storage: [String: (date: Date, result: PresentationReadinessResult)] = [:]

    func result(for key: String) -> PresentationReadinessResult? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached = storage[key] else {
            return nil
        }
        if Date().timeIntervalSince(cached.date) <= ttl {
            return cached.result
        }
        storage.removeValue(forKey: key)
        return nil
    }

    func store(_ result: PresentationReadinessResult, for key: String) {
        lock.lock()
        storage[key] = (Date(), result)
        lock.unlock()
    }
}

private extension ProgramSourceKind {
    var displayCacheKey: String {
        switch self {
        case .media:
            return "media"
        case .html:
            return "html"
        case .keynote:
            return "keynote"
        case .pptx:
            return "pptx"
        case .activeDeck:
            return "activeDeck"
        case .agendaMarker:
            return "agendaMarker"
        case .unsupported:
            return "unsupported"
        }
    }
}
