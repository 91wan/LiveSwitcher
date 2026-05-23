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
            modesCard

            Spacer(minLength: 0)
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
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                        .fill(outputActionFill(model))
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(!model.isEnabled)
            .opacity(model.isEnabled ? 1 : 0.62)
            .help(model.helpText)
            .accessibilityLabel(model.title)
            .accessibilityHint(model.subtitle)
        }
    }

    private var audioCard: some View {
        opsCard(title: "Audio", status: audioStatusText, kind: audioStatusKind) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.actionPrimary)
                    .frame(width: 18)
                Slider(value: $viewModel.masterVolume, in: 0...1)
                    .tint(StudioTheme.actionPrimary)
                    .controlSize(.small)
                    .accessibilityLabel("Master volume")
                    .accessibilityValue("\(Int(viewModel.masterVolume * 100)) percent")
                Text("\(Int(viewModel.masterVolume * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.actionPrimary)
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
        }
    }

    private var bgmMiniCard: some View {
        let controls = BGMControlsState.make(items: viewModel.bgmItems, currentItem: viewModel.currentBGMItem)

        return opsCard(title: "BGM", status: viewModel.isBGMPlaying ? "PLAYING" : "READY", kind: viewModel.isBGMPlaying ? .ready : .idle) {
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

            bgmProgressRow
        }
    }

    private var modesCard: some View {
        opsCard(title: "Modes", status: modesStatusText, kind: modesStatusKind) {
            HStack(spacing: 6) {
                modeToggleRow(
                    title: "Speaker",
                    systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic",
                    isOn: viewModel.isSpeakerMode,
                    action: { viewModel.toggleSpeakerMode() }
                )

                modeToggleRow(
                    title: "PPT",
                    systemName: viewModel.isPageInterceptEnabled ? "hand.raised.fill" : "hand.raised.slash",
                    isOn: viewModel.isPageInterceptEnabled,
                    action: { viewModel.isPageInterceptEnabled.toggle() }
                )
            }
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
        .tint(StudioTheme.actionPrimary)
        .controlSize(.small)
        .disabled(viewModel.currentBGMItem == nil)
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
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(kind == .live || kind == .fail ? StudioTheme.statusColor(kind).opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
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
        .background(StudioTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
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
                .frame(width: 28, height: 24)
                .background(StudioTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .accessibilityHint(hint ?? "BGM transport control")
    }

    private func modeToggleRow(
        title: String,
        systemName: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isOn ? StudioTheme.statusWarn : StudioTheme.textSecondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(isOn ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(isOn ? StudioTheme.statusWarn : StudioTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .frame(height: 28)
            .background(StudioTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func outputActionFill(_ model: ProjectionButtonModel) -> Color {
        if model.isBroadcasting { return StudioTheme.statusLive }
        return model.hasExternalDisplay ? StudioTheme.actionPrimary : StudioTheme.statusMuted
    }

    private var audioStatusText: String {
        if viewModel.isPanicMode { return "MUTED" }
        if viewModel.isBGMAudioTakeoverActive { return "BGM TAKEOVER" }
        if viewModel.isSpeakerMode { return "SPEAKER" }
        return "NORMAL"
    }

    private var audioStatusKind: StudioTheme.StatusKind {
        if viewModel.isPanicMode { return .fail }
        if viewModel.isBGMAudioTakeoverActive || viewModel.isSpeakerMode { return .warn }
        return .ready
    }

    private var modesStatusText: String {
        viewModel.isSpeakerMode || viewModel.isPageInterceptEnabled ? "ACTIVE" : "OFF"
    }

    private var modesStatusKind: StudioTheme.StatusKind {
        viewModel.isSpeakerMode || viewModel.isPageInterceptEnabled ? .warn : .idle
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
