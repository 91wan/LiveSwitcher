import SwiftUI

struct LiveModeView: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let verticalInsets: CGFloat = 14
            let agendaPrompt = viewModel.agendaAutoAdvancePrompt()
            let promptHeight: CGFloat = agendaPrompt == nil ? 0 : 46
            let mainHeight = max(
                0,
                proxy.size.height - verticalInsets - LiveModeLayoutMetrics.footerHeight - 8 - promptHeight
            )

            VStack(spacing: 8) {
                if let prompt = agendaPrompt {
                    AgendaAutoAdvancePromptBanner(
                        prompt: prompt,
                        onTake: { viewModel.confirmAgendaAutoAdvance(prompt) },
                        onDismiss: { viewModel.dismissAgendaAutoAdvancePrompt(prompt) }
                    )
                    .frame(height: 38)
                }

                HStack(alignment: .top, spacing: 10) {
                    LiveSourceRail()
                        .frame(width: viewModel.programItems.isEmpty ? LiveModeLayoutMetrics.sourceRailWidthEmpty : LiveModeLayoutMetrics.sourceRailWidth)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.programItems.isEmpty)
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

private struct AgendaAutoAdvancePromptBanner: View {
    let prompt: AgendaAutoAdvancePrompt
    let onTake: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(StudioTheme.TypeScale.body.weight(.bold))
                .foregroundStyle(StudioTheme.Tone.warn)
            Text(prompt.message)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button("Take") {
                onTake()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(StudioTheme.Action.primary)
            .focusable(false)
            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .focusable(false)
        }
        .padding(.horizontal, 12)
        .background(StudioTheme.Tone.warn.opacity(0.11), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.Tone.warn.opacity(0.24), lineWidth: 1))
        .accessibilityLabel("Agenda prompt. \(prompt.message)")
    }
}

