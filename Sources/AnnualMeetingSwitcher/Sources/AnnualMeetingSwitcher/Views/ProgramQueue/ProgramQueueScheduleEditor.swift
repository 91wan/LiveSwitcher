import SwiftUI

struct AgendaScheduleEditorPopover: View {
    let item: ProgramItem
    let onApply: (Date?, TimeInterval?) -> Void

    @State private var scheduledStart: Date
    @State private var durationMinutes: Int

    init(item: ProgramItem, onApply: @escaping (Date?, TimeInterval?) -> Void) {
        self.item = item
        self.onApply = onApply
        _scheduledStart = State(initialValue: item.scheduledStartAt ?? Date())
        _durationMinutes = State(initialValue: max(1, Int(((item.scheduledDuration ?? AgendaTimelineModel.defaultDuration) / 60).rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("议程时间")
                .font(StudioTheme.sectionTitle())
                .foregroundStyle(StudioTheme.textPrimary)

            DatePicker(
                "开始",
                selection: $scheduledStart,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.compact)

            Stepper("时长 \(durationMinutes) 分钟", value: $durationMinutes, in: 1...999)
                .font(StudioTheme.body())

            HStack {
                Button("清除") {
                    onApply(nil, nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("应用") {
                    onApply(scheduledStart, TimeInterval(durationMinutes * 60))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
