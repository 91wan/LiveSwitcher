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
        VStack(alignment: .leading, spacing: 18) {
            panelHeader
            lowerThirdSection
            countdownSection
            tickerSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                statusBadge(
                    title: activeOverlayCount == 0 ? "全部关闭" : "\(activeOverlayCount) 个上屏",
                    isLive: hasActiveOverlay
                )

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
                                .fill(hasActiveOverlay ? Color.red : Color.black.opacity(0.06))
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
                        fill: .red,
                        isDisabled: viewModel.isLowerThirdVisible || trimmedLowerThirdName.isEmpty
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showLowerThird(name: ltNameInput, title: ltTitleInput)
                        }
                    }

                    overlayActionButton(
                        title: "退场",
                        systemImage: "arrow.down.to.line",
                        fill: .gray,
                        isDisabled: !viewModel.isLowerThirdVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissLowerThird()
                        }
                    }
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
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "开始",
                        systemImage: "play.fill",
                        fill: .orange,
                        isDisabled: viewModel.isCountdownActive || countdownTotalSeconds <= 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startCountdown(seconds: countdownTotalSeconds, title: countdownTitleInput)
                        }
                    }

                    overlayActionButton(
                        title: "停止",
                        systemImage: "stop.fill",
                        fill: .gray,
                        isDisabled: !viewModel.isCountdownActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopCountdown()
                        }
                    }
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
                    .background(Color.white.opacity(0.68))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
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
                        fill: .purple,
                        isDisabled: viewModel.isTickerActive || trimmedTickerText.isEmpty
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startTicker(text: tickerInput)
                        }
                    }

                    overlayActionButton(
                        title: "停止",
                        systemImage: "stop.fill",
                        fill: .gray,
                        isDisabled: !viewModel.isTickerActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopTicker()
                        }
                    }
                }
            }
        }
    }

    private var currentLowerThirdPreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.lowerThirdName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !viewModel.lowerThirdTitle.isEmpty {
                    Text(viewModel.lowerThirdTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("LIVE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.green)
        }
        .padding(10)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
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
                    .foregroundStyle(.primary)
                Spacer()
                statusBadge(title: isLive ? "LIVE" : "OFF", isLive: isLive)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isLive ? Color.green.opacity(0.30) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func statusBadge(title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? Color.green : Color.gray.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(isLive ? Color.green : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isLive ? Color.green.opacity(0.12) : Color.black.opacity(0.05))
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
                .foregroundStyle(.secondary)
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDisabled ? Color.gray.opacity(0.45) : fill)
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
