import SwiftUI
import UniformTypeIdentifiers

// MARK: - 音频策略枚举

enum AudioStrategy: String, CaseIterable {
    case followProgram
    case followSource
    case bgmOnly
    case mixed

    init?(persistedValue: String) {
        if let strategy = AudioStrategy(rawValue: persistedValue) {
            self = strategy
            return
        }

        switch persistedValue {
        case "音频跟随":
            self = .followProgram
        case "跟随源":
            self = .followSource
        case "仅 BGM":
            self = .bgmOnly
        case "混合":
            self = .mixed
        default:
            return nil
        }
    }

    var displayTitle: String {
        switch self {
        case .followProgram:
            return "音频跟随"
        case .followSource:
            return "跟随源"
        case .bgmOnly:
            return "仅 BGM"
        case .mixed:
            return "混合"
        }
    }
}

// MARK: - BGM 分类

enum BGMCategory: String, CaseIterable {
    case warmUp   = "暖场音乐"
    case entrance = "上场音乐"
    case award    = "颁奖音乐"
    case ambient  = "氛围音乐"
    case halftime = "中场音乐"
    case exit     = "退场音乐"
}

// MARK: - 右侧调音与音乐面板（壁纸库已移除至中栏，Issue #3）

enum RightPanelMode {
    case liveQuick
    case fullMixer
}

