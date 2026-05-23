import Foundation

enum FileDropSupport {
    static func decodeFileURL(from item: Any?) -> URL? {
        if let url = item as? URL {
            return url.isFileURL ? url : nil
        }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url.isFileURL ? url : nil
        }

        if let string = item as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.isFileURL {
                return url
            }
            guard trimmed.hasPrefix("/") || trimmed.hasPrefix("~") else { return nil }
            let expandedPath = NSString(string: trimmed).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }

        return nil
    }

    static func importableProgramItem(from url: URL) -> ProgramItem? {
        guard url.isFileURL,
              ProgramSourceKind(fileURL: url).isImportableFile else {
            return nil
        }

        return ProgramItem(
            title: url.deletingPathExtension().lastPathComponent,
            subtitle: url.pathExtension.uppercased(),
            sourceURL: url
        )
    }
}
