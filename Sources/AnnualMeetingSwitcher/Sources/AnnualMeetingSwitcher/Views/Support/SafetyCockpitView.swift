import AppKit
import SwiftUI

@MainActor
struct SafetyCockpitView: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    @State private var supportMessage: String?
    @State private var actionMessage: String?

    private var cockpit: LiveSafetyCockpitState {
        LiveSafetyCockpit.make(
            snapshot: viewModel.livePreflightSnapshot,
            checks: viewModel.livePreflightChecks,
            events: viewModel.supportEvents
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SafetyCockpitHeader(
                    cockpit: cockpit,
                    actionMessage: actionMessage,
                    supportMessage: supportMessage,
                    onCopySupportReport: copySupportReport,
                    onSaveSupportReport: saveSupportReport
                )

                SafetyCockpitStatusGrid(
                    cockpit: cockpit,
                    onRiskAction: performAction
                )
            }
            .padding(24)
        }
        .background(StudioTheme.canvasGradient)
        .frame(minWidth: 760, minHeight: 620)
    }

    @MainActor
    private func performAction(_ action: LivePreflightActionKind) {
        switch action {
        case .clearOverlays:
            if viewModel.performLivePreflightAction(action) {
                showActionMessage("叠层已清空")
            }
        case .turnOffPanic:
            if viewModel.performLivePreflightAction(action) {
                showActionMessage("紧急切黑已关闭")
            }
        case .openPreview, .openAudioMixer, .openOverlays:
            guard let destination = action.mainConsoleDestination else { return }
            _ = viewModel.performLivePreflightAction(action)
            viewModel.selectedMainTab = destination
            openWindow(id: "main-console")
            showActionMessage(navigationMessage(for: destination))
        case .needsHardware, .manualReview:
            break
        }
    }

    @MainActor
    private func copySupportReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.liveSupportReportText(), forType: .string)
        LiveSwitcherTelemetry.supportReportCopied(summaryStatus: viewModel.livePreflightSummary.status)
        viewModel.recordSupportEvent(
            kind: .supportReportCopied,
            detail: "status=\(viewModel.livePreflightSummary.status.rawValue)"
        )
        showSupportMessage("支持报告已复制")
    }

    @MainActor
    private func saveSupportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "LiveSwitcher-Support-v\(AppConfiguration.appVersion).txt"
        panel.title = "保存支持报告"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try viewModel.liveSupportReportText().write(to: url, atomically: true, encoding: .utf8)
            LiveSwitcherTelemetry.supportReportSaved(summaryStatus: viewModel.livePreflightSummary.status)
            viewModel.recordSupportEvent(
                kind: .supportReportSaved,
                detail: "status=\(viewModel.livePreflightSummary.status.rawValue)"
            )
            showSupportMessage("支持报告已保存")
        } catch {
            showSupportMessage("支持报告保存失败")
        }
    }

    @MainActor
    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }

    private func navigationMessage(for destination: MainConsoleTab) -> String {
        switch destination {
        case .preview:
            return "已打开节目单"
        case .audioMixer:
            return "已打开音频页"
        case .overlays:
            return "已打开叠层字幕页"
        }
    }

    @MainActor
    private func showSupportMessage(_ message: String) {
        supportMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if supportMessage == message {
                supportMessage = nil
            }
        }
    }
}
