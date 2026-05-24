import Foundation

enum HostSystemSummary {
    static var shortVersionString: String {
        shortVersionString(for: ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func shortVersionString(for version: OperatingSystemVersion) -> String {
        if version.patchVersion == 0 {
            return "macOS \(version.majorVersion).\(version.minorVersion)"
        }
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
