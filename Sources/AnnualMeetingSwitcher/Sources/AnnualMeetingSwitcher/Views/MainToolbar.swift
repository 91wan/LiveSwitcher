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
        let routing = PreflightActionRoutingModel.make(action: action)
        viewModel.performLivePreflightAction(action)

        switch routing.destinationTab {
        case .preview:
            onOpenPreview()
        case .audioMixer:
            onOpenAudioMixer()
        case .overlays:
            onOpenOverlays()
        case nil:
            break
        }

        if routing.shouldDismissPopover {
            showHelp = false
            showPreflight = false
        }
    }

    private var embeddedToolbarActionCluster: some View {
        HStack(spacing: 10) {
            panicButton
            preflightButton
            helpButton
        }
    }

    private var panicTint: Color {
        viewModel.isPanicMode
            ? StudioTheme.Action.danger
            : StudioTheme.Action.primary
    }

    private var preflightModel: PreflightButtonModel {
        PreflightButtonModel.make(summary: viewModel.livePreflightSummary)
    }

    private func togglePanic() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.togglePanicMode()
        }
    }

    private var panicButton: some View {
        Button(action: togglePanic) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isPanicMode ? "eye.slash.fill" : "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.isPanicMode ? "老板键: 开" : "老板键")
                        .font(.system(size: 13, weight: .black))
                    Text(viewModel.isPanicMode ? "切黑静音" : "紧急切黑")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0.88)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(minWidth: ToolbarLayoutMetrics.panicMinWidth)
            .frame(height: ToolbarLayoutMetrics.actionHeight)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(panicTint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(StudioTheme.Surface.pressed.opacity(viewModel.isPanicMode ? 0.46 : 0.18), lineWidth: 1)
            )
            .shadow(color: panicTint.opacity(viewModel.isPanicMode ? 0.36 : 0.24), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(viewModel.isPanicMode
            ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
            : "老板键（紧急）：一键切黑副屏并静音所有音频")
        .accessibilityLabel(viewModel.isPanicMode ? "老板键: 开" : "老板键")
        .accessibilityHint(viewModel.isPanicMode
            ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
            : "老板键（紧急）：一键切黑副屏并静音所有音频")
    }

    private var preflightButton: some View {
        Button(action: { showPreflight.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: preflightModel.status == .fail ? "xmark.octagon.fill" : "checklist.checked")
                    .font(.system(size: 15, weight: .black))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preflightModel.title)
                        .font(.system(size: 13, weight: .black))
                    Text(preflightModel.value)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(StudioTheme.color(for: preflightModel.status))
            .padding(.horizontal, 12)
            .frame(minWidth: ToolbarLayoutMetrics.preflightMinWidth)
            .frame(height: ToolbarLayoutMetrics.actionHeight)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(StudioTheme.color(for: preflightModel.status).opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(StudioTheme.color(for: preflightModel.status).opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("现场检查：查看 fail/warn 项和安全操作")
        .accessibilityLabel("Preflight")
        .accessibilityValue(preflightModel.value)
        .accessibilityHint("Open live preflight checks")
    }

    // MARK: - 使用说明按钮

    private var helpButton: some View {
        Button(action: { showHelp.toggle() }) {
            Label("Help", systemImage: "questionmark.circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .frame(minWidth: ToolbarLayoutMetrics.helpMinWidth)
                .frame(height: ToolbarLayoutMetrics.actionHeight)
                .padding(.horizontal, 12)
                .background(StudioTheme.Surface.base, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
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

}

// MARK: - Preview

#Preview {
    MainToolbar()
        .environmentObject(SwitcherViewModel())
        .frame(width: 900)
}
