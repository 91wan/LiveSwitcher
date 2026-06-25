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
            return "就绪"
        case .permissionDenied, .unknown:
            return "需检查"
        case .missingApp, .fileBroken:
            return "不可用"
        }
    }

    var operatorMessage: String {
        switch self {
        case .notPresentation:
            return "无需演示就绪检查。"
        case .ready(let appName):
            return "\(appName) 已就绪。"
        case .missingApp(let appName):
            return "未安装 \(appName)。"
        case .permissionDenied(let appName):
            return "\(appName) 自动化权限被拒绝，请在系统设置中允许。"
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
    var presentationDocumentIsValid: (URL, ProgramSourceKind) -> Bool
    var applicationDisplayName: (String) -> String
    var applicationInstalled: (String) -> Bool
    var automationPermission: (String) -> PresentationAutomationPermission
    var usesCache: Bool

    init(_ directProbe: @escaping (ProgramItem) -> PresentationReadinessResult) {
        self.directProbe = directProbe
        self.fileExists = { _ in false }
        self.presentationDocumentIsValid = { _, _ in false }
        self.applicationDisplayName = { $0 }
        self.applicationInstalled = { _ in false }
        self.automationPermission = { _ in .unknown }
        self.usesCache = false
    }

    init(
        fileExists: @escaping (URL) -> Bool,
        presentationDocumentIsValid: @escaping (URL, ProgramSourceKind) -> Bool,
        applicationDisplayName: @escaping (String) -> String,
        applicationInstalled: @escaping (String) -> Bool,
        automationPermission: @escaping (String) -> PresentationAutomationPermission,
        usesCache: Bool
    ) {
        self.directProbe = nil
        self.fileExists = fileExists
        self.presentationDocumentIsValid = presentationDocumentIsValid
        self.applicationDisplayName = applicationDisplayName
        self.applicationInstalled = applicationInstalled
        self.automationPermission = automationPermission
        self.usesCache = usesCache
    }

    static let live = PresentationReadinessEnvironment(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        presentationDocumentIsValid: { url, sourceKind in
            PresentationDocumentValidator.isLikelyValid(url: url, sourceKind: sourceKind)
        },
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
                return .fileBroken("Keynote 文件缺失。")
            }
            guard environment.fileExists(sourceURL) else {
                return .fileBroken("文件缺失。")
            }
            guard environment.presentationDocumentIsValid(sourceURL, .keynote) else {
                return .fileBroken("演示文件缺失或损坏。")
            }
            return appReadiness(bundleID: keynoteBundleIdentifier, environment: environment)

        case .pptx:
            guard let sourceURL = item.sourceURL else {
                return .fileBroken("PPTX 文件缺失。")
            }
            guard environment.fileExists(sourceURL) else {
                return .fileBroken("文件缺失。")
            }
            guard environment.presentationDocumentIsValid(sourceURL, .pptx) else {
                return .fileBroken("演示文件缺失或损坏。")
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
            return .unknown("\(appName) 自动化权限未确认。")
        }
    }

    private static func cacheKey(for item: ProgramItem) -> String {
        [
            item.id.uuidString,
            item.sourceURL?.path ?? "",
            item.sourceKind.displayCacheKey,
            sourceFingerprint(for: item.sourceURL)
        ].joined(separator: "|")
    }

    private static func sourceFingerprint(for url: URL?) -> String {
        guard let url else {
            return "no-source"
        }

        var isDirectoryObject = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryObject) else {
            return "missing"
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? -1
            let isDirectory = isDirectoryObject.boolValue
            let childCount: Int
            if isDirectory {
                childCount = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil
                ).count) ?? -1
            } else {
                childCount = -1
            }
            return "\(isDirectory ? "dir" : "file"):\(fileSize):\(modifiedAt):\(childCount)"
        } catch {
            return "missing"
        }
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
