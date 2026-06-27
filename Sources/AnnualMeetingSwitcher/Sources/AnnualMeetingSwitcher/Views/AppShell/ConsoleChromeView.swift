import SwiftUI

@MainActor
struct ConsoleChromeView: View {
    let title: String
    let consoleMode: ConsoleMode
    let selectedTab: MainConsoleTab
    let isPanicMode: Bool
    let automationNotice: AutomationRuntimeNotice?
    let onTogglePanic: @MainActor () -> Void
    let onNavigateToSetup: @MainActor (MainConsoleTab) -> Void
    let onEnterLive: @MainActor () -> Void
    let onNoticePrimaryAction: @MainActor (AutomationRuntimeNoticeAction) -> Void
    let onNoticeDismiss: @MainActor () -> Void
    let onNoticeExpire: @MainActor (AutomationRuntimeNotice) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            PrimaryNavigationBar(
                title: title,
                consoleMode: consoleMode,
                selectedTab: selectedTab,
                isPanicMode: isPanicMode,
                onTogglePanic: onTogglePanic,
                onNavigateToSetup: onNavigateToSetup,
                onEnterLive: onEnterLive
            )
            automationRuntimeNoticeBanner
        }
    }

    @ViewBuilder
    private var automationRuntimeNoticeBanner: some View {
        if let notice = automationNotice {
            AutomationRuntimeNoticeBanner(
                notice: notice,
                onPrimaryAction: { action in
                    onNoticePrimaryAction(action)
                },
                onDismiss: onNoticeDismiss
            )
            .task(id: notice.id) {
                await onNoticeExpire(notice)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(StudioTheme.Surface.base.opacity(0.72))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct AutomationRuntimeNoticeBanner: View {
    let notice: AutomationRuntimeNotice
    let onPrimaryAction: @MainActor (AutomationRuntimeNoticeAction) -> Void
    let onDismiss: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: StudioTheme.spacingS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(toneColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(notice.message)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let primaryAction = notice.primaryAction {
                Button(primaryAction.label) {
                    onPrimaryAction(primaryAction)
                }
                .buttonStyle(.plain)
                .font(StudioTheme.TypeScale.label.weight(.black))
                .foregroundStyle(toneColor)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(toneColor.opacity(0.12), in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                .accessibilityLabel(primaryAction.label)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudioTheme.textSecondary)
            .accessibilityLabel("关闭自动化失败提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(toneColor.opacity(0.10), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(toneColor.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notice.title)：\(notice.message)")
    }

    private var toneColor: Color {
        switch notice.severity {
        case .warn:
            return StudioTheme.Tone.warn
        case .fail:
            return StudioTheme.Tone.fail
        }
    }
}
