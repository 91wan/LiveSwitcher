import Foundation

enum PresentationDocumentValidator {
    static func isLikelyValid(url: URL, sourceKind: ProgramSourceKind, fileManager: FileManager = .default) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .fileSizeKey]
        let values = try? url.resourceValues(forKeys: keys)

        switch sourceKind {
        case .keynote:
            if values?.isDirectory == true || values?.isPackage == true {
                return true
            }
        case .pptx:
            if values?.isDirectory == true || values?.isPackage == true {
                return false
            }
        case .media, .html, .activeDeck, .agendaMarker, .unsupported:
            return false
        }

        if let fileSize = values?.fileSize {
            return fileSize > 0
        }

        return false
    }
}
