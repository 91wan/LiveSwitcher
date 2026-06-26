import SwiftUI

@MainActor
struct LiveModeView: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let onOpenMixer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let verticalInsets = LiveModeLayoutMetrics.contentTopPadding + LiveModeLayoutMetrics.contentBottomPadding
            let promptHeight: CGFloat = viewModel.isAgendaTimeReminderEnabled ? 46 : 0
            let mainHeight = max(
                0,
                proxy.size.height - verticalInsets - LiveModeLayoutMetrics.footerHeight - 8 - promptHeight
            )

            VStack(spacing: 8) {
                if viewModel.isAgendaTimeReminderEnabled {
                    AgendaReminderHost()
                        .frame(height: 38)
                }

                HStack(alignment: .top, spacing: LiveModeLayoutMetrics.mainColumnSpacing) {
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
            .padding(.horizontal, LiveModeLayoutMetrics.horizontalContentPadding / 2)
            .padding(.top, LiveModeLayoutMetrics.contentTopPadding)
            .padding(.bottom, LiveModeLayoutMetrics.contentBottomPadding)
        }
    }
}

@MainActor
private struct AgendaReminderHost: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            if let prompt = viewModel.agendaReminderPrompt(now: context.date) {
                AgendaReminderPromptBanner(
                    prompt: prompt,
                    onTake: { viewModel.handleAgendaReminderAction(prompt) },
                    onDismiss: { viewModel.acknowledgeAgendaReminder(prompt) }
                )
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
    }
}

private struct AgendaReminderPromptBanner: View {
    let prompt: AgendaReminderPrompt
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
            if prompt.kind == .playableProgram {
                Button("切换") {
                    onTake()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Action.primary)
                .focusable(false)
                Button("忽略") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
            } else {
                Button("知道了") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Tone.warn)
                .focusable(false)
            }
        }
        .padding(.horizontal, 12)
        .background(StudioTheme.Tone.warn.opacity(0.11), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.Tone.warn.opacity(0.24), lineWidth: 1))
        .accessibilityLabel("议程提示。\(prompt.message)")
    }
}

@MainActor
struct LiveSourceRail: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        let programCount = viewModel.programItems.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("信号源")
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
                            Text("准备")
                                .font(StudioTheme.TypeScale.caption.weight(.black))
                                .lineLimit(1)
                        }
                            .frame(maxWidth: .infinity)
                            .frame(height: 78)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StudioTheme.Action.primary)
                    .focusable(false)
                    .accessibilityLabel("切到准备模式")
                    .accessibilityHint("打开节目单添加信号源。")
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                            if item.isAgendaMarker {
                                LiveSourceRailMarkerCueRow(
                                    item: item,
                                    queuePosition: index + 1
                                )
                            } else {
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
        .accessibilityLabel("现场信号源列表")
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

private struct LiveSourceRailMarkerCueRow: View {
    let item: ProgramItem
    let queuePosition: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ProgramQueueNumberBadge(
                    text: ProgramQueueNumberBadgeMetrics.displayText(for: queuePosition),
                    kind: .marker,
                    foreground: StudioTheme.Tone.warn,
                    background: StudioTheme.Tone.warn.opacity(0.14)
                )

                Image(systemName: "mappin.and.ellipse")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.Tone.warn)
                    .frame(
                        width: LiveModeLayoutMetrics.transportButtonSize,
                        height: LiveModeLayoutMetrics.transportButtonSize
                    )
                    .background(
                        Circle()
                            .fill(StudioTheme.Tone.warn.opacity(0.12))
                    )

                Text("标记")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.Tone.warn)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(item.title)
                .font(StudioTheme.TypeScale.caption.weight(.semibold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)

            if let scheduledStartText {
                Text(scheduledStartText)
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.Tone.warn.opacity(0.07), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.Tone.warn.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("议程标记，\(item.title)")
    }

    private var scheduledStartText: String? {
        guard let scheduledStartAt = item.scheduledStartAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: scheduledStartAt)
    }
}

private struct LiveSourceRailRow: View {
    let item: ProgramItem
    let queueRole: QueueRole
    let queuePosition: Int
    let isSelected: Bool
    let isBroadcasting: Bool
    let action: () -> Void

