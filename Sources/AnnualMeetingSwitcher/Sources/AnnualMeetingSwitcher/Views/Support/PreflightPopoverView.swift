import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PreflightPopoverView: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    @State private var copiedReport = false
    @State private var supportMessage: String?
    @State private var preflightListMode: PreflightReviewMode = .needsAttention
    @State private var preflightActionMessage: String?
    var onPreflightAction: @MainActor (LivePreflightActionKind) -> Void = { _ in }
    var onOpenSafetyCockpit: @MainActor () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            PreflightPopoverTitleBar(summary: viewModel.livePreflightSummary)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PreflightCheckList(
                        summary: viewModel.livePreflightSummary,
                        review: preflightReview,
                        listMode: $preflightListMode,
                        preflightActionMessage: preflightActionMessage,
                        supportMessage: supportMessage,
                        onPreflightAction: handlePreflightRowAction
                    )

                    PreflightSupportActions(
                        copiedReport: copiedReport,
                        onOpenSafetyCockpit: onOpenSafetyCockpit,
                        onCopyPreflightReport: copyPreflightReport,
                        onCopySupportReport: copySupportReport,
                        onSaveSupportReport: saveSupportReport
                    )
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }

    private var preflightReview: PreflightReviewModel {
        PreflightReviewModel.make(
            checks: viewModel.livePreflightChecks,
            mode: preflightListMode
        )
    }

    @MainActor
    private func handlePreflightRowAction(_ action: LivePreflightActionKind) {
        let routing = PreflightActionRoutingModel.make(action: action)
        onPreflightAction(action)
        if let successMessage = routing.successMessage {
            showPreflightActionMessage(successMessage)
        }
    }

    @MainActor
    private func showPreflightActionMessage(_ message: String) {
        preflightActionMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if preflightActionMessage == message {
                preflightActionMessage = nil
            }
        }
    }

    @MainActor
    private func copyPreflightReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.livePreflightReportText(), forType: .string)
        copiedReport = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copiedReport = false
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

#Preview {
    PreflightPopoverView()
        .environment(SwitcherViewModel())
}
