import AppKit
import Foundation
import UniformTypeIdentifiers

enum WallpaperImagePolicy {
    static func isSupported(url: URL) -> Bool {
        isSupported(
            url: url,
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            contentType: { url in
                try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
            }
        )
    }

    static func isSupported(
        url: URL,
        fileExists: (URL) -> Bool,
        contentType: (URL) -> UTType?
    ) -> Bool {
        guard url.isFileURL, fileExists(url) else { return false }
        if let type = contentType(url), type.conforms(to: .image) {
            return true
        }
        guard let extensionType = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return false
        }
        return extensionType.conforms(to: .image)
    }

    static func isRenderableImage(url: URL) -> Bool {
        guard isSupported(url: url),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data)
        else { return false }
        return image.size.width > 0 && image.size.height > 0
    }
}
