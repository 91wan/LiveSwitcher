import SwiftUI

@MainActor
struct BGMTrackRow: View {
    let bgm: BGMItem
    var viewModel: SwitcherViewModel
    var compact: Bool = false
    @State private var isHovered = false

    private var isCurrentTrack: Bool {
        viewModel.currentBGMItem?.id == bgm.id
    }

    private var isPlaying: Bool {
        isCurrentTrack && viewModel.isBGMPlaying
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ProgramThumbnailView(
                    sourceURL: bgm.url,
                    kind: .media,
                    isVideo: false,
                    displaySize: CGSize(width: compact ? 42 : 54, height: compact ? 24 : 30)
                )

                if isCurrentTrack {
                    Image(systemName: isPlaying ? "waveform" : "checkmark")
                        .font(StudioTheme.TypeScale.monoCaption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(StudioTheme.Action.primary))
                        .accessibilityHidden(true)
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bgm.title)
                    .font(compact ? StudioTheme.TypeScale.heading.weight(.semibold) : StudioTheme.TypeScale.title)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundStyle(isCurrentTrack ? StudioTheme.Action.primary : StudioTheme.textPrimary)
                    .lineLimit(1)
                Text(bgm.category.rawValue)
                    .font(compact ? StudioTheme.TypeScale.caption : StudioTheme.TypeScale.body)
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: compact ? 8 : 10) {
                Button(action: { viewModel.toggleBGM(bgm) }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(compact ? StudioTheme.TypeScale.body : StudioTheme.TypeScale.heading)
                        .foregroundStyle(isCurrentTrack ? StudioTheme.Action.primary : StudioTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "暂停" : "播放")
                .accessibilityLabel(isPlaying ? "暂停 \(bgm.title)" : "播放 \(bgm.title)")

                Button(action: { viewModel.removeBGMItem(bgm) }) {
                    Image(systemName: "trash")
                        .font(compact ? StudioTheme.TypeScale.caption : StudioTheme.TypeScale.body)
                        .foregroundStyle(isHovered ? StudioTheme.Action.danger : StudioTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("删除")
                .accessibilityLabel("删除 \(bgm.title)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 6 : 8)
        .background(isCurrentTrack ? StudioTheme.Action.primary.opacity(0.08) : (isHovered ? StudioTheme.Surface.raised : Color.clear))
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bgm.title), \(bgm.category.rawValue)")
        .accessibilityValue(isPlaying ? "播放中" : (isCurrentTrack ? "当前曲目" : "待播"))
    }
}
