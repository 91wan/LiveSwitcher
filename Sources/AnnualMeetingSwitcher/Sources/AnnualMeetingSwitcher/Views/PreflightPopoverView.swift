import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preflight

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
            HStack(spacing: 12) {
                Text("LiveSwitcher")
                    .font(StudioTheme.TypeScale.heading.weight(.black))

                Spacer()

                let headerBadge = PreflightHeaderBadgeModel.make(summary: viewModel.livePreflightSummary)
                if headerBadge.isVisible {
                    StatusBadge(headerBadge.text, kind: headerBadge.kind)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                preflightContent
                    .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }

    @ViewBuilder
    private var preflightContent: some View {
        let review = preflightReview

        VStack(alignment: .leading, spacing: 16) {
            preflightHeader

            PreflightSummaryCard(summary: viewModel.livePreflightSummary)

            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $preflightListMode) {
                    Text("需处理").tag(PreflightReviewMode.needsAttention)
                    Text("全部检查").tag(PreflightReviewMode.allChecks)
                }
                .pickerStyle(.segmented)

                if preflightListMode == .needsAttention {
                    Text("只显示故障和警告项，先处理现场风险。")
                        .font(StudioTheme.TypeScale.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let preflightActionMessage {
                Text(preflightActionMessage)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.Tone.ready)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.Tone.ready.opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .accessibilityLabel("现场检查操作结果：\(preflightActionMessage)")
            }

            if let supportMessage {
                Text(supportMessage)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.Action.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .accessibilityLabel("支持报告结果：\(supportMessage)")
            }

            if review.isEmpty {
                PreflightEmptyAttentionView(
                    title: review.emptyTitle,
                    message: review.emptyMessage
                )
            }

            ForEach(review.sections) { section in
                PreflightGroupView(
                    group: section.group,
                    checks: section.checks,
                    onAction: handlePreflightRowAction
                )
            }

            preflightFooterActions
        }
    }

    private var preflightHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("现场检查")
                .font(StudioTheme.TypeScale.numeric)
            Text("读取当前运行状态。先看汇总，再处理故障和警告项。")
                .font(StudioTheme.TypeScale.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preflightFooterActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(spacing: 8) {
                Button(action: onOpenSafetyCockpit) {
                    Label("打开安全台", systemImage: "gauge.with.dots.needle.bottom.100percent")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: copyPreflightReport) {
                    Label(copiedReport ? "已复制" : "复制检查", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)

                Button(action: copySupportReport) {
                    Label("复制支持报告", systemImage: "stethoscope")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: saveSupportReport) {
                    Label("保存支持报告...", systemImage: "square.and.arrow.down")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("现场检查底部操作")
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

private struct PreflightEmptyAttentionView: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(StudioTheme.TypeScale.numeric)
                .foregroundStyle(StudioTheme.Tone.ready)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                Text(message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(StudioTheme.Tone.ready.opacity(0.08), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.Tone.ready.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("没有需要处理的现场检查项")
    }
}

private struct PreflightSummaryCard: View {
    let summary: LivePreflightSummary

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.title.weight(.black))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(summary.title)
                        .font(StudioTheme.TypeScale.heading.weight(.black))

                    Text(summary.status.displayTitle)
                        .font(StudioTheme.TypeScale.label)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(summary.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                countPill("过", summary.passCount, StudioTheme.Tone.ready)
                countPill("警", summary.warnCount, StudioTheme.Tone.warn)
                countPill("故障", summary.failCount, StudioTheme.Tone.fail)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(statusColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(statusColor.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("现场检查汇总：\(summary.status.displayTitle)。\(summary.message)。\(summary.passCount) 个通过，\(summary.warnCount) 个警告，\(summary.failCount) 个故障。")
    }

    private func countPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        Text("\(label) \(count)")
            .font(StudioTheme.TypeScale.label)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        switch summary.status {
        case .pass:
            return StudioTheme.Tone.ready
        case .warn:
            return StudioTheme.Tone.warn
        case .fail:
            return StudioTheme.Tone.fail
        }
    }

    private var iconName: String {
        switch summary.status {
        case .pass:
            return "checkmark.seal.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }
}

@MainActor
private struct PreflightGroupView: View {
    let group: LivePreflightGroup
    let checks: [LivePreflightCheck]
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayTitle)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(checks) { check in
                    PreflightRowView(check: check, onAction: onAction)
                }
            }
        }
    }
}

@MainActor
private struct PreflightRowView: View {
    let check: LivePreflightCheck
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.heading.weight(.black))
                .foregroundStyle(statusColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(StudioTheme.TypeScale.body.weight(.bold))
                    Text(check.status.displayTitle)
                        .font(StudioTheme.TypeScale.label)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(check.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = check.actionLabel, let actionKind = check.actionKind {
                    if actionKind.shouldRenderAsButton {
                        Button(actionLabel) {
                            onAction(actionKind)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(preflightActionHelp(for: actionKind))
                        .accessibilityLabel(actionLabel)
                        .accessibilityHint(preflightActionHelp(for: actionKind))
                        .padding(.top, 3)
                    } else {
                        guidanceBadge(actionLabel, actionKind)
                            .padding(.top, 3)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch check.status {
        case .pass:
            return StudioTheme.Tone.ready
        case .warn:
            return StudioTheme.Tone.warn
        case .fail:
            return StudioTheme.Tone.fail
        }
    }

    private var iconName: String {
        switch check.status {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }

    private func guidanceBadge(_ label: String, _ action: LivePreflightActionKind) -> some View {
        Label(label, systemImage: guidanceIcon(for: action))
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(StudioTheme.Surface.raised, in: Capsule())
            .help(preflightActionHelp(for: action))
            .accessibilityLabel(label)
            .accessibilityHint(preflightActionHelp(for: action))
    }

    private func guidanceIcon(for action: LivePreflightActionKind) -> String {
        switch action {
        case .needsHardware:
            return "display.2"
        case .manualReview:
            return "person.crop.circle.badge.questionmark"
        case .clearOverlays, .turnOffPanic, .openPreview, .openAudioMixer, .openOverlays:
            return "info.circle"
        }
    }

    private func preflightActionHelp(for action: LivePreflightActionKind) -> String {
        switch action {
        case .clearOverlays:
            return "清除倒计时、游动字幕和人名条。"
        case .turnOffPanic:
            return "关闭当前紧急切黑。"
        case .openPreview:
            return "打开导播台页面。"
        case .openAudioMixer:
            return "打开音频页面。"
        case .openOverlays:
            return "打开叠层字幕页面。"
        case .needsHardware:
            return "需要外接显示器硬件，无法自动完成。"
        case .manualReview:
            return "仅提示人工复核，不改变应用状态。"
        }
    }
}

#Preview {
    PreflightPopoverView()
        .environment(SwitcherViewModel())
}
