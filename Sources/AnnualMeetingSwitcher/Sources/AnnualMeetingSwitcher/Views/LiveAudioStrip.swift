import SwiftUI

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

