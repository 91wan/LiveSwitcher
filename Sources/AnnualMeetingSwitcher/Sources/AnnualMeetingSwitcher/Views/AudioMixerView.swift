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
                routingImpactBanner

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
        StudioSectionCard(
            title: "BGM fade utility",
            subtitle: "现场音乐切换的辅助参数，不影响节目画面转场。",
            status: (String(format: "%.1fs", viewModel.crossfadeDuration), .idle)
        ) {
            VStack(spacing: 12) {
                HStack {
                    Text("当前：\(String(format: "%.1f", viewModel.crossfadeDuration))s")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Spacer()
                    Text("0.5s")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textSecondary)
                    Slider(value: $viewModel.crossfadeDuration, in: 0.5...3.0, step: 0.1)
                        .tint(StudioTheme.statusWarn)
                        .frame(width: 220)
                    Text("3.0s")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }

    private var routingImpactBanner: some View {
        InlineWarningBanner(
            title: "Actual output",
            message: routingImpactText,
            kind: routingImpactKind
        )
    }

    private var routingImpactText: String {
        if viewModel.isPanicMode {
            return "Panic is active: media and BGM effective outputs are muted."
        }
        if viewModel.isSpeakerMode {
            return "Speaker mode is active: media and BGM are ducked to the speaker-safe level."
        }
        if viewModel.isBGMAudioTakeoverActive {
            return "BGM takeover is active: media is muted while BGM plays."
        }
        return "No emergency routing is active; effective output follows the selected strategy and faders."
    }

    private var routingImpactKind: StudioTheme.StatusKind {
        if viewModel.isPanicMode { return .fail }
        if viewModel.isSpeakerMode || viewModel.isBGMAudioTakeoverActive { return .warn }
        return .ready
    }
}

// SettingsView 已从主界面移除，不再定义于此文件
