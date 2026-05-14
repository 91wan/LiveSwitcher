import SwiftUI

struct AudioMixerView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Audio Mixer / 音频混音")
                        .font(StudioTheme.titleLarge())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("管理 BGM 曲库、推子值、实际输出和音频策略。Speaker / Panic / BGM takeover 的影响会反映在 effective output。")
                        .font(StudioTheme.body())
                        .foregroundStyle(StudioTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                audioSummaryRow

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        BGMPlaylistPanel()

                        VStack(spacing: 20) {
                            RightPanel(mode: .fullMixer)
                            transitionCard
                        }
                    }

                    VStack(spacing: 20) {
                        BGMPlaylistPanel()
                        RightPanel(mode: .fullMixer)
                        transitionCard
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var audioSummaryRow: some View {
        HStack(spacing: 12) {
            MetricRow(title: "Master", value: "\(Int(viewModel.masterVolume * 100))%", subtitle: "User fader", kind: .idle)
            Divider().frame(height: 34)
            MetricRow(title: "Media effective", value: "\(Int(viewModel.effectiveMediaOutputVolume() * 100))%", subtitle: viewModel.isPanicMode ? "Panic muted" : "After routing", kind: viewModel.effectiveMediaOutputVolume() == 0 ? .muted : .ready)
            Divider().frame(height: 34)
            MetricRow(title: "BGM effective", value: "\(Int(viewModel.effectiveBGMOutputVolume() * 100))%", subtitle: viewModel.isBGMAudioTakeoverActive ? "Takeover active" : "After routing", kind: viewModel.effectiveBGMOutputVolume() == 0 ? .muted : .ready)
            Divider().frame(height: 34)
            StatusBadge(viewModel.isSpeakerMode ? "Speaker ON" : "Speaker OFF", kind: viewModel.isSpeakerMode ? .warn : .idle)
            StatusBadge(viewModel.isBGMAudioTakeoverActive ? "BGM Takeover" : "No Takeover", kind: viewModel.isBGMAudioTakeoverActive ? .warn : .idle)
        }
        .padding(14)
        .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audio summary. Master \(Int(viewModel.masterVolume * 100)) percent. Media effective \(Int(viewModel.effectiveMediaOutputVolume() * 100)) percent. BGM effective \(Int(viewModel.effectiveBGMOutputVolume() * 100)) percent.")
    }

    private var transitionCard: some View {
        MixerCard(title: "BGM淡入淡出时长", icon: "wand.and.rays", iconColor: .indigo) {
            VStack(spacing: 12) {
                HStack {
                    Text("当前：\(String(format: "%.1f", viewModel.crossfadeDuration))s")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("0.5s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.crossfadeDuration, in: 0.5...3.0, step: 0.1)
                        .tint(.indigo)
                        .frame(width: 220)
                    Text("3.0s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }
}

// MARK: - 混音面板卡片组件

struct MixerCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// SettingsView 已从主界面移除，不再定义于此文件
