import Foundation

enum WallpaperDropPersistence {
    static func persistDroppedWallpaperFile(
        from sourceURL: URL,
        applicationSupportDirectory: URL? = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let applicationSupportDirectory else { return nil }

        let directoryURL = applicationSupportDirectory
            .appendingPathComponent("LiveSwitcher", isDirectory: true)
            .appendingPathComponent("Wallpapers", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fallbackExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let destinationURL = directoryURL
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fallbackExtension)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)

            guard WallpaperImagePolicy.isRenderableImage(url: destinationURL) else {
                try? fileManager.removeItem(at: destinationURL)
                return nil
            }
            return destinationURL
        } catch {
            return nil
        }
    }
}
