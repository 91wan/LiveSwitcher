import SwiftUI

struct LiveOpsPanel: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onSwitchToLive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Ops")
                        .font(StudioTheme.title())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("Setup output")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textSecondary)
                }
                Spacer()
                if viewModel.isPanicMode {
                    StatusBadge("BLACKOUT", kind: .fail)
                }
            }
            .padding(.horizontal, 4)

            outputCard
            switchToLiveCard

            Spacer(minLength: 0)

            runtimeFooter
        }
        .frame(maxHeight: .infinity)
    }

    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return opsCard(title: "Output", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isBroadcasting ? "stop.fill" : "antenna.radiowaves.left.and.right")
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.title)
                            .font(StudioTheme.TypeScale.caption.weight(.black))
                            .lineLimit(1)
                        Text(model.screenLabel)
                            .font(StudioTheme.TypeScale.label.weight(.semibold))
                            .opacity(0.82)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .foregroundStyle(outputActionForeground(model))
                .padding(.horizontal, 10)
                .frame(height: LiveOpsLayoutMetrics.outputPrimaryButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                        .fill(outputActionFill(model))
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(!model.isEnabled)
            .help(model.helpText)
            .accessibilityLabel(model.title)
            .accessibilityHint(model.subtitle)

            if model.statusKind == .fail, let warningTitle = model.warningTitle, let warningMessage = model.warningMessage {
                InlineWarningBanner(title: warningTitle, message: warningMessage, kind: .fail)
            }
        }
    }

    private var switchToLiveCard: some View {
        opsCard(title: "Mode", status: viewModel.consoleMode == .live ? "LIVE" : "SETUP", kind: viewModel.consoleMode == .live ? .live : .idle) {
            Text("Setup keeps audio and BGM controls in the dock. Switch to Live for source switching, overlays, wallpaper, and live quick controls.")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(4)

            Button(action: onSwitchToLive) {
                Label("Switch to Live", systemImage: "play.fill")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: LiveOpsLayoutMetrics.secondaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(StudioTheme.Action.primary)
            .focusable(false)
            .help("Switch the console from setup to live operating mode.")
            .accessibilityLabel("Switch to Live mode")
        }
    }

    private func opsCard<Content: View>(
        title: String,
        status: String,
        kind: StudioTheme.StatusKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                if StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind) {
                    StatusBadge(status, kind: kind)
                }
            }
            content()
        }
        .padding(LiveOpsLayoutMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(kind == .live || kind == .fail ? StudioTheme.color(for: kind).opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func outputActionFill(_ model: ProjectionButtonModel) -> Color {
        if !model.isEnabled { return StudioTheme.Tone.muted.opacity(0.18) }
        if model.statusKind == .fail { return StudioTheme.Action.danger }
        if model.isBroadcasting { return StudioTheme.Tone.live }
        return model.hasExternalDisplay ? StudioTheme.Action.primary : StudioTheme.Tone.muted
    }

    private func outputActionForeground(_ model: ProjectionButtonModel) -> Color {
        model.isEnabled ? .white : StudioTheme.textSecondary
    }

    private var runtimeFooter: some View {
        Text("v\(AppConfiguration.appVersion) · \(HostSystemSummary.shortVersionString)")
            .font(StudioTheme.caption())
            .foregroundStyle(StudioTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 4)
            .accessibilityLabel("LiveSwitcher version \(AppConfiguration.appVersion). \(HostSystemSummary.shortVersionString).")
    }
}
