import Foundation

enum WebNavigationPolicy {
    static func shouldAllowNavigation(url: URL?, allowedRoot: URL?) -> Bool {
        guard let url else { return false }

        if url.scheme == "about" {
            return true
        }

        guard url.isFileURL,
              let allowedRoot else {
            return false
        }

        let rootPath = normalizedDirectoryPath(allowedRoot)
        let targetPath = url.standardizedFileURL.path

        return targetPath == rootPath || targetPath.hasPrefix(rootPath + "/")
    }

    private static func normalizedDirectoryPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