    private var labelModel: SourceRailRowLabelModel {
        SourceRailRowLabelModel.make(
            queuePosition: queuePosition,
            queueRole: queueRole,
            sourceLabel: item.displaySourceLabel
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 7) {
                    ProgramQueueNumberBadge(
                        text: labelModel.numberText,
                        kind: .live,
                        foreground: numberBadgeForeground,
                        background: numberBadgeBackground
                    )

                    ProgramThumbnailView(
                        sourceURL: item.sourceURL,
                        kind: item.sourceKind,
                        isVideo: item.isVideoMedia,
                        displaySize: LiveModeLayoutMetrics.railThumbnailSize
                    )
                    .frame(maxWidth: .infinity)

                    PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))
                }

                Text(labelModel.detailText)
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.title)
                    .font(StudioTheme.TypeScale.caption.weight(isSelected ? .black : .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
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
            .accessibilityLabel("\(labelModel.accessibilityLabel)，\(item.title)")
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

    private var numberBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.textSecondary
        }
    }

    private var numberBadgeBackground: Color {
        switch queueRole {
        case .current:
            return statusColor
        case .next:
            return StudioTheme.Tone.warn.opacity(0.14)
        case .queued:
            return StudioTheme.Surface.raised
        }
    }

    private var rowBackground: Color {
        isSelected ? statusColor.opacity(0.13) : StudioTheme.Surface.raised.opacity(0.62)
    }
}

struct LiveProgramStack: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        ProgramMonitorView(isLiveMode: true, avCoordinator: viewModel.avCoordinator)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("现场主输出监看")
    }
}

@MainActor
struct LiveAudioStrip: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let onOpenMixer: () -> Void

    var body: some View {
        LiveAudioStripContent(
            avCoordinator: viewModel.avCoordinator,
            bgmMeterStore: viewModel.audioMeterStore,
            onOpenMixer: onOpenMixer
        )
    }
}

