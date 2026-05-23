import SwiftUI
import UniformTypeIdentifiers

// MARK: - Program Monitor

struct ProgramMonitorView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var utilitiesExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Program")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("Monitor")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(monitorStateLabel, kind: monitorStateKind)
            }

            previewDeck

            currentNextInfoRow

            utilitiesDisclosure

            Spacer(minLength: 0)
        }
        .padding(18)
        .studioCard(cornerRadius: 24)
    }

    private var previewDeck: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .fill(StudioTheme.monitorGradient)

            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .stroke(StudioTheme.monitorBorder, lineWidth: 1)

            mediaLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(.rect(cornerRadius: StudioTheme.monitorRadius, style: .continuous))
                .animation(.easeInOut(duration: viewModel.crossfadeDuration),
                           value: viewModel.currentProgramItem)

            if viewModel.isBroadcasting {
                RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                    .stroke(StudioTheme.borderCritical.opacity(0.95), lineWidth: 3)
                    .padding(1)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isBroadcasting ? StudioTheme.statusLive : StudioTheme.statusIdle)
                    .frame(width: 8, height: 8)
                Text(monitorStateLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StudioTheme.monitorText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Text(monitorDisplayMode)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.monitorText.opacity(0.82))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioTheme.monitorOverlayFill, in: Capsule())
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 342)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .shadow(color: StudioTheme.shadowStrong, radius: 12, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isBroadcasting ? "Program monitor on air" : "Program monitor standby")
    }

    private var currentNextInfoRow: some View {
        HStack(spacing: 10) {
            monitorInfoBlock(
                title: "Current",
                value: viewModel.currentProgramItem?.title ?? "No Program",
                subtitle: currentProgramSubtitle,
                status: viewModel.isBroadcasting ? .live : (viewModel.currentProgramItem == nil ? .warn : .idle)
            )
            monitorInfoBlock(
                title: "Next",
                value: nextProgramItem?.title ?? "None",
                subtitle: nextProgramItem?.subtitle.uppercased() ?? "Queue empty",
                status: nextProgramItem == nil ? .idle : .ready
            )
        }
    }

    private func monitorInfoBlock(title: String, value: String, subtitle: String, status: StudioTheme.StatusKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                Text(title == "Current" ? currentBlockStateText(status: status) : "NEXT")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.statusColor(status))
            }
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(status == .live ? StudioTheme.borderCritical : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }

    private var utilitiesDisclosure: some View {
        DisclosureGroup(isExpanded: $utilitiesExpanded) {
            VStack(spacing: 10) {
                transitionControlCard
                wallpaperTrayCard
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Utilities")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Text(utilitiesSummary)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var transitionControlCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Transition")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("Program")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }

            Slider(
                value: $viewModel.crossfadeDuration,
                in: 0.5...3.0,
                step: 0.05
            )
            .tint(StudioTheme.statusWarn)
            .accessibilityLabel("Transition duration")
            .accessibilityValue(String(format: "%.1f seconds", viewModel.crossfadeDuration))

            Text(String(format: "%.1fs", viewModel.crossfadeDuration))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(StudioTheme.statusWarn)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var wallpaperTrayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Standby Wallpaper")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                }
                Spacer()
                CountPill("\(viewModel.backgroundWallpapers.count) 张", kind: viewModel.backgroundWallpapers.isEmpty ? .warn : .ready)
            }

            if viewModel.backgroundWallpapers.isEmpty {
                InlineWarningBanner(title: "No standby wallpaper", message: "Import a neutral image for fallback.", kind: .warn)
            } else {
                WallpaperGalleryRow()
                    .frame(maxHeight: 92)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if viewModel.avCoordinator.isPlaying {
            VideoPlayerView(coordinator: viewModel.avCoordinator)
                .transition(.opacity)
        } else if let item = viewModel.currentProgramItem {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(StudioTheme.monitorText)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(StudioTheme.monitorText.opacity(0.6))
                }
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Text("待机中")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(StudioTheme.monitorText)
                Text("NO SIGNAL LOADED")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.7))
            }
            .transition(.opacity)
        }
    }

    private var monitorDisplayMode: String {
        if let item = viewModel.currentProgramItem {
            switch item.sourceKind {
            case .media:
                return item.isVideoMedia ? "VIDEO" : "AUDIO"
            case .html:
                return "HTML"
            case .pptx:
                return "PPTX"
            case .keynote:
                return "KEYNOTE"
            case .activeDeck:
                return "ACTIVE DECK"
            case .unsupported:
                return "SOURCE"
            }
        }
        return viewModel.backgroundImage != nil ? "WALLPAPER READY" : "IDLE"
    }

    private var currentProgramSubtitle: String {
        if viewModel.currentHTMLURL != nil { return "HTML is loaded" }
        if viewModel.avCoordinator.isPlaying { return "Media playing" }
        return viewModel.currentProgramItem?.subtitle.uppercased() ?? "Standby"
    }

    private var monitorStateLabel: String {
        if viewModel.isBroadcasting { return "ON AIR" }
        if viewModel.currentProgramItem != nil { return "PREVIEW" }
        return "STANDBY"
    }

    private var monitorStateKind: StudioTheme.StatusKind {
        if viewModel.isBroadcasting { return .live }
        if viewModel.currentProgramItem != nil { return .idle }
        return .warn
    }

    private var utilitiesSummary: String {
        "Transition \(String(format: "%.1fs", viewModel.crossfadeDuration)) · \(viewModel.backgroundWallpapers.count) wallpaper"
    }

    private func currentBlockStateText(status: StudioTheme.StatusKind) -> String {
        switch status {
        case .live:
            return "ON AIR"
        case .warn:
            return "EMPTY"
        default:
            return "CURRENT"
        }
    }

    private var nextProgramItem: ProgramItem? {
        guard !viewModel.programItems.isEmpty else { return nil }
        guard let currentID = viewModel.currentProgramItem?.id,
              let currentIndex = viewModel.programItems.firstIndex(where: { $0.id == currentID })
        else {
            return viewModel.programItems.first
        }
        let nextIndex = viewModel.programItems.index(after: currentIndex)
        guard nextIndex < viewModel.programItems.endIndex else { return nil }
        return viewModel.programItems[nextIndex]
    }
}

enum WallpaperDropSupport {
    static func decodeFileURL(from item: Any?) -> URL? {
        FileDropSupport.decodeFileURL(from: item)
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
                    openWallpaperPicker()
                }
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundStyle(StudioTheme.actionPrimary)
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
                            .foregroundStyle(isDroppingWallpaper ? StudioTheme.actionPrimary : StudioTheme.borderSubtle)
                            .background(
                                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                                    .fill(isDroppingWallpaper ? StudioTheme.actionPrimary.opacity(0.05) : StudioTheme.surfaceSecondary)
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

    private func openWallpaperPicker() {
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
                    .fill(StudioTheme.surfaceSecondary)
                    .frame(width: 80, height: 60)
                Image(systemName: "photo")
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            if isActive {
                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                    .stroke(StudioTheme.actionPrimary, lineWidth: 3)
                    .frame(width: 80, height: 60)

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(StudioTheme.actionPrimary)
                            .background(StudioTheme.surfacePrimary.clipShape(Circle()))
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

#Preview {
    ProgramMonitorView()
        .environmentObject(SwitcherViewModel())
        .frame(width: 700, height: 620)
}
