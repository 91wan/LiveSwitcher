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
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(StudioTheme.color(for: headerKind))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("Live Safety Cockpit / 现场安全台")
                    .font(StudioTheme.titleLarge())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(cockpit.summary.message)
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 7) {
                    CountPill("PASS \(cockpit.summary.passCount)", kind: .ready)
                    CountPill("WARN \(cockpit.summary.warnCount)", kind: .warn)
                    CountPill("FAIL \(cockpit.summary.failCount)", kind: .fail)
                }

                HStack(spacing: 8) {
                    SecondaryActionButton("Copy Support", systemImage: "doc.on.doc") {
                        copySupportReport()
                    }

                    Button("Save Support...") {
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
                Text("Needs Attention First")
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
                .font(.system(size: 18, weight: .black))
            VStack(alignment: .leading, spacing: 3) {
                Text("No blocking rows")
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("All current runtime checks are passing.")
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
                Text("Recent Sanitized Events")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Text("\(cockpit.recentEvents.count) shown")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            if cockpit.recentEvents.isEmpty {
                Text("No recent support events recorded.")
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
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(StudioTheme.textSecondary)
                                .frame(width: 150, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.kind)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(StudioTheme.textPrimary)
                                Text(event.detail)
                                    .font(.system(size: 11, weight: .medium))
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
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func performAction(_ action: LivePreflightActionKind) {
        switch action {
        case .clearOverlays:
            if viewModel.performLivePreflightAction(action) {
                showActionMessage("Overlays cleared")
            }
        case .turnOffPanic:
            if viewModel.performLivePreflightAction(action) {
                showActionMessage("Panic turned off")
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
            return "Opened Preview / Switch"
        case .audioMixer:
            return "Opened Audio Mixer"
        case .overlays:
            return "Opened Overlays / Captions"
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
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(StudioTheme.color(for: statusKind))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    StatusBadge(check.status.displayTitle, kind: statusKind)
                }

                Text(check.message)
                    .font(.system(size: 12, weight: .medium))
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
            .font(.system(size: 11, weight: .bold))
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
            return "Clear countdown, ticker, and lower-third overlays."
        case .turnOffPanic:
            return "Turn off active panic blackout."
        case .openPreview, .openAudioMixer, .openOverlays:
            return "Open the matching page in the main console. This does not mutate show state."
        case .needsHardware:
            return "Requires external display hardware. This action is not automatic."
        case .manualReview:
            return "Manual operator review only. This action does not change app state."
        }
    }
}
