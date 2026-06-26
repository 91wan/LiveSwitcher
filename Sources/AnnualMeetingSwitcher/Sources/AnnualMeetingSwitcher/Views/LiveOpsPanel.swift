import SwiftUI

@MainActor
struct LiveOpsPanel: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let onSwitchToLive: () -> Void

    var body: some View {
        SetupSideRailChrome(
            scrollsContent: true,
            footer: { runtimeFooter }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("现场控制")
                            .font(StudioTheme.title())
                            .foregroundStyle(StudioTheme.textPrimary)
                        Text("准备阶段")
                            .font(StudioTheme.caption())
                            .foregroundStyle(StudioTheme.textSecondary)
                    }
                    Spacer()
                    if viewModel.isPanicMode {
                        StatusBadge("紧急切黑", kind: .fail)
                    }
                }
                .padding(.horizontal, 4)

                outputCard
                switchToLiveCard
                CornerLogoCard()
            }
        }
    }

    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return opsCard(title: "输出", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isBroadcasting ? "stop.fill" : "antenna.radiowaves.left.and.right")
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .accessibilityHidden(true)
                    ProjectionOutputOperatorLabel(model: model)
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
            .accessibilityLabel(model.operatorLine)
            .accessibilityHint(model.subtitle)

            if model.statusKind == .fail, let warningTitle = model.warningTitle, let warningMessage = model.warningMessage {
                InlineWarningBanner(title: warningTitle, message: warningMessage, kind: .fail)
            }
        }
    }

    private var switchToLiveCard: some View {
        opsCard(title: "模式", status: viewModel.consoleMode == .live ? "现场" : "准备", kind: viewModel.consoleMode == .live ? .live : .idle) {
            Text("准备阶段保留音频和 BGM 底栏控制；切到现场模式后可快速切换信号源、叠层、待机壁纸和现场控制。")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(4)

            Button(action: onSwitchToLive) {
                Label("进入现场", systemImage: "play.fill")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: LiveOpsLayoutMetrics.secondaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(StudioTheme.Action.primary)
            .focusable(false)
            .help("将控制台从准备阶段切到现场操作模式。")
            .accessibilityLabel("进入现场模式")
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
        SetupSideRailFooter(
            text: "v\(AppConfiguration.appVersion) · \(HostSystemSummary.shortVersionString)",
            accessibilityLabel: "LiveSwitcher 版本 \(AppConfiguration.appVersion)。\(HostSystemSummary.shortVersionString)。"
        )
    }
}
