import SwiftUI

struct AudioMixerView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("音频混音")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("在这里统一管理 BGM 列表、三路音量、音频策略和淡入淡出时长。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
