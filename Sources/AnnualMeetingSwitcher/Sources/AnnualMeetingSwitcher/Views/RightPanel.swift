import SwiftUI
import UniformTypeIdentifiers

// MARK: - 音频策略枚举

enum AudioStrategy: String, CaseIterable {
    case followProgram = "音频跟随"
    case followSource  = "跟随源"
    case bgmOnly       = "仅 BGM"
    case mixed         = "混合"
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
        ScrollView(.vertical, showsIndicators: false) {
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
        .frame(minWidth: 280, idealWidth: 292, maxWidth: 310)
        .studioCard(cornerRadius: 28)
    }

    // MARK: - 主音量卡片（Issue #7: 联控 AVPlayer + BGM）

    private var masterVolumeCard: some View {
        let compact = mode == .liveQuick

        return VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text("MASTER")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("主音量")
                        .font(.system(size: compact ? 22 : 24, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: compact ? 16 : 18, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("\(Int(viewModel.masterVolume * 100))%")
                        .font(.system(size: compact ? 24 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            }

            Slider(value: $viewModel.masterVolume, in: 0...1)
                .tint(.blue)
                .frame(height: compact ? 22 : 26)
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                strategyPill
            }

            Picker("", selection: audioStrategy) {
                ForEach(AudioStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.rawValue).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(audioStrategySummary)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
    }

    private var quickMixStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("现场快调")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("当前策略")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.indigo)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
    }

    // MARK: - 通道音量（Issue #8: 真实挂载到音频节点，不是空壳变量）

    private var channelVolumeCard: some View {
        VStack(alignment: .leading, spacing: mode == .liveQuick ? 10 : 14) {
            Text("现场推子")
                .font(.system(size: mode == .liveQuick ? 18 : 20, weight: .bold))
                .foregroundColor(.primary)

            mixerFader(
                title: "源 A",
                subtitle: "媒体",
                value: $viewModel.mediaVolume,
                tint: .blue
            )

            mixerFader(
                title: "BGM",
                subtitle: viewModel.isSpeakerMode ? "主讲人压限中" : "背景音乐",
                value: $viewModel.bgmVolume,
                tint: .purple
            )

            // MARK: - V26.3: 主讲人模式按钮（一键压限 BGM）
            Button(action: {
                viewModel.toggleSpeakerMode()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("主讲人模式")
                            .font(.system(size: 16, weight: .bold))
                        Text(viewModel.isSpeakerMode ? "BGM 已压低至 7%" : "一键压低 BGM")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.9)
                    }
                    Spacer()
                    Text(viewModel.isSpeakerMode ? "ON" : "OFF")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, mode == .liveQuick ? 10 : 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.isSpeakerMode
                              ? Color(red: 0.05, green: 0.65, blue: 0.35)  // 开启：深绿
                              : Color(red: 0.18, green: 0.42, blue: 0.88)) // 关闭：蓝色
                )
                .shadow(color: viewModel.isSpeakerMode
                        ? Color.green.opacity(0.4)
                        : Color.blue.opacity(0.3),
                        radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .padding(.top, mode == .liveQuick ? 4 : 10)
        }
        .padding(mode == .liveQuick ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
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
        Text(viewModel.audioStrategy.rawValue)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.indigo.opacity(0.12))
            )
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
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: compact ? 21 : 24, weight: .bold, design: .rounded))
                    .foregroundColor(tint)
            }

            Slider(value: value, in: 0...1)
                .tint(tint)
                .frame(height: compact ? 20 : 24)
        }
        .padding(compact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.06))
        )
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
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Slider(value: $value, in: 0...1)
                .tint(color)
                .frame(height: 22)

            Text("\(Int(value * 100))")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

// MARK: - BGM 曲目行（Issue #6: 文字放大）
// V24 Fix #1: isCurrentTrack 不依赖 isBGMPlaying，暂停时高亮依然保持

struct BGMItemRow: View {
    let bgm: BGMItem
    @ObservedObject var viewModel: SwitcherViewModel
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
                .foregroundColor(isCurrentTrack ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                // Issue #6: .title3 或更大
                Text(bgm.title)
                    .font(.title3)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundColor(isCurrentTrack ? .blue : .primary)
                    .lineLimit(1)
                Text(bgm.category.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                // Issue #6: 按钮也放大
                Button(action: { viewModel.toggleBGM(bgm) }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isCurrentTrack ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "暂停" : "播放")

                Button(action: { viewModel.removeBGMItem(bgm) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("删除")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(isCurrentTrack ? Color.blue.opacity(0.08) : (isHovered ? Color.gray.opacity(0.06) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    RightPanel()
        .environmentObject(SwitcherViewModel())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
