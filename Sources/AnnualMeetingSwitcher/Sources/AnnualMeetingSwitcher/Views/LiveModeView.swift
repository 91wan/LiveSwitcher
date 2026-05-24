import SwiftUI

struct LiveModeView: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let verticalInsets: CGFloat = 14
            let mainHeight = max(
                0,
                proxy.size.height - verticalInsets - LiveModeLayoutMetrics.footerHeight - 8
            )

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    LiveSourceRail()
                        .frame(width: LiveModeLayoutMetrics.sourceRailWidth)
                        .layoutPriority(1)

                    VStack(spacing: 10) {
                        LiveProgramStack()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(3)

                        LiveAudioStrip(onOpenMixer: onOpenMixer)
                            .frame(height: LiveModeLayoutMetrics.audioStripHeight)
                    }
                    .layoutPriority(3)

                    LiveQuickRail(onOpenMixer: onOpenMixer)
                        .frame(width: LiveModeLayoutMetrics.quickRailWidth)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: mainHeight)

                LiveRuntimeStatusBar()
                    .frame(height: LiveModeLayoutMetrics.footerHeight)
                    .layoutPriority(2)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
    }
}

struct LiveSourceRail: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sources")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                CountPill("\(viewModel.programItems.count)", kind: viewModel.programItems.isEmpty ? .idle : .ready)
            }

            if viewModel.programItems.isEmpty {
                EmptyStateView(
                    title: "No sources",
                    message: "Prepare the run queue in Setup mode.",
                    systemImage: "rectangle.stack"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                            LiveSourceRailRow(
                                item: item,
                                queueRole: role(for: item),
                                queuePosition: index + 1,
                                isSelected: item.id == viewModel.currentProgramItem?.id,
                                isBroadcasting: viewModel.isBroadcasting,
                                action: { viewModel.switchToProgram(at: index) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay), in: RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live source rail")
    }

    private func role(for item: ProgramItem) -> QueueRole {
        if item.id == viewModel.currentProgramItem?.id {
            return .current
        }
        if item.id == nextProgramItem?.id {
            return .next
        }
        return .queued
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

private struct LiveSourceRailRow: View {
    let item: ProgramItem
    let queueRole: QueueRole
    let queuePosition: Int
    let isSelected: Bool
    let isBroadcasting: Bool
    let action: () -> Void

    private var rowModel: ProgramQueueRowModel {
        ProgramQueueRowModel(
            item: item,
            queuePosition: queuePosition,
            queueRole: queueRole,
            isBroadcasting: isBroadcasting,
            isPlaying: false
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                ProgramThumbnailView(
                    sourceURL: item.sourceURL,
                    kind: item.sourceKind,
                    isVideo: item.isVideoMedia,
                    displaySize: LiveModeLayoutMetrics.railThumbnailSize
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(rowModel.queueBadgeText)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                        Text(item.displaySourceLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(StudioTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Text(item.title)
                        .font(.system(size: 12, weight: isSelected ? .black : .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(isSelected ? statusColor.opacity(0.55) : StudioTheme.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rowModel.queueBadgeText), \(item.title), \(item.displaySourceLabel)")
    }

    private var statusColor: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.Tone.idle
        }
    }

    private var rowBackground: Color {
        isSelected ? statusColor.opacity(0.13) : StudioTheme.Surface.raised.opacity(0.62)
    }
}

struct LiveProgramStack: View {
    var body: some View {
        ProgramMonitorView(isLiveMode: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Live program monitor")
    }
}

struct LiveAudioStrip: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            LiveAudioFader(
                title: "Master",
                subtitle: "Global",
                value: $viewModel.masterVolume,
                isMuted: $viewModel.isMasterAudioMuted,
                meter: LiveAudioMeterModel.make(
                    effectiveVolume: viewModel.isPanicMode || viewModel.isMasterAudioMuted ? 0 : Float(viewModel.masterVolume),
                    isMuted: viewModel.isPanicMode || viewModel.isMasterAudioMuted
                ),
                tint: StudioTheme.Action.primary
            )
            LiveAudioFader(
                title: "Media",
                subtitle: "Program",
                value: $viewModel.mediaVolume,
                isMuted: $viewModel.isMediaAudioMuted,
                meter: LiveAudioMeterModel.make(
                    effectiveVolume: viewModel.effectiveMediaOutputVolume(),
                    isMuted: viewModel.isMasterAudioMuted || viewModel.isMediaAudioMuted
                ),
                tint: StudioTheme.Action.primary
            )
            LiveAudioFader(
                title: "BGM",
                subtitle: "Music",
                value: $viewModel.bgmVolume,
                isMuted: $viewModel.isBGMAudioMuted,
                meter: LiveAudioMeterModel.make(
                    effectiveVolume: viewModel.effectiveBGMOutputVolume(),
                    isMuted: viewModel.isMasterAudioMuted || viewModel.isBGMAudioMuted
                ),
                tint: StudioTheme.Tone.warn
            )

            VStack(alignment: .trailing, spacing: 8) {
                StatusBadge(viewModel.audioStrategy.displayTitle, kind: audioStatusKind)
                Button(action: onOpenMixer) {
                    Label("Mixer", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .bold))
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(width: 92)
        }
        .padding(12)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay), in: RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live audio strip")
    }

    private var audioStatusKind: StudioTheme.StatusKind {
        if viewModel.isPanicMode { return .fail }
        if viewModel.isBGMAudioTakeoverActive || viewModel.isSpeakerMode || viewModel.isPageInterceptEnabled { return .warn }
        return .ready
    }
}

private struct LiveAudioFader: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    @Binding var isMuted: Bool
    let meter: LiveAudioMeterModel
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                Spacer()
                Text(meter.decibelText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.color(for: meter.statusKind))
            }

            Slider(value: $value, in: 0...1)
                .tint(tint)
                .controlSize(.small)
                .accessibilityLabel("\(title) volume")
                .accessibilityValue("User \(percent(value)), meter \(meter.decibelText)")

            HStack(spacing: 8) {
                LiveAudioMeter(model: meter, tint: tint)
                Button {
                    isMuted.toggle()
                } label: {
                    Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .labelStyle(.iconOnly)
                        .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(isMuted ? "Unmute \(title)" : "Mute \(title)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct LiveAudioMeter: View {
    let model: LiveAudioMeterModel
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(StudioTheme.Tone.muted.opacity(0.18))
                Capsule(style: .continuous)
                    .fill(model.statusKind == .muted ? StudioTheme.Tone.muted.opacity(0.35) : tint.opacity(0.78))
                    .frame(width: proxy.size.width * model.level)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Audio meter")
        .accessibilityValue(model.decibelText)
    }
}

struct LiveQuickRail: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            outputCard
            cutBusCard
            overlayCard
            wallpaperCard
            bgmCard
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Live quick rail")
    }

    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return quickCard(title: "Output", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: model.screenSystemImage)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.title)
                            .font(.system(size: 12, weight: .black))
                            .lineLimit(1)
                        Text(model.screenLabel)
                            .font(StudioTheme.caption())
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .foregroundStyle(model.isEnabled ? .white : StudioTheme.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 42)
                .background(outputFill(model), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.isEnabled)
            .help(model.helpText)
        }
    }

    private var cutBusCard: some View {
        let model = LiveCutBusModel.make(
            programItems: viewModel.programItems,
            currentProgramItem: viewModel.currentProgramItem
        )

        return quickCard(title: "Cut Bus", status: viewModel.isPanicMode ? "BLACK" : "READY", kind: viewModel.isPanicMode ? .fail : .idle) {
            HStack(spacing: 7) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.togglePanicMode()
                    }
                } label: {
                    Label(viewModel.isPanicMode ? "Restore" : "FTB", systemImage: viewModel.isPanicMode ? "play.fill" : "moon.fill")
                        .font(.system(size: 12, weight: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isPanicMode ? StudioTheme.Tone.live : StudioTheme.Action.danger)
                .accessibilityLabel(viewModel.isPanicMode ? "Restore from blackout" : "Fade to black")

                Button {
                    if let index = model.nextIndex {
                        viewModel.switchToProgram(at: index)
                    }
                } label: {
                    Label("Take Next", systemImage: "arrow.right.to.line.compact")
                        .font(.system(size: 12, weight: .black))
                        .labelStyle(.iconOnly)
                        .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: 40)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canTakeNext)
                .help(model.canTakeNext ? "Take next source: \(model.nextTitle)" : "No next source")
            }
        }
    }

    private var overlayCard: some View {
        quickCard(title: "Overlays", status: overlayStatusText, kind: overlayStatusKind) {
            overlayButton(
                title: "Lower Third",
                isActive: viewModel.isLowerThirdVisible,
                canStart: !viewModel.overlayComposerState.trimmedLowerThirdName.isEmpty,
                disabledHint: "Prepare a lower-third name in Setup.",
                start: {
                    viewModel.showLowerThird(
                        name: viewModel.overlayComposerState.lowerThirdNameDraft,
                        title: viewModel.overlayComposerState.lowerThirdTitleDraft
                    )
                },
                stop: { viewModel.dismissLowerThird() }
            )

            overlayButton(
                title: "Countdown",
                isActive: viewModel.isCountdownActive,
                canStart: OverlayUIState.countdownDisabledReason(
                    minutes: viewModel.overlayComposerState.countdownMinutesDraft,
                    seconds: viewModel.overlayComposerState.countdownSecondsDraft,
                    isLive: false
                ) == nil,
                disabledHint: "Prepare a valid countdown in Setup.",
                start: {
                    viewModel.startCountdown(
                        minutes: viewModel.overlayComposerState.countdownMinutesDraft,
                        seconds: viewModel.overlayComposerState.countdownSecondsDraft,
                        title: viewModel.overlayComposerState.countdownTitleDraft
                    )
                },
                stop: { viewModel.stopCountdown() }
            )

            overlayButton(
                title: "Ticker",
                isActive: viewModel.isTickerActive,
                canStart: !viewModel.overlayComposerState.trimmedTickerText.isEmpty,
                disabledHint: "Prepare ticker text in Setup.",
                start: { viewModel.startTicker(text: viewModel.overlayComposerState.tickerTextDraft) },
                stop: { viewModel.stopTicker() }
            )
        }
    }

    private var wallpaperCard: some View {
        quickCard(title: "Wallpaper", status: "\(viewModel.backgroundWallpapers.count)", kind: viewModel.backgroundWallpapers.isEmpty ? .warn : .ready) {
            Text(activeWallpaperTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(activeWallpaperTitle)

            Button(action: cycleWallpaper) {
                Label("Next wallpaper", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.backgroundWallpapers.count < 2)
        }
    }

    private var bgmCard: some View {
        let controls = BGMControlsState.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            isPlaying: viewModel.isBGMPlaying
        )

        return quickCard(title: "BGM", status: controls.displayStatusText, kind: controls.displayStatusKind) {
            Text(viewModel.currentBGMItem?.title ?? "No BGM selected")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .help(viewModel.currentBGMItem?.title ?? "No BGM selected")

            HStack(spacing: 7) {
                transportButton("backward.end.fill", enabled: controls.canSkipPrevious, hint: controls.skipDisabledReason) {
                    viewModel.playPreviousBGM()
                }
                transportButton(viewModel.isBGMPlaying ? "pause.fill" : "play.fill", enabled: controls.canPlay, hint: controls.playDisabledReason) {
                    if let current = viewModel.currentBGMItem {
                        viewModel.toggleBGM(current)
                    } else if let first = viewModel.bgmItems.first {
                        viewModel.toggleBGM(first)
                    }
                }
                transportButton("forward.end.fill", enabled: controls.canSkipNext, hint: controls.skipDisabledReason) {
                    viewModel.playNextBGM()
                }
                Spacer()
                Button(action: onOpenMixer) {
                    Image(systemName: "music.note.list")
                        .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Open BGM library")
            }
        }
    }

    private func quickCard<Content: View>(
        title: String,
        status: String,
        kind: StudioTheme.StatusKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(status, kind: kind)
            }
            content()
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay), in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(kind == .warn || kind == .fail || kind == .live ? StudioTheme.color(for: kind).opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func overlayButton(
        title: String,
        isActive: Bool,
        canStart: Bool,
        disabledHint: String,
        start: @escaping () -> Void,
        stop: @escaping () -> Void
    ) -> some View {
        Button(action: isActive ? stop : start) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer()
                Text(isActive ? "LIVE" : "OFF")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(isActive ? StudioTheme.Tone.warn : StudioTheme.textTertiary)
            }
            .frame(height: 30)
            .padding(.horizontal, 8)
            .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isActive && !canStart)
        .opacity(!isActive && !canStart ? 0.48 : 1)
        .help(!isActive && !canStart ? disabledHint : (isActive ? "Stop \(title)" : "Send \(title) live"))
    }

    private func transportButton(_ systemName: String, enabled: Bool, hint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .black))
                .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .help(hint ?? "BGM transport")
    }

    private func outputFill(_ model: ProjectionButtonModel) -> Color {
        if !model.isEnabled { return StudioTheme.Tone.muted.opacity(0.18) }
        if model.statusKind == .fail { return StudioTheme.Action.danger }
        if model.isBroadcasting { return StudioTheme.Tone.live }
        return model.hasExternalDisplay ? StudioTheme.Action.primary : StudioTheme.Tone.muted
    }

    private var overlayStatusText: String {
        let activeCount = [viewModel.isLowerThirdVisible, viewModel.isCountdownActive, viewModel.isTickerActive].filter { $0 }.count
        return activeCount == 0 ? "OFF" : "\(activeCount) LIVE"
    }

    private var overlayStatusKind: StudioTheme.StatusKind {
        [viewModel.isLowerThirdVisible, viewModel.isCountdownActive, viewModel.isTickerActive].contains(true) ? .warn : .idle
    }

    private var activeWallpaperTitle: String {
        viewModel.activeWallpaperURL?.lastPathComponent ?? "No standby wallpaper"
    }

    private func cycleWallpaper() {
        let wallpapers = viewModel.backgroundWallpapers
        guard wallpapers.count >= 2 else { return }
        let currentIndex = viewModel.activeWallpaperURL.flatMap { current in
            wallpapers.firstIndex(of: current)
        } ?? -1
        let nextIndex = wallpapers.index(after: currentIndex)
        viewModel.setActiveWallpaper(url: wallpapers[nextIndex < wallpapers.endIndex ? nextIndex : wallpapers.startIndex])
    }
}

struct LiveRuntimeStatusBar: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            Text(statusText)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("v\(AppConfiguration.appVersion)")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(StudioTheme.Surface.base.opacity(0.62), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
        .accessibilityLabel("Live runtime status. \(statusText)")
    }

    private var statusDot: some View {
        Circle()
            .fill(statusKindColor)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }

    private var statusKindColor: Color {
        StudioTheme.color(for: runtimeStatus.kind)
    }

    private var statusText: String {
        runtimeStatus.text
    }

    private var runtimeStatus: LiveRuntimeStatusModel {
        LiveRuntimeStatusModel.make(snapshot: viewModel.livePreflightSnapshot)
    }
}