@MainActor
private struct LiveAudioStripContent: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    @ObservedObject var avCoordinator: AVPlayerCoordinator
    @ObservedObject var bgmMeterStore: AudioMeterStore
    let onOpenMixer: () -> Void

    var body: some View {
        @Bindable var viewModel = viewModel

        HStack(spacing: 10) {
            LiveAudioFader(
                title: "Master",
                subtitle: "总线",
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
                subtitle: "节目",
                value: $viewModel.mediaVolume,
                isMuted: $viewModel.isMediaAudioMuted,
                meter: LiveAudioMeterModel.make(
                    realtimeDB: avCoordinator.realtimeLevelDB,
                    fallbackEffectiveVolume: viewModel.effectiveMediaOutputVolume(),
                    isMuted: viewModel.isMasterAudioMuted || viewModel.isMediaAudioMuted
                ),
                tint: StudioTheme.Action.primary
            )
            LiveAudioFader(
                title: "BGM",
                subtitle: "音乐",
                value: $viewModel.bgmVolume,
                isMuted: $viewModel.isBGMAudioMuted,
                meter: LiveAudioMeterModel.make(
                    realtimeDB: bgmMeterStore.bgmRealtimeLevelDB,
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
                    Label("调音台", systemImage: "slider.horizontal.3")
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
        .accessibilityLabel("现场音频控制条")
    }

    private var audioStatusText: String {
        let strategy = viewModel.audioStrategy.displayTitle
        if viewModel.isPanicMode { return "\(strategy) · 紧急切黑" }
        if viewModel.isBGMAudioTakeoverActive { return "\(strategy) · BGM 接管" }
        if viewModel.isSpeakerMode { return "\(strategy) · 主持人" }
        if viewModel.isPageInterceptEnabled { return "\(strategy) · PPT" }
        return strategy
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
                Text(meter.decibelText)
                    .font(StudioTheme.TypeScale.heading.weight(.black))
                    .foregroundStyle(StudioTheme.color(for: meter.statusKind))
                    .help(meter.isEstimated ? "该 channel 没有 AVAudioEngine tap，显示为估算值。" : "实时音频电平")
            }

            Slider(value: $value, in: 0...1)
                .tint(tint)
                .controlSize(.small)
                .accessibilityLabel("\(title) 音量")
                .accessibilityValue("用户值 \(percent(value))，电平 \(meter.decibelText)")

            HStack(spacing: 8) {
                LiveAudioMeter(model: meter, tint: tint)
                Button {
                    isMuted.toggle()
                } label: {
                    Label(isMuted ? "取消静音" : "静音", systemImage: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .labelStyle(.iconOnly)
                        .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(isMuted ? "取消 \(title) 静音" : "\(title) 静音")
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
        .accessibilityLabel("音频电平")
        .accessibilityValue(model.isEstimated ? "估算电平，\(model.decibelText)" : model.decibelText)
    }
}

@MainActor
struct LiveQuickRail: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    @State private var liveBGMCategory: BGMCategory = .warmUp
    @State private var isBGMChooserPresented = false
    @State private var bgmChooserSearchText = ""
    @State private var bgmChooserCategory: BGMCategory?
    let onOpenMixer: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                outputCard
                cutBusCard
                bgmCard
                wallpaperCard
                overlayCard
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("现场快速控制")
    }

    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return quickCard(title: "输出", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: model.screenSystemImage)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .accessibilityHidden(true)
                    Text(model.operatorLine)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
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
        let returnToStart = LiveMediaReturnToStartControlModel.make(currentItem: viewModel.currentProgramItem)

        return quickCard(title: "切换", status: viewModel.isFadeToBlackActive ? "已切黑" : "", kind: viewModel.isFadeToBlackActive ? .warn : .idle) {
            HStack(spacing: 7) {
                Button {
                    if let index = model.nextIndex {
                        viewModel.switchToProgram(at: index)
                    }
                } label: {
                    Label("下一项", systemImage: "arrow.right.to.line.compact")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.Action.primary)
                .disabled(!model.canTakeNext)
                .help(model.canTakeNext ? "切换到下一项：\(model.nextTitle)" : "没有下一项")

                ftbButton
            }

            if returnToStart.isEnabled {
                Button {
                    viewModel.returnCurrentMediaToStart()
                } label: {
                    Label(returnToStart.title, systemImage: "backward.end.fill")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(returnToStart.help ?? "")
                .accessibilityLabel(returnToStart.title)
                .accessibilityHint(returnToStart.help ?? "")
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
            Label(viewModel.isFadeToBlackActive ? "恢复" : "切黑", systemImage: viewModel.isFadeToBlackActive ? "play.fill" : "moon.fill")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(width: LiveModeLayoutMetrics.ftbButtonWidth, height: 40)
        }
        .help(viewModel.isFadeToBlackActive ? "从黑场恢复" : "淡出至黑场")
        .accessibilityLabel(viewModel.isFadeToBlackActive ? "恢复画面" : "切黑")

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
        quickCard(title: "叠层", status: overlayStatusText, kind: overlayStatusKind) {
            compactOverlayRow(
                model: LiveOverlayRailRowModel.lowerThird(
                    presets: viewModel.lowerThirdPresets,
                    selectedID: viewModel.overlayComposerState.selectedLowerThirdPresetID,
                    isLive: viewModel.isLowerThirdVisible
                ),
                systemImage: OverlayComposerKind.lowerThird.systemImage
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
                systemImage: OverlayComposerKind.countdown.systemImage
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
                systemImage: OverlayComposerKind.ticker.systemImage
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

            overlayClearAllButton
        }
    }

    private var overlayClearAllButton: some View {
        let hasActiveOverlay = overlayActiveCount > 0

        return Button {
            viewModel.clearAllOverlays()
        } label: {
            Label("全部清空", systemImage: "xmark.circle")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!hasActiveOverlay)
        .opacity(hasActiveOverlay ? 1 : 0.42)
        .help("关闭当前全部上屏叠层")
        .accessibilityLabel("全部清空叠层")
    }

    private func compactOverlayRow<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        @ViewBuilder menuContent: () -> MenuContent,
        onToggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            overlayPresetMenu(
                model: model,
                systemImage: systemImage,
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
            .help(model.canToggle ? (model.isLive ? "停止\(model.title)" : "\(model.title)上屏") : model.disabledHint)
            .accessibilityLabel(model.isLive ? "停止\(model.title)" : "\(model.title)上屏")
            .accessibilityHint(model.canToggle ? model.presetLabel : model.disabledHint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityLabel)
    }

    @ViewBuilder
    private func overlayPresetMenu<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        switch model.presetInteraction {
        case .create(let kind):
            Button {
                openOverlaySetup(kind)
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("到叠层字幕页面新建\(model.title)。")
            .accessibilityLabel(model.presetLabel)
            .accessibilityHint("还没有保存\(model.title)预设。打开叠层字幕页面新建\(model.title)。")
        case .choose:
            Menu {
                menuContent()
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: true)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("\(model.title)预设")
            .accessibilityHint("选择一个已保存预设。")
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

        return quickCard(title: "待机", status: picker.statusText, kind: picker.statusKind) {
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
                    Label("添加壁纸", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("打开准备模式节目单导入待机壁纸。")
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
                            .accessibilityLabel("选择待机壁纸")
                            .accessibilityValue(item.isActive ? "\(item.title)，当前启用" : item.title)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .accessibilityLabel("选择待机壁纸")
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
            isPlaying: viewModel.isBGMPlaying,
            phase: viewModel.runtime.state.bgm.phase
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

            HStack(spacing: 6) {
                transportButton("gobackward", label: "回到开头", enabled: controls.canSeekToBeginning, disabledHint: controls.seekDisabledReason) {
                    viewModel.seekBGMToBeginning()
                }
                transportButton("backward.end.fill", label: "上一首", enabled: controls.canSkipPrevious, disabledHint: controls.skipDisabledReason) {
                    viewModel.playPreviousBGM()
                }
                transportButton(viewModel.isBGMPlaying ? "pause.fill" : "play.fill", label: viewModel.isBGMPlaying ? "暂停 BGM" : "播放 BGM", enabled: controls.canPlay, disabledHint: controls.playDisabledReason) {
                    if let item = BGMDefaultSelectionPolicy.defaultItem(
                        items: viewModel.bgmItems,
                        currentItem: viewModel.currentBGMItem,
                        selectedCategory: playlist.displayCategory
                    ) {
                        viewModel.toggleBGM(item)
                    }
                }
                transportButton("forward.end.fill", label: "下一首", enabled: controls.canSkipNext, disabledHint: controls.skipDisabledReason) {
                    viewModel.playNextBGM()
                }
            }

            bgmCategoryMenu(picker: picker, title: playlist.categoryButtonTitle)

            liveBGMPlaylistRows(playlist)

            fullBGMChooserButton()
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
                Text("BGM 库为空")
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
        .frame(maxWidth: .infinity)
        .frame(height: LiveModeLayoutMetrics.transportButtonSize)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("选择 BGM 分类")
    }

    private func fullBGMChooserButton() -> some View {
        Button {
            isBGMChooserPresented = true
        } label: {
            Label("全部曲目 · \(viewModel.bgmItems.count)", systemImage: "music.note.list")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(viewModel.bgmItems.isEmpty ? "曲库为空。" : "搜索并选择任意已有 BGM 曲目。")
        .accessibilityLabel("选择任意 BGM 曲目")
        .accessibilityValue("\(viewModel.bgmItems.count) 首")
        .popover(isPresented: $isBGMChooserPresented) {
            LiveBGMChooserPopover(
                searchText: $bgmChooserSearchText,
                selectedCategory: $bgmChooserCategory
            ) {
                isBGMChooserPresented = false
            }
        }
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
                            .frame(height: 28)
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

    private func transportButton(_ systemName: String, label: String, enabled: Bool, disabledHint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .help(enabled ? label : disabledHint ?? label)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : disabledHint ?? "")
    }

    private func outputFill(_ model: ProjectionButtonModel) -> Color {
        if !model.isEnabled { return StudioTheme.Tone.muted.opacity(0.18) }
        if model.statusKind == .fail { return StudioTheme.Action.danger }
        if model.isBroadcasting { return StudioTheme.Tone.live }
        return model.hasExternalDisplay ? StudioTheme.Action.primary : StudioTheme.Tone.muted
    }

    private var overlayStatusText: String {
        overlayActiveCount == 0 ? "关闭" : "\(overlayActiveCount) 上屏"
    }

    private var overlayStatusKind: StudioTheme.StatusKind {
        overlayActiveCount > 0 ? .warn : .idle
    }

    private var overlayActiveCount: Int {
        [viewModel.isLowerThirdVisible, viewModel.isCountdownActive, viewModel.isTickerActive].filter { $0 }.count
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
            AsyncLocalImage(url: item.url) {
                Rectangle()
                    .fill(StudioTheme.Surface.raised)
                    .overlay {
                        Image(systemName: "photo")
                            .font(StudioTheme.TypeScale.caption)
                            .foregroundStyle(StudioTheme.textTertiary)
                            .accessibilityHidden(true)
                    }
            } content: { image in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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

@MainActor
struct LiveRuntimeStatusBar: View {
    @Environment(SwitcherViewModel.self) private var viewModel

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
        .accessibilityLabel("现场运行状态。\(statusText)")
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
