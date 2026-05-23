import SwiftUI

struct LiveOpsPanel: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Ops")
                        .font(StudioTheme.title())
                        .foregroundStyle(StudioTheme.textPrimary)
                }
                Spacer()
                if viewModel.isPanicMode {
                    StatusBadge("PANIC", kind: .fail)
                }
            }
            .padding(.horizontal, 4)

            outputCard
            audioCard
            bgmMiniCard

            Spacer(minLength: 0)

            runtimeFooter
        }
        .frame(maxHeight: .infinity)
    }

    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return opsCard(title: "Output", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isBroadcasting ? "stop.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .black))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.title)
                            .font(.system(size: 12, weight: .black))
                            .lineLimit(1)
                        Text(model.screenLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.82)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .foregroundStyle(outputActionForeground(model))
                .padding(.horizontal, 10)
                .frame(height: LiveOpsLayoutMetrics.outputPrimaryButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                        .fill(outputActionFill(model))
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(!model.isEnabled)
            .help(model.helpText)
            .accessibilityLabel(model.title)
            .accessibilityHint(model.subtitle)

            if model.statusKind == .fail, let warningTitle = model.warningTitle, let warningMessage = model.warningMessage {
                InlineWarningBanner(title: warningTitle, message: warningMessage, kind: .fail)
            }
        }
    }

    private var audioCard: some View {
        opsCard(title: "Audio", status: audioStatusText, kind: audioStatusKind) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .frame(width: 18)
                Slider(value: $viewModel.masterVolume, in: 0...1)
                    .tint(StudioTheme.Action.primary)
                    .controlSize(.small)
                    .accessibilityLabel("Master volume")
                    .accessibilityValue("\(Int(viewModel.masterVolume * 100)) percent")
                Text("\(Int(viewModel.masterVolume * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .frame(width: 38, alignment: .trailing)
            }

            HStack(spacing: 6) {
                miniMetric("Media", value: "\(Int(viewModel.effectiveMediaOutputVolume() * 100))%")
                miniMetric("BGM", value: "\(Int(viewModel.effectiveBGMOutputVolume() * 100))%")
                Button(action: onOpenMixer) {
                    Label("Mixer", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .bold))
                        .frame(height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Open audio mixer page")
            }

            audioModesRow
        }
    }

    private var bgmMiniCard: some View {
        let controls = BGMControlsState.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            isPlaying: viewModel.isBGMPlaying
        )

        return opsCard(title: "BGM", status: controls.displayStatusText, kind: controls.displayStatusKind) {
            Text(viewModel.currentBGMItem?.title ?? "No BGM selected")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .help(viewModel.currentBGMItem?.title ?? "No BGM selected")

            HStack(spacing: 6) {
                iconButton("backward.end.fill", enabled: controls.canSkipPrevious, hint: controls.skipDisabledReason) {
                    viewModel.playPreviousBGM()
                }
                iconButton(viewModel.isBGMPlaying ? "pause.fill" : "play.fill", enabled: controls.canPlay, hint: controls.playDisabledReason) {
                    if let current = viewModel.currentBGMItem {
                        viewModel.toggleBGM(current)
                    } else if let first = viewModel.bgmItems.first {
                        viewModel.toggleBGM(first)
                    }
                }
                iconButton("forward.end.fill", enabled: controls.canSkipNext, hint: controls.skipDisabledReason) {
                    viewModel.playNextBGM()
                }
                Spacer()
                Button(action: onOpenMixer) {
                    Text("Library")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.currentBGMItem != nil {
                bgmProgressRow
            }
        }
    }

    private var audioModesRow: some View {
        HStack(spacing: 6) {
            modeToggleRow(
                title: "Speaker",
                systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic",
                isOn: Binding(
                    get: { viewModel.isSpeakerMode },
                    set: { newValue in
                        if newValue != viewModel.isSpeakerMode {
                            viewModel.toggleSpeakerMode()
                        }
                    }
                ),
                accessibilityLabel: "Speaker mode"
            )

            modeToggleRow(
                title: "PPT",
                systemName: viewModel.isPageInterceptEnabled ? "hand.raised.fill" : "hand.raised.slash",
                isOn: Binding(
                    get: { viewModel.isPageInterceptEnabled },
                    set: { viewModel.isPageInterceptEnabled = $0 }
                ),
                accessibilityLabel: "PPT mode"
            )
        }
    }

    private var bgmProgressRow: some View {
        Slider(
            value: Binding(
                get: { viewModel.bgmProgress },
                set: { newValue in
                    viewModel.bgmProgress = newValue
                    if let player = viewModel.bgmAudioPlayer {
                        player.currentTime = player.duration * newValue
                        viewModel.bgmCurrentTime = player.currentTime
                    }
                }
            ),
            in: 0...1
        )
        .tint(StudioTheme.Action.primary)
        .controlSize(.small)
        .accessibilityLabel("BGM progress")
        .accessibilityValue("\(formatTime(viewModel.bgmCurrentTime)) of \(viewModel.bgmDuration.map { formatTime($0) } ?? "unknown duration")")
    }

    private func opsCard<Content: View>(
        title: String,
        status: String,
        kind: StudioTheme.StatusKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(status, kind: kind)
            }
            content()
        }
        .padding(LiveOpsLayoutMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(kind == .live || kind == .fail ? StudioTheme.color(for: kind).opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func miniMetric(_ title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
    }

    private func iconButton(
        _ systemName: String,
        enabled: Bool,
        hint: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                .frame(width: LiveOpsLayoutMetrics.bgmTransportButtonSize, height: LiveOpsLayoutMetrics.bgmTransportButtonSize)
                .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .accessibilityHint(hint ?? "BGM transport control")
    }

    private func modeToggleRow(
        title: String,
        systemName: String,
        isOn: Binding<Bool>,
        accessibilityLabel: String
    ) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemName)
        }
        .toggleStyle(LiveOpsToggleStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
    }

    private func outputActionFill(_ model: ProjectionButtonModel) -> Color {
        if !model.isEnabled { return StudioTheme.Tone.muted.opacity(0.18) }
        if model.statusKind == .fail { return StudioTheme.Action.danger }
        if model.isBroadcasting { return StudioTheme.Tone.live }
        return model.hasExternalDisplay ? StudioTheme.Action.primary : StudioTheme.Tone.muted
    }

    private func outputActionForeground(_ model: ProjectionButtonModel) -> Color {
        model.isEnabled ? .white : StudioTheme.textSecondary
    }

    private var runtimeFooter: some View {
        Text("v\(AppConfiguration.appVersion) · \(ProcessInfo.processInfo.operatingSystemVersionString)")
            .font(StudioTheme.caption())
            .foregroundStyle(StudioTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .accessibilityLabel("LiveSwitcher version \(AppConfiguration.appVersion). \(ProcessInfo.processInfo.operatingSystemVersionString).")
    }

    private var audioStatusText: String {
        if viewModel.isPanicMode { return "MUTED" }
        if viewModel.isBGMAudioTakeoverActive { return "BGM TAKEOVER" }
        if viewModel.isSpeakerMode && viewModel.isPageInterceptEnabled { return "MODES" }
        if viewModel.isSpeakerMode { return "SPEAKER" }
        if viewModel.isPageInterceptEnabled { return "PPT" }
        return "NORMAL"
    }

    private var audioStatusKind: StudioTheme.StatusKind {
        if viewModel.isPanicMode { return .fail }
        if viewModel.isBGMAudioTakeoverActive || viewModel.isSpeakerMode || viewModel.isPageInterceptEnabled { return .warn }
        return .ready
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct LiveOpsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                configuration.label
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(configuration.isOn ? StudioTheme.Tone.warn : StudioTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                switchTrack(isOn: configuration.isOn)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 7)
            .frame(height: LiveOpsLayoutMetrics.modeRowHeight)
            .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func switchTrack(isOn: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(isOn ? StudioTheme.Tone.warn.opacity(0.88) : StudioTheme.Tone.muted.opacity(0.28))
            .frame(width: 34, height: 19)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .shadow(color: StudioTheme.shadowSoft, radius: 2, x: 0, y: 1)
                    .padding(2)
            }
    }
}
