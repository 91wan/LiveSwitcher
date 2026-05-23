import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preflight

struct PreflightPopoverView: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    @State private var copiedReport = false
    @State private var supportMessage: String?
    @State private var preflightListMode: PreflightListMode = .needsAttention
    @State private var preflightActionMessage: String?
    var onPreflightAction: (LivePreflightActionKind) -> Void = { _ in }
    var onOpenSafetyCockpit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("LiveSwitcher")
                    .font(.system(size: 16, weight: .black))

                Spacer()

                StatusBadge("Preflight", kind: PreflightButtonModel.make(summary: viewModel.livePreflightSummary).status)
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
        let checks = preflightDisplayedChecks

        VStack(alignment: .leading, spacing: 16) {
            preflightHeader

            PreflightSummaryCard(summary: viewModel.livePreflightSummary)

            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $preflightListMode) {
                    Text("Needs attention").tag(PreflightListMode.needsAttention)
                    Text("All checks").tag(PreflightListMode.allChecks)
                }
                .pickerStyle(.segmented)

                if preflightListMode == .needsAttention {
                    Text("Shows only fail and warn rows, so the operator sees what must be handled first.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let preflightActionMessage {
                Text(preflightActionMessage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StudioTheme.Tone.ready)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.Tone.ready.opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .accessibilityLabel("Preflight action result: \(preflightActionMessage)")
            }

            if let supportMessage {
                Text(supportMessage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StudioTheme.Action.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .accessibilityLabel("Support report result: \(supportMessage)")
            }

            if checks.isEmpty {
                PreflightEmptyAttentionView()
            }

            ForEach(LivePreflightGroup.allCases, id: \.self) { group in
                let groupChecks = checks.filter { $0.group == group }
                if !groupChecks.isEmpty {
                    PreflightGroupView(
                        group: group,
                        checks: groupChecks,
                        onAction: handlePreflightRowAction
                    )
                }
            }

            preflightFooterActions
        }
    }

    private var preflightHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Live Preflight / 现场检查")
                .font(.system(size: 18, weight: .black))
            Text("Reads the current runtime state. Use the summary first, then review fail/warn rows before a show.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var preflightFooterActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(spacing: 8) {
                Button(action: onOpenSafetyCockpit) {
                    Label("Open Cockpit", systemImage: "gauge.with.dots.needle.bottom.100percent")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: copyPreflightReport) {
                    Label(copiedReport ? "Copied" : "Copy Report", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)

                Button(action: copySupportReport) {
                    Label("Copy Support", systemImage: "stethoscope")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: saveSupportReport) {
                    Label("Save Support...", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preflight footer actions")
    }

    private var preflightDisplayedChecks: [LivePreflightCheck] {
        switch preflightListMode {
        case .needsAttention:
            return LivePreflightCheck.attentionChecks(from: viewModel.livePreflightChecks)
        case .allChecks:
            return viewModel.livePreflightChecks
        }
    }

    private func handlePreflightRowAction(_ action: LivePreflightActionKind) {
        let routing = PreflightActionRoutingModel.make(action: action)
        onPreflightAction(action)
        if let successMessage = routing.successMessage {
            showPreflightActionMessage(successMessage)
        }
    }

    private func showPreflightActionMessage(_ message: String) {
        preflightActionMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if preflightActionMessage == message {
                preflightActionMessage = nil
            }
        }
    }

    private func copyPreflightReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.livePreflightReportText(), forType: .string)
        copiedReport = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copiedReport = false
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
        showSupportMessage("Support report copied")
    }

    private func saveSupportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "LiveSwitcher-Support-v\(AppConfiguration.appVersion).txt"
        panel.title = "Save Support Report"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try viewModel.liveSupportReportText().write(to: url, atomically: true, encoding: .utf8)
            LiveSwitcherTelemetry.supportReportSaved(summaryStatus: viewModel.livePreflightSummary.status)
            viewModel.recordSupportEvent(
                kind: .supportReportSaved,
                detail: "status=\(viewModel.livePreflightSummary.status.rawValue)"
            )
            showSupportMessage("Support report saved")
        } catch {
            showSupportMessage("Support report save failed")
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

private enum PreflightListMode: Hashable {
    case needsAttention
    case allChecks
}

private struct PreflightEmptyAttentionView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(StudioTheme.Tone.ready)
            VStack(alignment: .leading, spacing: 3) {
                Text("No rows need attention")
                    .font(.system(size: 13, weight: .bold))
                Text("Switch to All checks if you want to audit every passing row.")
                    .font(.system(size: 12, weight: .medium))
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
        .accessibilityLabel("No preflight rows need attention")
    }
}

private struct PreflightSummaryCard: View {
    let summary: LivePreflightSummary

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(summary.title)
                        .font(.system(size: 15, weight: .black))

                    Text(summary.status.displayTitle)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(summary.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                countPill("P", summary.passCount, StudioTheme.Tone.ready)
                countPill("W", summary.warnCount, StudioTheme.Tone.warn)
                countPill("F", summary.failCount, StudioTheme.Tone.fail)
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
        .accessibilityLabel("Preflight summary: \(summary.status.displayTitle). \(summary.message). \(summary.passCount) pass, \(summary.warnCount) warn, \(summary.failCount) fail.")
    }

    private func countPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        Text("\(label) \(count)")
            .font(.system(size: 10, weight: .black, design: .rounded))
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

private struct PreflightGroupView: View {
    let group: LivePreflightGroup
    let checks: [LivePreflightCheck]
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayTitle)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(checks) { check in
                    PreflightRowView(check: check, onAction: onAction)
                }
            }
        }
    }
}

private struct PreflightRowView: View {
    let check: LivePreflightCheck
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(statusColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(.system(size: 13, weight: .bold))
                    Text(check.status.displayTitle)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(check.message)
                    .font(.system(size: 12, weight: .medium))
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
            .font(.system(size: 11, weight: .bold))
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
            return "Clear countdown, ticker, and lower-third overlays."
        case .turnOffPanic:
            return "Turn off active panic blackout."
        case .openPreview:
            return "Open the Run Desk page."
        case .openAudioMixer:
            return "Open the Audio Mixer page."
        case .openOverlays:
            return "Open the Overlays page."
        case .needsHardware:
            return "Requires external display hardware. This action is not automatic."
        case .manualReview:
            return "Manual operator review only. This action does not change app state."
        }
    }
}

#Preview {
    PreflightPopoverView()
        .environmentObject(SwitcherViewModel())
}
