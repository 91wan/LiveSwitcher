import SwiftUI

@MainActor
struct LiveModeView: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let onOpenMixer: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let verticalInsets = LiveModeLayoutMetrics.contentTopPadding + LiveModeLayoutMetrics.contentBottomPadding
            let promptHeight: CGFloat = viewModel.isAgendaTimeReminderEnabled ? 46 : 0
            let mainHeight = max(
                0,
                proxy.size.height - verticalInsets - LiveModeLayoutMetrics.footerHeight - 8 - promptHeight
            )

            VStack(spacing: 8) {
                if viewModel.isAgendaTimeReminderEnabled {
                    AgendaReminderHost()
                        .frame(height: 38)
                }

                HStack(alignment: .top, spacing: LiveModeLayoutMetrics.mainColumnSpacing) {
                    LiveSourceRail()
                        .frame(width: viewModel.programItems.isEmpty ? LiveModeLayoutMetrics.sourceRailWidthEmpty : LiveModeLayoutMetrics.sourceRailWidth)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.programItems.isEmpty)
                        .layoutPriority(1)

                    VStack(spacing: 10) {
                        LiveProgramStack()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .layoutPriority(3)

                        LiveAudioStrip(onOpenMixer: onOpenMixer)
                            .frame(height: LiveModeLayoutMetrics.audioStripHeight)
                    }
                    .layoutPriority(3)

                    LiveQuickRail(onOpenMixer: onOpenMixer)
                        .frame(width: LiveModeLayoutMetrics.quickRailWidth)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: mainHeight)

                LiveRuntimeStatusBar()
                    .frame(height: LiveModeLayoutMetrics.footerHeight)
                    .layoutPriority(2)
            }
            .padding(.horizontal, LiveModeLayoutMetrics.horizontalContentPadding / 2)
            .padding(.top, LiveModeLayoutMetrics.contentTopPadding)
            .padding(.bottom, LiveModeLayoutMetrics.contentBottomPadding)
        }
    }
}
@MainActor
private struct AgendaReminderHost: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            if let prompt = viewModel.agendaReminderPrompt(now: context.date) {
                AgendaReminderPromptBanner(
                    prompt: prompt,
                    onTake: { viewModel.handleAgendaReminderAction(prompt) },
                    onDismiss: { viewModel.acknowledgeAgendaReminder(prompt) }
                )
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
    }
}

private struct AgendaReminderPromptBanner: View {
    let prompt: AgendaReminderPrompt
    let onTake: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(StudioTheme.TypeScale.body.weight(.bold))
                .foregroundStyle(StudioTheme.Tone.warn)
            Text(prompt.message)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if prompt.kind == .playableProgram {
                Button("切换") {
                    onTake()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Action.primary)
                .focusable(false)
                Button("忽略") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
            } else {
                Button("知道了") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Tone.warn)
                .focusable(false)
            }
        }
        .padding(.horizontal, 12)
        .background(StudioTheme.Tone.warn.opacity(0.11), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.Tone.warn.opacity(0.24), lineWidth: 1))
        .accessibilityLabel("议程提示。\(prompt.message)")
    }
}
