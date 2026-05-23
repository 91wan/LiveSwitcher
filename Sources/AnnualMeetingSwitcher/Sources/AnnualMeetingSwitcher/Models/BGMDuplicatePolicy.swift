import Foundation

enum BGMDuplicateDecision: Equatable {
    case importable(title: String)
    case duplicateURL
}

enum BGMDuplicatePolicy {
    static func decision(for url: URL, existingItems: [BGMItem]) -> BGMDuplicateDecision {
        let normalizedPath = normalizedFilePath(url)
        if existingItems.contains(where: { normalizedFilePath($0.url) == normalizedPath }) {
            return .duplicateURL
        }
        return .importable(title: url.deletingPathExtension().lastPathComponent)
    }

    private static func normalizedFilePath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
