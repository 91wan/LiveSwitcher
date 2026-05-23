import SwiftUI

struct AudioMixerView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    private var pageModel: AudioMixerPageModel {
        AudioMixerPageModel(
            masterVolume: viewModel.masterVolume,
            mediaVolume: viewModel.mediaVolume,
            mediaEffectiveVolume: Double(viewModel.effectiveMediaOutputVolume()),
            bgmVolume: viewModel.bgmVolume,
            bgmEffectiveVolume: Double(viewModel.effectiveBGMOutputVolume()),
            strategy: viewModel.audioStrategy,
            isPanicMode: viewModel.isPanicMode,
            isSpeakerMode: viewModel.isSpeakerMode,
            isBGMAudioTakeoverActive: viewModel.isBGMAudioTakeoverActive
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader
                audioSummaryRow

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 18) {
                            mixerSection
                            routingStrategyCard
                            transitionCard
                        }
                        .frame(minWidth: 430, idealWidth: 500, maxWidth: 560)

                        BGMLibraryCard()
                            .frame(minWidth: 360, idealWidth: 430, maxWidth: .infinity)
                    }

                    VStack(spacing: 18) {
                        mixerSection
                        routingStrategyCard
                        transitionCard
                        BGMLibraryCard()
                    }
                }
            }
            .frame(maxWidth: 1180, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio / 音频")
                .font(StudioTheme.titleLarge())
                .foregroundStyle(StudioTheme.textPrimary)
            Text("Mixer、routing strategy 和 BGM library 分区管理；每个推子同时显示用户值和实际输出。")
                .font(StudioTheme.body())
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private var audioSummaryRow: some View {
        HStack(spacing: 12) {
            MetricRow(title: "Master", value: percent(pageModel.masterVolume), subtitle: "User fader", kind: .idle)
            Divider().frame(height: 32)
            MetricRow(title: "Media effective", value: percent(pageModel.mediaEffectiveVolume), subtitle: "Actual output", kind: pageModel.mediaEffectiveVolume == 0 ? .muted : .ready)
            Divider().frame(height: 32)
            MetricRow(title: "BGM effective", value: percent(pageModel.bgmEffectiveVolume), subtitle: "Actual output", kind: pageModel.bgmEffectiveVolume == 0 ? .muted : .ready)
            Divider().frame(height: 32)
            MetricRow(title: "Routing", value: pageModel.routingStatusText, subtitle: pageModel.channelLimitText, kind: pageModel.routingStatusKind)
        }
        .padding(14)
        .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audio summary. Master \(percent(pageModel.masterVolume)). Media effective \(percent(pageModel.mediaEffectiveVolume)). BGM effective \(percent(pageModel.bgmEffectiveVolume)). Routing \(pageModel.routingStatusText).")
    }

    private var mixerSection: some View {
        StudioSectionCard(
            title: "Mixer",
            subtitle: "用户推子与实际输出",
            status: ("3 FADERS", .idle)
        ) {
            VStack(spacing: 10) {
                MixerFaderCard(
                    title: "Master",
                    subtitle: "Global output",
                    value: $viewModel.masterVolume,
                    userValue: viewModel.masterVolume,
                    effectiveValue: viewModel.masterVolume,
                    tint: StudioTheme.actionPrimary
                )
                MixerFaderCard(
                    title: "Media",
                    subtitle: mediaFaderSubtitle,
                    value: $viewModel.mediaVolume,
                    userValue: viewModel.mediaVolume,
                    effectiveValue: pageModel.mediaEffectiveVolume,
                    tint: StudioTheme.actionPrimary
                )
                MixerFaderCard(
                    title: "BGM",
                    subtitle: bgmFaderSubtitle,
                    value: $viewModel.bgmVolume,
                    userValue: viewModel.bgmVolume,
                    effectiveValue: pageModel.bgmEffectiveVolume,
                    tint: StudioTheme.pink
                )
            }
        }
    }

    private var routingStrategyCard: some View {
        RoutingStrategyCard(
            strategy: audioStrategy,
            statusText: pageModel.routingStatusText,
            statusKind: pageModel.routingStatusKind,
            impactText: pageModel.routingImpactText,
            channelLimitText: pageModel.channelLimitText,
            strategySummary: audioStrategySummary
        )
    }

    private var transitionCard: some View {
        let model = ProgramTransitionControlModel(crossfadeDuration: viewModel.crossfadeDuration)

        return StudioSectionCard(
            title: model.title,
            subtitle: model.subtitle,
            status: (model.statusText, .idle)
        ) {
            HStack(spacing: 10) {
                Text(model.currentValueText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                Slider(value: $viewModel.crossfadeDuration, in: 0.5...3.0, step: 0.1)
                    .tint(StudioTheme.statusWarn)
                    .accessibilityLabel("Program transition duration")
                    .accessibilityValue(model.currentValueText)
                Text("0.5s-3.0s")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }
        }
    }

    private var audioStrategy: Binding<AudioStrategy> {
        Binding(
            get: { viewModel.audioStrategy },
            set: { viewModel.audioStrategy = $0 }
        )
    }

    private var audioStrategySummary: String {
        switch viewModel.audioStrategy {
        case .followProgram:
            return "有媒体节目正在播时走节目声；停播或切到无声源时回到 BGM。"
        case .followSource:
            return "严格跟随当前节目源；无媒体声时保持静音，不自动回落到 BGM。"
        case .bgmOnly:
            return "只保留 BGM，媒体通道静音，适合暖场或纯氛围输出。"
        case .mixed:
            return "媒体与 BGM 同时输出，分别受各自推子控制。"
        }
    }

    private var mediaFaderSubtitle: String {
        if viewModel.isPanicMode { return "Muted by Panic" }
        if viewModel.isBGMAudioTakeoverActive { return "Muted by BGM takeover" }
        if viewModel.isSpeakerMode { return "Ducked by Speaker mode" }
        return "Program/media channel"
    }

    private var bgmFaderSubtitle: String {
        if viewModel.isPanicMode { return "Muted by Panic" }
        if viewModel.isSpeakerMode { return "Ducked by Speaker mode" }
        return "Background music channel"
    }

    private func percent(_ value: Double) -> String {
        "\(Int((max(0, min(value, 1)) * 100).rounded()))%"
    }
}

private struct MixerFaderCard: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let userValue: Double
    let effectiveValue: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 10) {
                    valuePair(label: "User", value: userValue, tint: tint)
                    valuePair(label: "Effective", value: effectiveValue, tint: effectiveValue == 0 ? StudioTheme.statusMuted : tint)
                }
            }

            Slider(value: $value, in: 0...1)
                .tint(tint)
                .accessibilityLabel("\(title) volume")
                .accessibilityValue("User \(percent(userValue)), effective \(percent(effectiveValue))")
        }
        .padding(12)
        .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    private func valuePair(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.textTertiary)
            Text(percent(value))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((max(0, min(value, 1)) * 100).rounded()))%"
    }
}

private struct RoutingStrategyCard: View {
    @Binding var strategy: AudioStrategy
    let statusText: String
    let statusKind: StudioTheme.StatusKind
    let impactText: String
    let channelLimitText: String
    let strategySummary: String

    var body: some View {
        StudioSectionCard(
            title: "Routing Strategy",
            subtitle: "输出策略与现场限制",
            status: (statusText, statusKind)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: $strategy) {
                    ForEach(AudioStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Audio routing strategy")

                Text(strategySummary)
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                InlineWarningBanner(
                    title: channelLimitText,
                    message: impactText,
                    kind: statusKind
                )
            }
        }
    }
}

private struct BGMLibraryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("BGM Library")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                StatusBadge("LIBRARY", kind: .idle)
            }
            Text("分类、曲目列表、添加、删除和排序集中在音频页管理。")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
            BGMPlaylistPanel()
        }
    }
}
