import SwiftUI

// MARK: - 叠层控制面板

struct OverlayControlPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    private var activeOverlayCount: Int {
        [
            viewModel.isLowerThirdVisible,
            viewModel.isCountdownActive,
            viewModel.isTickerActive
        ].filter { $0 }.count
    }

    private var hasActiveOverlay: Bool {
        activeOverlayCount > 0
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                composerColumn
                    .frame(minWidth: 420, maxWidth: 560)
                livePreviewColumn
                    .frame(minWidth: 360, maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 18) {
                composerColumn
                livePreviewColumn
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: 18, x: 0, y: 10)
        .onAppear {
            syncTickerSpeedFromViewModel()
        }
        .onChange(of: viewModel.tickerSpeed) { _, _ in
            syncTickerSpeedFromViewModel()
        }
    }

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    private func composerBinding<Value>(_ keyPath: WritableKeyPath<OverlayComposerState, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.overlayComposerState[keyPath: keyPath] },
            set: { viewModel.overlayComposerState[keyPath: keyPath] = $0 }
        )
    }

    private var composerColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            composerPicker
            activeComposerCard
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .fill(StudioTheme.Action.primary.opacity(0.12))
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(StudioTheme.Action.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text("Overlay Composer")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(.primary)
                Text("一次准备一种叠层；Preview 和 Active Stack 会显示当前上屏状态。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(activeOverlayCount == 0 ? "OFF" : "\(activeOverlayCount) LIVE", kind: hasActiveOverlay ? .live : .idle)
        }
    }

    private var composerPicker: some View {
        Picker("Overlay composer", selection: composerBinding(\.selectedKind)) {
            ForEach(OverlayComposerKind.allCases) { kind in
                Label(kind.pickerTitle, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: composerState.selectedKind) { _, newKind in
            viewModel.overlayComposerState.select(newKind)
        }
        .accessibilityLabel("Overlay composer")
    }

    @ViewBuilder
    private var activeComposerCard: some View {
        switch composerState.selectedKind {
        case .lowerThird:
            lowerThirdEditor
        case .countdown:
            countdownEditor
        case .ticker:
            tickerEditor
        }
    }

    private var lowerThirdEditor: some View {
        overlaySection(
            kind: .lowerThird,
            isLive: viewModel.isLowerThirdVisible,
            disabledReason: OverlayUIState.lowerThirdDisabledReason(
                name: composerState.lowerThirdNameDraft,
                isLive: viewModel.isLowerThirdVisible
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("嘉宾姓名", text: composerBinding(\.lowerThirdNameDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                TextField("职务 / 单位（可留空）", text: composerBinding(\.lowerThirdTitleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "arrow.up.to.line",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.lowerThirdDisabledReason(
                            name: composerState.lowerThirdNameDraft,
                            isLive: viewModel.isLowerThirdVisible
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showLowerThird(
                                name: composerState.lowerThirdNameDraft,
                                title: composerState.lowerThirdTitleDraft
                            )
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "arrow.down.to.line",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isLowerThirdVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissLowerThird()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.lowerThirdDisabledReason(
                        name: composerState.lowerThirdNameDraft,
                        isLive: viewModel.isLowerThirdVisible
                    )
                )
            }
        }
    }

    private var countdownEditor: some View {
        overlaySection(
            kind: .countdown,
            isLive: viewModel.isCountdownActive,
            disabledReason: OverlayUIState.countdownDisabledReason(
                minutes: composerState.countdownMinutesDraft,
                seconds: composerState.countdownSecondsDraft,
                isLive: viewModel.isCountdownActive
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("标题（如：活动即将开始）", text: composerBinding(\.countdownTitleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                HStack(spacing: 8) {
                    numberInput(title: "分", value: composerBinding(\.countdownMinutesDraft))
                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                    numberInput(title: "秒", value: composerBinding(\.countdownSecondsDraft))
                    Spacer()
                    if viewModel.isCountdownActive {
                        Text("剩余 \(formattedTime(viewModel.countdownSeconds))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(StudioTheme.Tone.warn)
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "play.fill",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.countdownDisabledReason(
                            minutes: composerState.countdownMinutesDraft,
                            seconds: composerState.countdownSecondsDraft,
                            isLive: viewModel.isCountdownActive
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startCountdown(
                                minutes: composerState.countdownMinutesDraft,
                                seconds: composerState.countdownSecondsDraft,
                                title: composerState.countdownTitleDraft
                            )
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isCountdownActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopCountdown()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.countdownDisabledReason(
                        minutes: composerState.countdownMinutesDraft,
                        seconds: composerState.countdownSecondsDraft,
                        isLive: viewModel.isCountdownActive
                    )
                )
            }
        }
    }

    private var tickerEditor: some View {
        overlaySection(
            kind: .ticker,
            isLive: viewModel.isTickerActive,
            disabledReason: OverlayUIState.tickerDisabledReason(
                text: composerState.tickerTextDraft,
                isLive: viewModel.isTickerActive
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: composerBinding(\.tickerTextDraft))
                    .font(.system(size: 13))
                    .frame(height: 76)
                    .padding(6)
                    .background(StudioTheme.Surface.raised)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .stroke(StudioTheme.borderSubtle, lineWidth: 1)
                    )

                HStack {
                    Text("速度")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: composerBinding(\.tickerSpeedIndex)) {
                        ForEach(OverlaySpeedSelection.options.indices, id: \.self) { index in
                            Text(OverlaySpeedSelection.label(at: index)).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: composerState.tickerSpeedIndex) { _, index in
                        viewModel.tickerSpeed = OverlaySpeedSelection.speed(at: index)
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "play.fill",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.tickerDisabledReason(
                            text: composerState.tickerTextDraft,
                            isLive: viewModel.isTickerActive
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startTicker(text: composerState.tickerTextDraft)
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isTickerActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopTicker()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.tickerDisabledReason(
                        text: composerState.tickerTextDraft,
                        isLive: viewModel.isTickerActive
                    )
                )
            }
        }
    }

    private var livePreviewColumn: some View {
        let previewModel = livePreviewModel
        let isEmptyPreview = previewModel.layers.isEmpty

        return StudioSectionCard(
            title: "Live Preview",
            subtitle: "16:9 preview and active overlay stack",
            status: (hasActiveOverlay ? "\(activeOverlayCount) LIVE" : "OFF", hasActiveOverlay ? .live : .idle)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OverlayLivePreviewCanvas(model: previewModel)
                    .frame(maxWidth: isEmptyPreview ? 320 : .infinity)
                    .frame(height: isEmptyPreview ? 180 : nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                activeStackCard
            }
        }
    }

    private var activeStackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Active Stack")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.clearAllOverlays()
                    }
                } label: {
                    Label("Clear All", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!hasActiveOverlay)
            }

            activeOverlaySummaryRow(title: "Lower Third", isLive: viewModel.isLowerThirdVisible)
            activeOverlaySummaryRow(title: "Countdown", isLive: viewModel.isCountdownActive)
            activeOverlaySummaryRow(title: "Ticker", isLive: viewModel.isTickerActive)
        }
        .padding(12)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
    }

    private var livePreviewModel: OverlayLivePreviewModel {
        OverlayLivePreviewModel.make(
            isLowerThirdVisible: viewModel.isLowerThirdVisible,
            lowerThirdName: viewModel.lowerThirdName,
            lowerThirdTitle: viewModel.lowerThirdTitle,
            isCountdownActive: viewModel.isCountdownActive,
            countdownSeconds: viewModel.countdownSeconds,
            countdownTitle: viewModel.countdownTitle,
            isTickerActive: viewModel.isTickerActive,
            tickerText: viewModel.tickerText,
            composerState: composerState
        )
    }

    private func activeOverlaySummaryRow(title: String, isLive: Bool) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            StatusBadge(isLive ? "LIVE" : "OFF", kind: isLive ? .live : .idle)
        }
    }

    private func overlaySection<Content: View>(
        kind: OverlayComposerKind,
        isLive: Bool,
        disabledReason: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(kind.title, systemImage: kind.systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                statusBadge(title: composerStatusText(isLive: isLive, disabledReason: disabledReason), isLive: isLive)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(isLive ? StudioTheme.borderCritical.opacity(0.50) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func composerStatusText(isLive: Bool, disabledReason: String?) -> String {
        if isLive { return "LIVE" }
        if disabledReason == nil { return "READY" }
        return "DRAFT"
    }

    private func statusBadge(title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? StudioTheme.Tone.live : StudioTheme.Tone.idle.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(isLive ? StudioTheme.Tone.live : StudioTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isLive ? StudioTheme.Tone.live.opacity(0.12) : StudioTheme.Surface.raised)
        )
    }

    @ViewBuilder
    private func disabledReasonText(_ reason: String?) -> some View {
        if let reason {
            Text(reason)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
    }

    private func numberInput(title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func overlayActionButton(
        title: String,
        systemImage: String,
        fill: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isDisabled ? .white.opacity(0.55) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .fill(isDisabled ? fill.opacity(0.25) : fill)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "This overlay action is currently unavailable." : "Run overlay action.")
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func syncTickerSpeedFromViewModel() {
        let index = OverlaySpeedSelection.nearestIndex(for: viewModel.tickerSpeed)
        viewModel.overlayComposerState.tickerSpeedIndex = index
        let normalizedSpeed = OverlaySpeedSelection.speed(at: index)
        if viewModel.tickerSpeed != normalizedSpeed {
            viewModel.tickerSpeed = normalizedSpeed
        }
    }
}
