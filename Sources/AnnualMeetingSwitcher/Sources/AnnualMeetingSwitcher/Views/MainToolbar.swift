import AppKit
import SwiftUI

// MARK: - 主工具栏

@MainActor
struct MainToolbar: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showHelp = false
    @State private var showPreflight = false
    var embedded: Bool = false
    var consoleMode: ConsoleMode = .setup
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

    @MainActor
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
        HStack(spacing: ToolbarLayoutMetrics.interItemSpacing) {
            toolbarModeButtons
            preflightButton
            helpButton
        }
    }

    private var preflightModel: PreflightButtonModel {
        PreflightButtonModel.make(summary: viewModel.livePreflightSummary)
    }

    private var toolbarModeButtons: some View {
        HStack(spacing: ToolbarLayoutMetrics.modeButtonSpacing) {
            ToolbarModeButton(
                title: "主持人",
                systemImage: "mic.fill",
                isActive: viewModel.isSpeakerMode
            ) {
                viewModel.toggleSpeakerMode()
            }
            ToolbarModeButton(
                title: "PPT",
                systemImage: "hand.raised.slash.fill",
                isActive: viewModel.isPageInterceptEnabled
            ) {
                viewModel.isPageInterceptEnabled.toggle()
            }
        }
        .frame(minWidth: ToolbarLayoutMetrics.modeButtonGroupMinWidth)
        .frame(height: ToolbarLayoutMetrics.actionHeight)
    }

    private var preflightButton: some View {
        Button(action: { showPreflight.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: preflightModel.status == .fail ? "xmark.octagon.fill" : "checklist.checked")
                    .font(StudioTheme.TypeScale.heading.weight(.black))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preflightModel.title)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                    Text(preflightModel.value)
                        .font(StudioTheme.TypeScale.label.weight(.bold))
                }
                Image(systemName: "chevron.down")
                    .font(StudioTheme.TypeScale.label.weight(.black))
                    .accessibilityHidden(true)
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
        .accessibilityLabel("现场检查")
        .accessibilityValue(preflightModel.value)
        .accessibilityHint("打开现场检查")
    }

    // MARK: - 使用说明按钮

    private var helpButton: some View {
        Button(action: { showHelp.toggle() }) {
            Label("帮助", systemImage: "questionmark.circle")
                .font(StudioTheme.TypeScale.body.weight(.bold))
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
        .accessibilityLabel("帮助")
        .accessibilityHint("打开使用说明")
    }

}

private struct ToolbarModeButton: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .accessibilityHidden(true)
                Text(title)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(isActive ? .white : StudioTheme.Action.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(width: ToolbarLayoutMetrics.modeButtonMinWidth)
        .frame(height: ToolbarLayoutMetrics.actionHeight)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(isActive ? StudioTheme.Action.primary : StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(isActive ? StudioTheme.Action.primary.opacity(0.32) : StudioTheme.Action.primary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: isActive ? StudioTheme.Action.primary.opacity(0.18) : .clear, radius: 8, x: 0, y: 4)
        .focusable(false)
        .help(isActive ? "\(title)模式已开启" : "开启\(title)模式")
        .accessibilityLabel(title)
        .accessibilityValue(isActive ? "开" : "关")
    }
}

// MARK: - Preview

#Preview {
    MainToolbar()
        .environment(SwitcherViewModel())
        .frame(width: 900)
}
