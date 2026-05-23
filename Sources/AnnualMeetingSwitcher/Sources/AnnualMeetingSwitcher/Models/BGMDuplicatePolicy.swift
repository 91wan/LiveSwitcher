import Foundation

enum BGMImportDecision: Equatable {
    case importable(title: String)
    case duplicateURL
}

enum BGMDuplicatePolicy {
    static func decision(for url: URL, existingItems: [BGMItem]) -> BGMImportDecision {
        let standardizedURL = url.standardizedFileURL
        if existingItems.contains(where: { $0.url.standardizedFileURL == standardizedURL }) {
            return .duplicateURL
        }

        return .importable(title: url.deletingPathExtension().lastPathComponent)
    }
}