struct RightPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    let mode: RightPanelMode
    let onOpenMixer: (() -> Void)?

    init(mode: RightPanelMode = .fullMixer, onOpenMixer: (() -> Void)? = nil) {
        self.mode = mode
        self.onOpenMixer = onOpenMixer
    }

    var body: some View {
        Group {
            if mode == .liveQuick {
                panelContent
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    panelContent
                }
            }
        }
        .frame(
            minWidth: mode == .liveQuick ? 0 : 280,
            idealWidth: mode == .liveQuick ? 312 : 292,
            maxWidth: mode == .liveQuick ? .infinity : 310
        )
        .studioCard(cornerRadius: 28)
    }

    private var panelContent: some View {
        VStack(spacing: mode == .liveQuick ? 10 : 14) {
            // ── 主音量卡片（Issue #7: 联控 AVPlayer + BGM）──
            masterVolumeCard

            if mode == .fullMixer {
                // ── 音频策略选择器 ──
                audioStrategyCard
            } else {
                quickMixStatusCard
            }

            // ── 通道音量（Issue #8: 真实挂载到音频节点）──
            channelVolumeCard
            // （V20：背景音乐列表已移至独立的音乐播放列表面板）
        }
        .padding(.bottom, mode == .liveQuick ? 8 : 12)
    }

    // MARK: - 主音量卡片（Issue #7: 联控 AVPlayer + BGM）

    private var masterVolumeCard: some View {
        let compact = mode == .liveQuick

        return VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                Text("MASTER")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Text("主音量")
                    .font(compact ? StudioTheme.sectionTitle() : StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: compact ? 16 : 18, weight: .semibold))
                        .foregroundStyle(StudioTheme.actionPrimary)
                    Text("\(Int(viewModel.masterVolume * 100))%")
                        .font(.system(size: compact ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioTheme.actionPrimary)
                }
            }

            Slider(value: $viewModel.masterVolume, in: 0...1)
                .tint(StudioTheme.actionPrimary)
                .frame(height: compact ? 22 : 26)
                .accessibilityLabel("Master volume")
                .accessibilityValue("\(Int(viewModel.masterVolume * 100)) percent")
        }
        .padding(.horizontal, compact ? 16 : 18)
        .padding(.vertical, compact ? 14 : 18)
        .background(Color.clear)
    }

    // MARK: - 音频策略

    private var audioStrategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("混音策略")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                strategyPill
            }

            Picker("", selection: audioStrategy) {
                ForEach(AudioStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.displayTitle).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(audioStrategySummary)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var quickMixStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("现场快调")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("当前策略")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textSecondary)
                }
                Spacer()
                strategyPill
            }

            if let onOpenMixer {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onOpenMixer()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("打开音频混音页")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(StudioTheme.actionPrimary)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open audio mixer page")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - 通道音量（Issue #8: 真实挂载到音频节点，不是空壳变量）

    private var channelVolumeCard: some View {
        let compact = mode == .liveQuick

        return VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            channelVolumeTitle(compact: compact)
            mixerFader(
                title: "源 A",
                subtitle: viewModel.isSpeakerMode ? "主讲人压限中" : "媒体",
                value: $viewModel.mediaVolume,
                tint: StudioTheme.actionPrimary
            )

            mixerFader(
                title: "BGM",
                subtitle: viewModel.isSpeakerMode ? "主讲人压限中" : "背景音乐",
                value: $viewModel.bgmVolume,
                tint: StudioTheme.pink
            )

            SpeakerModeStatusRow(viewModel: viewModel, compact: compact)
        }
        .padding(compact ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .fill(StudioTheme.surfacePrimary.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func channelVolumeTitle(compact: Bool) -> some View {
        Text("现场推子")
            .font(compact ? StudioTheme.sectionTitle() : StudioTheme.title())
            .foregroundStyle(StudioTheme.textPrimary)
    }



}

private extension RightPanel {
    var audioStrategy: Binding<AudioStrategy> {
        Binding(
            get: { viewModel.audioStrategy },
            set: { viewModel.audioStrategy = $0 }
        )
    }

    var audioStrategySummary: String {
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

    var strategyPill: some View {
        Text(viewModel.audioStrategy.displayTitle)
            .font(StudioTheme.statusLabel())
            .foregroundStyle(StudioTheme.actionPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(StudioTheme.actionPrimary.opacity(0.10), in: Capsule())
    }

    func mixerFader(
        title: String,
        subtitle: String,
        value: Binding<Double>,
        tint: Color
    ) -> some View {
        let compact = mode == .liveQuick

        return VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                    Text(title)
                        .font(.system(size: compact ? 16 : 17, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: compact ? 21 : 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Slider(value: value, in: 0...1)
                .tint(tint)
                .frame(height: compact ? 20 : 24)
                .accessibilityLabel("\(title) volume")
                .accessibilityValue("\(Int(value.wrappedValue * 100)) percent")
        }
        .padding(compact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(tint.opacity(0.06))
        )
    }
}

private struct SpeakerModeStatusRow: View {
    @ObservedObject var viewModel: SwitcherViewModel
    let compact: Bool

    var body: some View {
        Button(action: {
            viewModel.toggleSpeakerMode()
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(viewModel.isSpeakerMode ? StudioTheme.statusWarn : StudioTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("主讲人状态")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text(viewModel.isSpeakerMode ? "顶部主控已开启 · 声道 7%" : "从顶部主控一键开启")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                Spacer()

                statusPill
            }
            .padding(.horizontal, 12)
            .padding(.vertical, compact ? 9 : 10)
            .frame(maxWidth: .infinity)
            .background(rowBackground)
            .overlay(rowBorder)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(viewModel.isSpeakerMode ? "关闭主讲人模式并恢复媒体声道和 BGM" : "开启主讲人模式，媒体声道和 BGM 压低至 7%")
        .accessibilityLabel("Speaker mode status")
        .accessibilityValue(viewModel.isSpeakerMode ? "On" : "Off")
        .padding(.top, compact ? 4 : 10)
    }

    private var statusPill: some View {
        Text(viewModel.isSpeakerMode ? "ON" : "切换")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(viewModel.isSpeakerMode ? StudioTheme.statusWarn : StudioTheme.actionPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((viewModel.isSpeakerMode ? StudioTheme.statusWarn : StudioTheme.actionPrimary).opacity(0.1), in: Capsule())
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
            .fill(StudioTheme.surfacePrimary.opacity(0.70))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
            .stroke((viewModel.isSpeakerMode ? StudioTheme.statusWarn : StudioTheme.borderSubtle).opacity(0.44), lineWidth: 1)
    }
}

// MARK: - Issue #8: 通道音量行（真实绑定）

struct LargeChannelFaderRow: View {
    let label: String
    @Binding var value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                // Issue #6: 放大
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 50, alignment: .leading)

            Slider(value: $value, in: 0...1)
                .tint(color)
                .frame(height: 22)
                .accessibilityLabel("\(label) channel volume")
                .accessibilityValue("\(Int(value * 100)) percent")

            Text("\(Int(value * 100))")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - BGM 曲目行（Issue #6: 文字放大）
// V24 Fix #1: isCurrentTrack 不依赖 isBGMPlaying，暂停时高亮依然保持

struct BGMItemRow: View {
    let bgm: BGMItem
    @ObservedObject var viewModel: SwitcherViewModel
    var compact: Bool = false
    @State private var isHovered = false

    /// V24 Fix #1: 只要是当前曲目就高亮，不管播放还是暂停
    var isCurrentTrack: Bool {
        viewModel.currentBGMItem?.id == bgm.id
    }

    var isPlaying: Bool {
        isCurrentTrack && viewModel.isBGMPlaying
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isPlaying ? "waveform" : (isCurrentTrack ? "pause.fill" : "music.note"))
                .font(.system(size: 16))
                .foregroundStyle(isCurrentTrack ? StudioTheme.actionPrimary : StudioTheme.textSecondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                // Issue #6: .title3 或更大
                Text(bgm.title)
                    .font(compact ? .system(size: 14, weight: .semibold) : .title3)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundStyle(isCurrentTrack ? StudioTheme.actionPrimary : StudioTheme.textPrimary)
                    .lineLimit(1)
                Text(bgm.category.rawValue)
                    .font(.system(size: compact ? 11 : 12))
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: compact ? 8 : 10) {
                // Issue #6: 按钮也放大
                Button(action: { viewModel.toggleBGM(bgm) }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 14 : 16))
                        .foregroundStyle(isCurrentTrack ? StudioTheme.actionPrimary : StudioTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "暂停" : "播放")
                .accessibilityLabel(isPlaying ? "Pause \(bgm.title)" : "Play \(bgm.title)")

                Button(action: { viewModel.removeBGMItem(bgm) }) {
                    Image(systemName: "trash")
                        .font(.system(size: compact ? 13 : 14))
                        .foregroundStyle(isHovered ? StudioTheme.actionDanger : StudioTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("删除")
                .accessibilityLabel("Delete \(bgm.title)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 6 : 8)
        .background(isCurrentTrack ? StudioTheme.actionPrimary.opacity(0.08) : (isHovered ? StudioTheme.surfaceSecondary : Color.clear))
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bgm.title), \(bgm.category.rawValue)")
        .accessibilityValue(isPlaying ? "Playing" : (isCurrentTrack ? "Current" : "Queued"))
    }
}

// MARK: - Preview

#Preview {
    RightPanel()
        .environmentObject(SwitcherViewModel())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
