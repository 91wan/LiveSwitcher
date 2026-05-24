import SwiftUI

struct SetupAudioDock: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        let model = SetupAudioDockModel.make(
            masterVolume: viewModel.masterVolume,
            mediaVolume: viewModel.mediaVolume,
            bgmVolume: viewModel.bgmVolume,
            effectiveMediaVolume: viewModel.effectiveMediaOutputVolume(),
            effectiveBGMVolume: viewModel.effectiveBGMOutputVolume(),
            isMasterMuted: viewModel.isMasterAudioMuted || viewModel.isPanicMode,
            isMediaMuted: viewModel.isMediaAudioMuted,
            isBGMMuted: viewModel.isBGMAudioMuted
        )

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Audio")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(model.mutedChannelCount == 0 ? "Setup dock" : "\(model.mutedChannelCount) muted")
                    .font(StudioTheme.caption())
                    .foregroundStyle(model.mutedChannelCount == 0 ? StudioTheme.textSecondary : StudioTheme.Tone.warn)
            }
            .frame(width: 94, alignment: .leading)

            SetupAudioDockChannel(
                title: "Master",
                value: $viewModel.masterVolume,
                isMuted: $viewModel.isMasterAudioMuted,
                userText: model.masterUserText,
                effectiveText: model.masterEffectiveText,
                tint: StudioTheme.Action.primary
            )

            SetupAudioDockChannel(
                title: "Media",
                value: $viewModel.mediaVolume,
                isMuted: $viewModel.isMediaAudioMuted,
                userText: model.mediaUserText,
                effectiveText: model.mediaEffectiveText,
                tint: StudioTheme.Action.primary
            )

            SetupAudioDockChannel(
                title: "BGM",
                value: $viewModel.bgmVolume,
                isMuted: $viewModel.isBGMAudioMuted,
                userText: model.bgmUserText,
                effectiveText: model.bgmEffectiveText,
                tint: StudioTheme.Tone.warn
            )

            Button {
                onOpenMixer()
            } label: {
                Label("Mixer", systemImage: "slider.horizontal.3")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open full Audio Mixer")
            .accessibilityLabel("Open full Audio Mixer")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(StudioTheme.Surface.base.opacity(0.88))
        .overlay(Divider(), alignment: .top)
    }
}

private struct SetupAudioDockChannel: View {
    let title: String
    @Binding var value: Double
    @Binding var isMuted: Bool
    let userText: String
    let effectiveText: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("User \(userText) · Out \(effectiveText)")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(StudioTheme.TypeScale.label)
                        .frame(width: 24, height: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(isMuted ? "Unmute \(title)" : "Mute \(title)")
                .accessibilityLabel(isMuted ? "Unmute \(title)" : "Mute \(title)")
            }

            Slider(value: $value, in: 0...1)
                .tint(isMuted ? StudioTheme.Tone.muted : tint)
                .controlSize(.mini)
                .accessibilityLabel("\(title) setup dock volume")
                .accessibilityValue("User \(userText), output \(effectiveText)")
        }
        .frame(maxWidth: .infinity)
    }
}
