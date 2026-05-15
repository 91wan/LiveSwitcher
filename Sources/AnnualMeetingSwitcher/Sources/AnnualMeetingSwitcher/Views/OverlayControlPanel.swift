import SwiftUI

// MARK: - 叠层控制面板

struct OverlayControlPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    @State private var countdownMinutes = 10
    @State private var countdownSecs = 0
    @State private var countdownTitleInput = "活动即将开始"

    @State private var tickerInput = "Welcome · The program will begin shortly"
    @State private var tickerSpeedIndex = 1

    @State private var ltNameInput = ""
    @State private var ltTitleInput = ""

    private let tickerSpeeds: [(String, Double)] = [
        ("慢", 55), ("中", 85), ("快", 130)
    ]

    private var trimmedLowerThirdName: String {
        ltNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedTickerText: String {
        tickerInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var countdownTotalSeconds: Int {
        countdownMinutes * 60 + countdownSecs
    }

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
                controlsColumn
                    .frame(minWidth: 440, maxWidth: 560)
                livePreviewColumn
                    .frame(minWidth: 320, maxWidth: 420)
            }

            VStack(alignment: .leading, spacing: 18) {
                controlsColumn
                livePreviewColumn
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: 18, x: 0, y: 10)
    }

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader
            lowerThirdSection
            countdownSection
            tickerSection
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .fill(StudioTheme.accent.opacity(0.12))
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(StudioTheme.accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text("叠层控制")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                Text("人名条、倒计时和游动字幕会直接叠加到输出大屏。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatusBadge(activeOverlayCount == 0 ? "OFF" : "\(activeOverlayCount) LIVE", kind: hasActiveOverlay ? .live : .idle)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.clearAllOverlays()
                    }
                } label: {
                    Text("全部下屏 / Clear all")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(hasActiveOverlay ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(hasActiveOverlay ? StudioTheme.actionDanger : StudioTheme.surfaceSecondary)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasActiveOverlay)
            }
        }
    }

    private var lowerThirdSection: some View {
        overlaySection(
            title: "人名条（Lower Third）",
            systemImage: "person.text.rectangle",
            isLive: viewModel.isLowerThirdVisible
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("嘉宾姓名", text: $ltNameInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                TextField("职务 / 单位（可留空）", text: $ltTitleInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "上屏",
                        systemImage: "arrow.up.to.line",
                        fill: StudioTheme.statusLive,
                        isDisabled: viewModel.isLowerThirdVisible || trimmedLowerThirdName.isEmpty
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showLowerThird(name: ltNameInput, title: ltTitleInput)
                        }
                    }

                    overlayActionButton(
                        title: "退场",
                        systemImage: "arrow.down.to.line",
                        fill: StudioTheme.actionSecondary,
                        isDisabled: !viewModel.isLowerThirdVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissLowerThird()
                        }
                    }
                }

                if let reason = OverlayUIState.lowerThirdDisabledReason(name: ltNameInput, isLive: viewModel.isLowerThirdVisible) {
                    Text(reason)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }

                if viewModel.isLowerThirdVisible {
                    currentLowerThirdPreview
                }
            }
        }
    }

    private var countdownSection: some View {
        overlaySection(
            title: "倒计时",
            systemImage: "timer",
            isLive: viewModel.isCountdownActive
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("标题（如：活动即将开始）", text: $countdownTitleInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                HStack(spacing: 8) {
                    numberInput(title: "分", value: $countdownMinutes)
                    Text(":")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                    numberInput(title: "秒", value: $countdownSecs)
                    Spacer()
                    if viewModel.isCountdownActive {
                        Text("剩余 \(formattedTime(viewModel.countdownSeconds))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(StudioTheme.statusWarn)
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "开始",
                        systemImage: "play.fill",
                        fill: StudioTheme.statusWarn,
                        isDisabled: viewModel.isCountdownActive || countdownTotalSeconds <= 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startCountdown(seconds: countdownTotalSeconds, title: countdownTitleInput)
                        }
                    }

                    overlayActionButton(
                        title: "停止",
                        systemImage: "stop.fill",
                        fill: StudioTheme.actionSecondary,
                        isDisabled: !viewModel.isCountdownActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopCountdown()
                        }
                    }
                }

                if let reason = OverlayUIState.countdownDisabledReason(totalSeconds: countdownTotalSeconds, isLive: viewModel.isCountdownActive) {
                    Text(reason)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
            }
        }
    }

    private var tickerSection: some View {
        overlaySection(
            title: "游动字幕",
            systemImage: "text.badge.star",
            isLive: viewModel.isTickerActive
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $tickerInput)
                    .font(.system(size: 13))
                    .frame(height: 76)
                    .padding(6)
                    .background(StudioTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .stroke(StudioTheme.borderSubtle, lineWidth: 1)
                    )

                HStack {
                    Text("速度")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $tickerSpeedIndex) {
                        ForEach(0..<tickerSpeeds.count, id: \.self) { index in
                            Text(tickerSpeeds[index].0).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: tickerSpeedIndex) { _, index in
                        viewModel.tickerSpeed = tickerSpeeds[index].1
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "开始",
                        systemImage: "play.fill",
                        fill: StudioTheme.pink,
                        isDisabled: viewModel.isTickerActive || trimmedTickerText.isEmpty
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startTicker(text: tickerInput)
                        }
                    }

                    overlayActionButton(
                        title: "停止",
                        systemImage: "stop.fill",
                        fill: StudioTheme.actionSecondary,
                        isDisabled: !viewModel.isTickerActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopTicker()
                        }
                    }
                }

                if let reason = OverlayUIState.tickerDisabledReason(text: tickerInput, isLive: viewModel.isTickerActive) {
                    Text(reason)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                }
            }
        }
    }

    private var livePreviewColumn: some View {
        StudioSectionCard(
            title: "Live Overlay Preview",
            subtitle: "上屏前确认位置和当前状态",
            status: (hasActiveOverlay ? "\(activeOverlayCount) LIVE" : "OFF", hasActiveOverlay ? .live : .idle)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                        .fill(StudioTheme.monitorSurfaceBottom.opacity(0.95))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)

                    VStack {
                        tickerPreview
                        Spacer()
                        countdownPreview
                        Spacer()
                        lowerThirdPreview
                    }
                    .padding(18)
                }

                VStack(alignment: .leading, spacing: 8) {
                    activeOverlaySummaryRow(title: "Lower Third", isLive: viewModel.isLowerThirdVisible)
                    activeOverlaySummaryRow(title: "Countdown", isLive: viewModel.isCountdownActive)
                    activeOverlaySummaryRow(title: "Ticker", isLive: viewModel.isTickerActive)
                }
            }
        }
    }

    private var tickerPreview: some View {
        Text(trimmedTickerText.isEmpty ? "Ticker preview" : trimmedTickerText)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(viewModel.isTickerActive || !trimmedTickerText.isEmpty ? .white : .white.opacity(0.45))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countdownPreview: some View {
        Text(formattedTime(viewModel.isCountdownActive ? viewModel.countdownSeconds : countdownTotalSeconds))
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(countdownTotalSeconds > 0 || viewModel.isCountdownActive ? .white : .white.opacity(0.45))
    }

    private var lowerThirdPreview: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trimmedLowerThirdName.isEmpty ? "Lower third name" : trimmedLowerThirdName)
                    .font(.system(size: 13, weight: .black))
                Text(ltTitleInput.isEmpty ? "Title / organization" : ltTitleInput)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.78)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(StudioTheme.statusLive.opacity(viewModel.isLowerThirdVisible || !trimmedLowerThirdName.isEmpty ? 0.72 : 0.25), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
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

    private var currentLowerThirdPreview: some View {
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(StudioTheme.statusLive)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.lowerThirdName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                if !viewModel.lowerThirdTitle.isEmpty {
                    Text(viewModel.lowerThirdTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("LIVE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.statusLive)
        }
        .padding(10)
        .background(StudioTheme.statusLive.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.statusLive.opacity(0.18), lineWidth: 1)
        )
    }

    private func overlaySection<Content: View>(
        title: String,
        systemImage: String,
        isLive: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                statusBadge(title: isLive ? "LIVE" : "OFF", isLive: isLive)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(isLive ? StudioTheme.borderCritical.opacity(0.50) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func statusBadge(title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? StudioTheme.statusLive : StudioTheme.statusIdle.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(isLive ? StudioTheme.statusLive : StudioTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isLive ? StudioTheme.statusLive.opacity(0.12) : StudioTheme.surfaceSecondary)
        )
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .fill(isDisabled ? StudioTheme.statusMuted.opacity(0.45) : fill)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
