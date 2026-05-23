import SwiftUI
import UniformTypeIdentifiers

enum WallpaperDropSupport {
    static func decodeFileURL(from item: Any?) -> URL? {
        FileDropSupport.decodeFileURL(from: item)
    }
}

enum WallpaperImportService {
    @MainActor
    static func presentPicker(viewModel: SwitcherViewModel) {
        let panel = NSOpenPanel()
        panel.title = "选择壁纸图片"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif]
        guard panel.runModal() == .OK else { return }
        var firstAcceptedURL: URL?
        for url in panel.urls {
            if viewModel.addWallpaper(url: url), firstAcceptedURL == nil {
                firstAcceptedURL = url
            }
        }
        if let firstAcceptedURL {
            viewModel.setActiveWallpaper(url: firstAcceptedURL)
        }
    }
}

struct WallpaperGalleryRow: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isDroppingWallpaper = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14))
                    .foregroundStyle(StudioTheme.textSecondary)
                Text("待机图库")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Button("导入...") {
                    WallpaperImportService.presentPicker(viewModel: viewModel)
                }
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundStyle(StudioTheme.Action.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.backgroundWallpapers, id: \.self) { url in
                        WallpaperThumbView(url: url, isActive: viewModel.activeWallpaperURL == url)
                            .onTapGesture {
                                viewModel.setActiveWallpaper(url: url)
                            }
                            .contextMenu {
                                Button("删除") {
                                    viewModel.removeWallpaper(url: url)
                                }
                            }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .foregroundStyle(isDroppingWallpaper ? StudioTheme.Action.primary : StudioTheme.borderSubtle)
                            .background(
                                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                                    .fill(isDroppingWallpaper ? StudioTheme.Action.primary.opacity(0.05) : StudioTheme.Surface.raised)
                            )

                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(StudioTheme.textSecondary)
                            Text("拖入图片")
                                .font(.system(size: 10))
                                .foregroundStyle(StudioTheme.textSecondary)
                        }
                    }
                    .frame(width: 80, height: 60)
                    .onDrop(of: [.fileURL, .image], isTargeted: $isDroppingWallpaper) { providers in
                        handleWallpaperDrop(providers: providers)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func handleWallpaperDrop(providers: [NSItemProvider]) -> Bool {
        var didRequestImport = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didRequestImport = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = WallpaperDropSupport.decodeFileURL(from: item) else { return }
                    importWallpaperOnMain(url)
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                didRequestImport = true
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    guard let url,
                          let persistedURL = persistDroppedWallpaperFile(from: url) else { return }
                    importWallpaperOnMain(persistedURL)
                }
            }
        }

        return didRequestImport
    }

    private func persistDroppedWallpaperFile(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = appSupportURL
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
            return destinationURL
        } catch {
            return nil
        }
    }

    private func importWallpaperOnMain(_ url: URL) {
        DispatchQueue.main.async {
            if viewModel.addWallpaper(url: url) {
                viewModel.setActiveWallpaper(url: url)
            }
        }
    }
}

struct WallpaperThumbView: View {
    let url: URL
    let isActive: Bool

    var body: some View {
        ZStack {
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusS))
            } else {
                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                    .fill(StudioTheme.Surface.raised)
                    .frame(width: 80, height: 60)
                Image(systemName: "photo")
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            if isActive {
                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                    .stroke(StudioTheme.Action.primary, lineWidth: 3)
                    .frame(width: 80, height: 60)

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(StudioTheme.Action.primary)
                            .background(StudioTheme.Surface.base.clipShape(Circle()))
                            .padding(4)
                    }
                    Spacer()
                }
                .frame(width: 80, height: 60)
            }
        }
        .frame(width: 80, height: 60)
    }
}
