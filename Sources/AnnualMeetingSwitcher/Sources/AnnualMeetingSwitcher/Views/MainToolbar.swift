import AppKit
import SwiftUI

// MARK: - 主工具栏

struct MainToolbar: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showHelp = false
    @State private var showPreflight = false
    var embedded: Bool = false
    var onOpenPreview: () -> Void = {}
    var onOpenAudioMixer: () -> Void = {}
    var onOpenOverlays: () -> Void = {}

    var body: some View {
        Group {
            if embedded {
                embeddedToolbarActionCluster
            } else {
                HStack(spacing: 14) {
                    Spacer()
                    embeddedToolbarActionCluster
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.clear)
                .overlay(
                    Divider()
                        .background(Color(NSColor.separatorColor)),
                    alignment: .bottom
                )
            }
        }
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            HelpPopoverView()
        }
        .popover(isPresented: $showPreflight, arrowEdge: .bottom) {
            PreflightPopoverView(
                onPreflightAction: handlePreflightAction,
                onOpenSafetyCockpit: {
                    openWindow(id: "safety-cockpit")
                    showPreflight = false
                }
            )
        }
    }

    private func handlePreflightAction(_ action: LivePreflightActionKind) {
        viewModel.performLivePreflightAction(action)
        switch action {
        case .clearOverlays, .turnOffPanic:
            break
        case .openPreview:
            onOpenPreview()
            showHelp = false
            showPreflight = false
        case .openAudioMixer:
            onOpenAudioMixer()
            showHelp = false
            showPreflight = false
        case .openOverlays:
            onOpenOverlays()
            showHelp = false
            showPreflight = false
        case .needsHardware, .manualReview:
            break
        }
    }

    private var embeddedToolbarActionCluster: some View {
        ViewThatFits(in: .horizontal) {
            toolbarActionRow(compact: false)
            toolbarActionRow(compact: true)
        }
    }

    private var panicTint: Color {
        viewModel.isPanicMode
            ? StudioTheme.actionDanger
            : StudioTheme.actionPrimary
    }

    private var preflightModel: PreflightButtonModel {
        PreflightButtonModel.make(summary: viewModel.livePreflightSummary)
    }

    private func toolbarActionRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            ForEach(ToolbarActionModel.topActions) { action in
                toolbarActionButton(action.id, compact: compact)
            }
        }
    }

    @ViewBuilder
    private func toolbarActionButton(_ action: ToolbarActionModel.ActionID, compact: Bool) -> some View {
        switch action {
        case .panic:
            if compact {
                compactToolbarButton(
                    title: viewModel.isPanicMode ? "老板键: 开" : "老板键",
                    subtitle: viewModel.isPanicMode ? "切黑静音" : "紧急切黑",
                    systemName: viewModel.isPanicMode ? "eye.slash.fill" : "bolt.fill",
                    fill: panicTint,
                    action: togglePanic
                )
            } else {
                liveControlButton(
                    title: viewModel.isPanicMode ? "老板键: 开" : "老板键",
                    subtitle: viewModel.isPanicMode ? "切黑静音" : "紧急切黑",
                    systemName: viewModel.isPanicMode ? "eye.slash.fill" : "bolt.fill",
                    tint: panicTint,
                    isCritical: viewModel.isPanicMode,
                    help: viewModel.isPanicMode
                        ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
                        : "老板键（紧急）：一键切黑副屏并静音所有音频",
                    action: togglePanic
                )
            }
        case .preflight:
            if compact {
                compactPreflightButton
            } else {
                preflightButton
            }
        case .help:
            helpButton
        case .speaker, .ppt:
            EmptyView()
        }
    }

    private func togglePanic() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.togglePanicMode()
        }
    }

    private var preflightButton: some View {
        Button(action: { showPreflight.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: preflightModel.status == .fail ? "xmark.octagon.fill" : "checklist.checked")
                    .font(.system(size: 15, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(preflightModel.title)
                        .font(.system(size: 13, weight: .black))
                    Text(preflightModel.value)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(StudioTheme.statusColor(preflightModel.status))
            .frame(width: 112, height: 46)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(StudioTheme.statusColor(preflightModel.status).opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(StudioTheme.statusColor(preflightModel.status).opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("现场检查：查看 fail/warn 项和安全操作")
        .accessibilityLabel("Preflight")
        .accessibilityValue(preflightModel.value)
        .accessibilityHint("Open live preflight checks")
    }

    private var compactPreflightButton: some View {
        compactToolbarButton(
            title: "Preflight",
            subtitle: preflightModel.value,
            systemName: preflightModel.status == .fail ? "xmark.octagon.fill" : "checklist.checked",
            fill: StudioTheme.statusColor(preflightModel.status)
        ) {
            showPreflight.toggle()
        }
    }

    // MARK: - 使用说明按钮

    private var helpButton: some View {
        Button(action: { showHelp.toggle() }) {
            Label("Help", systemImage: "questionmark.circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .frame(height: 38)
                .padding(.horizontal, 12)
                .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .stroke(StudioTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("使用说明")
        .accessibilityLabel("Help")
        .accessibilityHint("Open usage help")
    }

    private func compactToolbarButton(
        title: String,
        subtitle: String,
        systemName: String,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: fill.opacity(0.28), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("\(title): \(subtitle)")
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .accessibilityHint("Toggle \(title)")
    }

    private func liveControlButton(
        title: String,
        subtitle: String,
        systemName: String,
        tint: Color,
        isCritical: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0.88)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 112, height: 46)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(
                        isCritical ? StudioTheme.actionDanger : tint
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(StudioTheme.surfaceElevated.opacity(isCritical ? 0.46 : 0.18), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isCritical ? 0.36 : 0.24), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
        .accessibilityLabel(title)
        .accessibilityHint(help)
    }
}

// MARK: - Preview

#Preview {
    MainToolbar()
        .environmentObject(SwitcherViewModel())
        .frame(width: 900)
}
