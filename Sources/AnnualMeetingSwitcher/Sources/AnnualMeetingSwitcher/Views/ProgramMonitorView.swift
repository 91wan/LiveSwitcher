import SwiftUI

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
            monitorInfoBlock(model: .current(
                item: viewModel.currentProgramItem,
                isBroadcasting: viewModel.isBroadcasting,
                isPlaying: viewModel.avCoordinator.isPlaying,
                isHTMLLoaded: viewModel.currentHTMLURL != nil
            ))
            monitorInfoBlock(model: .next(
                item: nextProgramItem
            ))
        }
    }

    private func monitorInfoBlock(model: ProgramMonitorInfoBlockModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                Text(model.badgeText)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.statusColor(model.status))
            }
            Text(model.value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(model.subtitle)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(model.status == .live ? StudioTheme.borderCritical : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.title): \(model.value), \(model.subtitle)")
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

    private var monitorState: ProgramMonitorStateModel {
        ProgramMonitorStateModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            currentItem: viewModel.currentProgramItem
        )
    }

    private var monitorStateLabel: String {
        monitorState.label
    }

    private var monitorStateKind: StudioTheme.StatusKind {
        monitorState.kind
    }

    private var utilitiesSummary: String {
        "Transition \(String(format: "%.1fs", viewModel.crossfadeDuration)) · \(viewModel.backgroundWallpapers.count) wallpaper"
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

#Preview {
    ProgramMonitorView()
        .environmentObject(SwitcherViewModel())
        .frame(width: 700, height: 620)
}
