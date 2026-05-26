import AppKit
import SwiftUI

struct SafetyCockpitView: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
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
                header
                urgentSection
                sectionGrid
                eventsSection
            }
            .padding(24)
        }
        .background(StudioTheme.canvasGradient)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: headerIcon)
                .font(StudioTheme.TypeScale.display.weight(.black))
                .foregroundStyle(StudioTheme.color(for: headerKind))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("现场安全台")
                    .font(StudioTheme.titleLarge())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(cockpit.summary.message)
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 7) {
                    CountPill("通过 \(cockpit.summary.passCount)", kind: .ready)
                    CountPill("警告 \(cockpit.summary.warnCount)", kind: .warn)
                    CountPill("故障 \(cockpit.summary.failCount)", kind: .fail)
                }

                HStack(spacing: 8) {
                    SecondaryActionButton("复制支持报告", systemImage: "doc.on.doc") {
                        copySupportReport()
                    }

                    Button("保存支持报告...") {
                        saveSupportReport()
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
        }
        .padding(18)
        .background(StudioTheme.color(for: headerKind).opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.color(for: headerKind).opacity(0.24), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if let actionMessage {
                messageBanner(actionMessage, color: StudioTheme.Tone.ready)
                    .offset(y: 42)
            } else if let supportMessage {
                messageBanner(supportMessage, color: StudioTheme.Action.primary)
                    .offset(y: 42)
            }
        }
        .padding(.bottom, (actionMessage == nil && supportMessage == nil) ? 0 : 34)
    }

    private var urgentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("先处理风险")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Text(cockpit.attentionReview.rowCountText)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            let attention = cockpit.attentionReview.checks
            if attention.isEmpty {
                readyCard
            } else {
                VStack(spacing: 9) {
                    ForEach(attention.prefix(6)) { check in
                        SafetyCheckRow(check: check, onAction: performAction)
                    }
                }
            }
        }
        .padding(16)
        .studioCard(cornerRadius: 20)
    }

    private var readyCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(StudioTheme.Tone.ready)
                .font(StudioTheme.TypeScale.numeric)
            VStack(alignment: .leading, spacing: 3) {
                Text("没有阻塞项")
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("当前运行检查全部通过。")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(StudioTheme.Tone.ready.opacity(0.08), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
    }

    private var sectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
            ForEach(cockpit.sections) { section in
                SafetySectionCard(section: section, onAction: performAction)
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近脱敏事件")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Text("显示 \(cockpit.recentEvents.count) 条")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            if cockpit.recentEvents.isEmpty {
                Text("暂无最近支持事件。")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            } else {
                VStack(spacing: 7) {
                    ForEach(cockpit.recentEvents) { event in
                        HStack(alignment: .top, spacing: 9) {
                            Text(event.timestamp)
                                .font(StudioTheme.TypeScale.monoCaption)
                                .foregroundStyle(StudioTheme.textSecondary)
                                .frame(width: 150, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind)
                                    .font(StudioTheme.TypeScale.mono.weight(.bold))
                                    .foregroundStyle(StudioTheme.textPrimary)
                                Text(event.detail)
                                    .font(StudioTheme.TypeScale.caption)
                                    .foregroundStyle(StudioTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .studioCard(cornerRadius: 20)
    }

    private var headerKind: StudioTheme.StatusKind {
        switch cockpit.summary.status {
        case .pass:
            return .ready
        case .warn:
            return .warn
        case .fail:
            return .fail
        }
    }

    private var headerIcon: String {
        switch cockpit.summary.status {
        case .pass:
            return "checkmark.seal.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }

    private func messageBanner(_ message: String, color: Color) -> some View {
        Text(message)
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(color.opacity(0.10), in: Capsule())
    }

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

private struct SafetySectionCard: View {
    let section: LiveSafetyCockpitSection
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(StudioTheme.sectionTitle())
                .foregroundStyle(StudioTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(section.checks) { check in
                    SafetyCheckRow(check: check, onAction: onAction)
                }
            }
        }
        .padding(14)
        .studioCard(cornerRadius: 18)
    }
}

private struct SafetyCheckRow: View {
    let check: LivePreflightCheck
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.heading.weight(.black))
                .foregroundStyle(StudioTheme.color(for: statusKind))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(StudioTheme.TypeScale.body.weight(.bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    StatusBadge(check.status.displayTitle, kind: statusKind)
                }

                Text(check.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = check.actionLabel, let actionKind = check.actionKind {
                    if actionKind.shouldRenderAsButton {
                        Button(actionLabel) {
                            onAction(actionKind)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(help(for: actionKind))
                        .padding(.top, 2)
                    } else {
                        guidanceBadge(actionLabel, actionKind)
                            .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(StudioTheme.color(for: statusKind).opacity(0.06), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.color(for: statusKind).opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.status.displayTitle): \(check.title). \(check.message)")
    }

    private var statusKind: StudioTheme.StatusKind {
        switch check.status {
        case .pass:
            return .ready
        case .warn:
            return .warn
        case .fail:
            return .fail
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
            .foregroundStyle(StudioTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(StudioTheme.Surface.raised, in: Capsule())
            .help(help(for: action))
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

    private func help(for action: LivePreflightActionKind) -> String {
        switch action {
        case .clearOverlays:
            return "清除倒计时、游动字幕和人名条。"
        case .turnOffPanic:
            return "关闭当前紧急切黑。"
        case .openPreview, .openAudioMixer, .openOverlays:
            return "打开主控制台对应页面，不改变上屏状态。"
        case .needsHardware:
            return "需要外接显示器硬件，无法自动完成。"
        case .manualReview:
            return "仅提示人工复核，不改变应用状态。"
        }
    }
}
