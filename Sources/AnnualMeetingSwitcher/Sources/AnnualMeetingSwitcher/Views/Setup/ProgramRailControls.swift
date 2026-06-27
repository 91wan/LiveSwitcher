import SwiftUI

struct ProgramAutoPlayOptionRow: View {
    @Binding var isEnabled: Bool
    let hasCurrentProgram: Bool

    var body: some View {
        let model = AutoNextVideoControlModel.make(
            isEnabled: isEnabled,
            hasCurrentProgram: hasCurrentProgram
        )

        return Toggle(isOn: $isEnabled) {
            HStack(spacing: 7) {
                Image(systemName: model.systemImage)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.color(for: model.statusKind))
                Text("自动续播下一项")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .tint(StudioTheme.Tone.warn)
        .controlSize(.small)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .help("当前视频播毕后，如下一项也是视频，会自动续播下一项；不会打开 HTML、PPT 或 Keynote。")
        .accessibilityLabel("自动续播下一项")
    }
}

struct ProgramAgendaControlRow: View {
    @Binding var showAgendaTimeline: Bool
    @Binding var isAgendaTimeReminderEnabled: Bool
    @Binding var isAgendaMarkerPopoverPresented: Bool
    let onAddAgendaMarker: (AgendaMarkerInput) -> Void

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(StudioTheme.TypeScale.label.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .accessibilityHidden(true)
                Text("时间线")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 48, alignment: .leading)
                Toggle("", isOn: $showAgendaTimeline)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .help("将节目单显示为议程时间线，可选显示计划时间。")

            Spacer(minLength: 0)

            Toggle(isOn: $isAgendaTimeReminderEnabled) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Text("到点提醒")
                        .font(StudioTheme.TypeScale.label.weight(.semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("计划项到达开始时间时提示；不会自动切换。")
            .accessibilityLabel("到点提醒")
            .accessibilityHint("计划项到达开始时间时只显示提醒，不会自动切换。")

            Button {
                isAgendaMarkerPopoverPresented = true
            } label: {
                Label("添加标记", systemImage: "mappin.and.ellipse")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .focusable(false)
            .help("添加茶歇、转场等不可播放的议程标记。")
            .popover(isPresented: $isAgendaMarkerPopoverPresented, arrowEdge: .trailing) {
                AgendaMarkerEditorPopover(
                    mode: .add,
                    initialInput: .initial()
                ) { input in
                    onAddAgendaMarker(input)
                    isAgendaMarkerPopoverPresented = false
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}