struct LiveSourceRail: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel

    var body: some View {
        let programCount = viewModel.programItems.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sources")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                if CountPillVisibilityPolicy.shouldShow(count: programCount) {
                    CountPill("\(programCount)", kind: .ready)
                }
            }

            if viewModel.programItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.navigateToSetup(.preview)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "gearshape.fill")
                                .font(StudioTheme.TypeScale.title.weight(.black))
                            Text("Setup")
                                .font(StudioTheme.TypeScale.caption.weight(.black))
                                .lineLimit(1)
                        }
                            .frame(maxWidth: .infinity)
                            .frame(height: 78)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.Action.primary)
                    .focusable(false)
                    .accessibilityLabel("Switch to Setup")
                    .accessibilityHint("Open Setup Run Queue to add sources.")
                    Spacer(minLength: 0)
                }
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
                                action: { viewModel.switchToProgramAfterReadinessConfirmation(item) }
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
        ProgramQueueStore.nextPlayableAfterCurrent(
            current: viewModel.currentProgramItem,
            in: viewModel.programItems
        )
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
                            .font(StudioTheme.TypeScale.label)
                            .foregroundStyle(statusColor)
                            .lineLimit(1)
                        Text(item.displaySourceLabel)
                            .font(StudioTheme.TypeScale.label.weight(.bold))
                            .foregroundStyle(StudioTheme.textTertiary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))
                    }
                    Text(item.title)
                        .font(StudioTheme.TypeScale.caption.weight(isSelected ? .black : .semibold))
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
                    realtimeDB: viewModel.liveMasterMeterRealtimeDB(),
                    fallbackEffectiveVolume: viewModel.liveMasterMeterFallbackVolume(),
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
                    realtimeDB: viewModel.avCoordinator.realtimeLevelDB,
                    fallbackEffectiveVolume: viewModel.effectiveMediaOutputVolume(),
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
                    realtimeDB: viewModel.bgmRealtimeLevelDB,
                    fallbackEffectiveVolume: viewModel.effectiveBGMOutputVolume(),
                    isMuted: viewModel.isMasterAudioMuted || viewModel.isBGMAudioMuted || !viewModel.isBGMPlaying
                ),
                tint: StudioTheme.Tone.warn
            )

            VStack(alignment: .trailing, spacing: 8) {
                if StatusBadgeVisibilityPolicy.shouldShow(text: audioStatusText, kind: audioStatusKind) {
                    StatusBadge(audioStatusText, kind: audioStatusKind)
                }
                Button(action: onOpenMixer) {
                    Label("Mixer", systemImage: "slider.horizontal.3")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
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

    private var audioStatusText: String {
        viewModel.audioStrategy.displayTitle
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
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
                Spacer()
                HStack(spacing: 4) {
                    if meter.isEstimated {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(StudioTheme.caption().weight(.black))
                            .foregroundStyle(StudioTheme.Tone.warn)
                            .help("Estimated meter")
                            .accessibilityLabel("Estimated meter")
                    }
                    Text(meter.decibelText)
                        .font(StudioTheme.TypeScale.heading.weight(.black))
                        .foregroundStyle(StudioTheme.color(for: meter.statusKind))
                }
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
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .labelStyle(.iconOnly)
                        .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
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
        .accessibilityValue(model.isEstimated ? "Estimated meter, \(model.decibelText)" : model.decibelText)
    }
}

struct LiveQuickRail: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    @State private var liveBGMCategory: BGMCategory = .warmUp
    let onOpenMixer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            outputCard
            modesCard
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
                            .font(StudioTheme.TypeScale.caption.weight(.black))
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

    private var modesCard: some View {
        let isModeActive = viewModel.isSpeakerMode || viewModel.isPageInterceptEnabled
        return quickCard(title: "Modes", status: isModeActive ? "ACTIVE" : "", kind: isModeActive ? .warn : .idle) {
            modeToggleRow(
                title: "Speaker",
                subtitle: "Duck BGM",
                systemImage: "mic.fill",
                isOn: $viewModel.isSpeakerMode
            )
            modeToggleRow(
                title: "PPT",
                subtitle: "Page keys",
                systemImage: "hand.raised.slash.fill",
                isOn: $viewModel.isPageInterceptEnabled
            )
        }
    }

    private func modeToggleRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(isOn.wrappedValue ? StudioTheme.Tone.warn : StudioTheme.textTertiary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        .help(isOn.wrappedValue ? "\(title) mode is active" : "Enable \(title) mode")
    }

    private var cutBusCard: some View {
        let model = LiveCutBusModel.make(
            programItems: viewModel.programItems,
            currentProgramItem: viewModel.currentProgramItem
        )

        return quickCard(title: "Cut Bus", status: viewModel.isFadeToBlackActive ? "FTB" : "", kind: viewModel.isFadeToBlackActive ? .warn : .idle) {
            HStack(spacing: 7) {
                Button {
                    if let index = model.nextIndex {
                        viewModel.switchToProgram(at: index)
                    }
                } label: {
                    Label("Take Next", systemImage: "arrow.right.to.line.compact")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.Action.primary)
                .disabled(!model.canTakeNext)
                .help(model.canTakeNext ? "Take next source: \(model.nextTitle)" : "No next source")

                ftbButton
            }
        }
    }

    @ViewBuilder
    private var ftbButton: some View {
        let button = Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.toggleFadeToBlack()
            }
        } label: {
            Label(viewModel.isFadeToBlackActive ? "Restore" : "FTB", systemImage: viewModel.isFadeToBlackActive ? "play.fill" : "moon.fill")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(width: LiveModeLayoutMetrics.ftbButtonWidth, height: 40)
        }
        .accessibilityLabel(viewModel.isFadeToBlackActive ? "Restore from FTB" : "Fade to black")

        if viewModel.isFadeToBlackActive {
            button
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.Action.danger)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(StudioTheme.Action.danger)
        }
    }

    private var overlayCard: some View {
        quickCard(title: "Overlays", status: overlayStatusText, kind: overlayStatusKind) {
            compactOverlayRow(
                model: LiveOverlayRailRowModel.lowerThird(
                    presets: viewModel.lowerThirdPresets,
                    selectedID: viewModel.overlayComposerState.selectedLowerThirdPresetID,
                    isLive: viewModel.isLowerThirdVisible
                ),
                systemImage: OverlayComposerKind.lowerThird.systemImage,
                setupKind: .lowerThird
            ) {
                ForEach(viewModel.lowerThirdPresets) { preset in
                    Button {
                        viewModel.loadLowerThirdPreset(preset)
                        viewModel.showLowerThirdPreset(preset)
                    } label: {
                        Label(
                            preset.name,
                            systemImage: preset.id == viewModel.overlayComposerState.selectedLowerThirdPresetID ? "checkmark" : OverlayComposerKind.lowerThird.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isLowerThirdVisible {
                    viewModel.dismissLowerThird()
                } else if let preset = selectedLowerThirdPreset {
                    viewModel.showLowerThirdPreset(preset)
                }
            }

            compactOverlayRow(
                model: LiveOverlayRailRowModel.countdown(
                    presets: viewModel.countdownPresets,
                    selectedID: viewModel.overlayComposerState.selectedCountdownPresetID,
                    isLive: viewModel.isCountdownActive
                ),
                systemImage: OverlayComposerKind.countdown.systemImage,
                setupKind: .countdown
            ) {
                ForEach(viewModel.countdownPresets) { preset in
                    Button {
                        viewModel.loadCountdownPreset(preset)
                        viewModel.startCountdownPreset(preset)
                    } label: {
                        Label(
                            "\(preset.title) · \(formattedTime(preset.totalSeconds))",
                            systemImage: preset.id == viewModel.overlayComposerState.selectedCountdownPresetID ? "checkmark" : OverlayComposerKind.countdown.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isCountdownActive {
                    viewModel.stopCountdown()
                } else if let preset = selectedCountdownPreset {
                    viewModel.startCountdownPreset(preset)
                }
            }

            compactOverlayRow(
                model: LiveOverlayRailRowModel.ticker(
                    presets: viewModel.tickerPresets,
                    selectedID: viewModel.overlayComposerState.selectedTickerPresetID,
                    isLive: viewModel.isTickerActive
                ),
                systemImage: OverlayComposerKind.ticker.systemImage,
                setupKind: .ticker
            ) {
                ForEach(viewModel.tickerPresets) { preset in
                    Button {
                        viewModel.loadTickerPreset(preset)
                        viewModel.startTickerPreset(preset)
                    } label: {
                        Label(
                            "\(preset.text) · \(OverlaySpeedSelection.label(at: preset.speedIndex))",
                            systemImage: preset.id == viewModel.overlayComposerState.selectedTickerPresetID ? "checkmark" : OverlayComposerKind.ticker.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isTickerActive {
                    viewModel.stopTicker()
                } else if let preset = selectedTickerPreset {
                    viewModel.startTickerPreset(preset)
                }
            }
        }
    }

    private func compactOverlayRow<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        setupKind: OverlayComposerKind,
        @ViewBuilder menuContent: () -> MenuContent,
        onToggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            overlayPresetMenu(
                model: model,
                systemImage: systemImage,
                setupKind: setupKind,
                menuContent: menuContent
            )
            .frame(maxWidth: .infinity)

            Button(action: onToggle) {
                Text(model.toggleText)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(model.isLive ? StudioTheme.Tone.warn : StudioTheme.textTertiary)
                    .frame(width: 48, height: LiveModeLayoutMetrics.quickActionButtonHeight)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggle)
            .opacity(model.canToggle ? 1 : 0.48)
            .help(model.canToggle ? (model.isLive ? "Stop \(model.title)" : "Send \(model.title) live") : model.disabledHint)
            .accessibilityLabel(model.isLive ? "Stop \(model.title)" : "Send \(model.title) live")
            .accessibilityHint(model.canToggle ? model.presetLabel : model.disabledHint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityLabel)
    }

    @ViewBuilder
    private func overlayPresetMenu<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        setupKind: OverlayComposerKind,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        if model.presetLabel == "+ New preset" {
            Button {
                openOverlaySetup(setupKind)
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Create \(model.title.lowercased()) presets in Setup Overlays.")
            .accessibilityLabel("\(model.title) presets")
            .accessibilityHint("No presets are saved. Opens Setup Overlays.")
        } else {
            Menu {
                menuContent()
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: true)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("\(model.title) presets")
            .accessibilityHint("Choose a saved preset.")
        }
    }

    private func overlayPresetLabel(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        showsMenuIndicator: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .accessibilityHidden(true)
            Text(model.presetLabel)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(model.isPlaceholder ? StudioTheme.textTertiary : StudioTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 2)
            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        .help(model.title)
    }

    private func openOverlaySetup(_ kind: OverlayComposerKind) {
        withAnimation(.easeInOut(duration: 0.16)) {
            viewModel.navigateToSetup(.overlays)
            viewModel.overlayComposerState.selectedKind = kind
        }
    }

    private var selectedLowerThirdPreset: LowerThirdPreset? {
        viewModel.lowerThirdPresets.first {
            $0.id == viewModel.overlayComposerState.selectedLowerThirdPresetID
        }
    }

    private var selectedCountdownPreset: CountdownPreset? {
        viewModel.countdownPresets.first {
            $0.id == viewModel.overlayComposerState.selectedCountdownPresetID
        }
    }

    private var selectedTickerPreset: TickerPreset? {
        viewModel.tickerPresets.first {
            $0.id == viewModel.overlayComposerState.selectedTickerPresetID
        }
    }

    private var wallpaperCard: some View {
        let picker = LiveWallpaperQuickPickerModel.make(
            wallpapers: viewModel.backgroundWallpapers,
            activeWallpaperURL: viewModel.activeWallpaperURL
        )

        return quickCard(title: "Wallpaper", status: picker.statusText, kind: picker.statusKind) {
            Text(picker.displayTitle)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(picker.displayTitle)

            if picker.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.navigateToSetup(.preview)
                    }
                } label: {
                    Label("Add wallpaper", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Setup Run Queue to import standby wallpaper.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(picker.items) { item in
                            Button {
                                viewModel.setActiveWallpaper(url: item.url)
                            } label: {
                                LiveWallpaperPickerThumb(item: item)
                            }
                            .buttonStyle(.plain)
                            .help(item.title)
                            .accessibilityLabel("Choose standby wallpaper")
                            .accessibilityValue(item.isActive ? "\(item.title), active" : item.title)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .accessibilityLabel("Choose standby wallpaper")
            }
        }
    }

    private var bgmCard: some View {
        let picker = LiveBGMQuickPickerModel.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem
        )
        let controls = BGMControlsState.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            isPlaying: viewModel.isBGMPlaying
        )
        let playlist = LiveBGMPlaylistModel.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            selectedCategory: liveBGMCategory,
            isPlaying: viewModel.isBGMPlaying
        )

        return quickCard(title: "BGM", status: controls.displayStatusText, kind: controls.displayStatusKind) {
            Text(picker.currentTitle)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .help(picker.currentTitle)

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
                bgmCategoryMenu(picker: picker, title: playlist.categoryButtonTitle)
            }

            liveBGMPlaylistRows(playlist)
        }
        .onAppear {
            syncLiveBGMCategoryToCurrent()
        }
        .onChange(of: viewModel.currentBGMItem?.id) { _, _ in
            syncLiveBGMCategoryToCurrent()
        }
    }

    private func bgmCategoryMenu(picker: LiveBGMQuickPickerModel, title: String) -> some View {
        Menu {
            if picker.isLibraryEmpty {
                Text("No BGM in library")
            } else {
                ForEach(BGMCategory.allCases, id: \.self) { category in
                    if let section = picker.section(for: category) {
                        Button {
                            liveBGMCategory = category
                        } label: {
                            Label(section.title, systemImage: liveBGMCategory == category ? "checkmark" : "music.note.list")
                        }
                        .disabled(section.isEmpty)
                    }
                }
            }
        } label: {
            Text(title)
                .font(StudioTheme.TypeScale.label.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(width: 78, height: LiveModeLayoutMetrics.transportButtonSize)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Choose BGM category")
    }

    @ViewBuilder
    private func liveBGMPlaylistRows(_ playlist: LiveBGMPlaylistModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(playlist.displayCategory.rawValue)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let remaining = playlist.remainingCountText {
                    Text(remaining)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            if playlist.rows.isEmpty {
                Text(playlist.emptyMessage)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 26)
            } else {
                VStack(spacing: 3) {
                    ForEach(playlist.rows) { row in
                        Button {
                            viewModel.toggleBGM(row.item)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: row.systemImage)
                                    .font(StudioTheme.TypeScale.caption.weight(.black))
                                    .foregroundStyle(row.isCurrent ? StudioTheme.Action.primary : StudioTheme.textTertiary)
                                    .frame(width: 16)
                                    .accessibilityHidden(true)
                                Text(row.title)
                                    .font(StudioTheme.caption().weight(row.isCurrent ? .black : .semibold))
                                    .foregroundStyle(StudioTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6)
                            .frame(height: 24)
                            .background(
                                row.isCurrent ? StudioTheme.Action.primary.opacity(0.10) : StudioTheme.Surface.raised.opacity(0.58),
                                in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(row.title)
                        .accessibilityLabel(row.accessibilityLabel)
                    }
                }
            }
        }
    }

    private func syncLiveBGMCategoryToCurrent() {
        if let current = viewModel.currentBGMItem {
            liveBGMCategory = current.category
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
                if !status.isEmpty && StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind) {
                    StatusBadge(status, kind: kind)
                }
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

    private func transportButton(_ systemName: String, enabled: Bool, hint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(StudioTheme.TypeScale.body.weight(.black))
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

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

}

private struct LiveWallpaperPickerThumb: View {
    let item: LiveWallpaperQuickPickerModel.Item

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(contentsOf: item.url) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(StudioTheme.Surface.raised)
                        .overlay {
                            Image(systemName: "photo")
                                .font(StudioTheme.TypeScale.caption)
                                .foregroundStyle(StudioTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                }
            }
            .frame(width: 44, height: 32)
            .clipShape(.rect(cornerRadius: StudioTheme.radiusS))

            if item.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.Action.primary)
                    .background(StudioTheme.Surface.base.clipShape(Circle()))
                    .offset(x: -3, y: 3)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 46, height: 34)
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                .stroke(item.isActive ? StudioTheme.Action.primary : StudioTheme.borderSubtle, lineWidth: item.isActive ? 2 : 1)
        )
    }
}

struct LiveRuntimeStatusBar: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(runtimeStatus.chips.enumerated()), id: \.offset) { _, chip in
                        statusChip(chip)
                    }
                }
                .padding(.vertical, 2)
            }
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

    private func statusChip(_ chip: LiveRuntimeStatusChip) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.color(for: chip.kind))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(chip.text)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(StudioTheme.Surface.raised.opacity(0.82), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
    }

    private var statusText: String {
        runtimeStatus.text
    }

    private var runtimeStatus: LiveRuntimeStatusModel {
        LiveRuntimeStatusModel.make(snapshot: viewModel.livePreflightSnapshot)
    }
}
