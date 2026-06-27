import SwiftUI

@MainActor
struct SafetyCockpitStatusGrid: View {
    let cockpit: LiveSafetyCockpitState
    let onRiskAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            urgentSection
            sectionGrid
            eventsSection
        }
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
                SafetyReadyCard()
            } else {
                VStack(spacing: 9) {
                    ForEach(attention.prefix(6)) { check in
                        SafetyCheckRow(check: check, onAction: onRiskAction)
                    }
                }
            }
        }
        .padding(16)
        .studioCard(cornerRadius: 20)
    }

    private var sectionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
            ForEach(cockpit.sections) { section in
                SafetySectionCard(section: section, onAction: onRiskAction)
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
}

private struct SafetyReadyCard: View {
    var body: some View {
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
}
