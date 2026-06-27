import SwiftUI

struct AgendaMarkerEditorPopover: View {
    enum Mode {
        case add
        case edit

        var title: String {
            switch self {
            case .add:
                return "添加标记"
            case .edit:
                return "编辑标记"
            }
        }

        var submitTitle: String {
            switch self {
            case .add:
                return "添加"
            case .edit:
                return "应用"
            }
        }
    }

    let mode: Mode
    let onApply: (AgendaMarkerInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var hasScheduledStart: Bool
    @State private var scheduledStart: Date
    @State private var durationMinutes: Int

    init(
        mode: Mode,
        initialInput: AgendaMarkerInput,
        onApply: @escaping (AgendaMarkerInput) -> Void
    ) {
        self.mode = mode
        self.onApply = onApply
        _title = State(initialValue: initialInput.title)
        _hasScheduledStart = State(initialValue: initialInput.scheduledStartAt != nil)
        _scheduledStart = State(initialValue: initialInput.scheduledStartAt ?? Date())
        _durationMinutes = State(initialValue: Self.durationMinutes(from: initialInput.duration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode.title)
                .font(StudioTheme.sectionTitle())
                .foregroundStyle(StudioTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("标题 *")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                TextField("例如：茶歇", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 6) {
                ForEach(["茶歇", "转场", "提醒"], id: \.self) { quickTitle in
                    Button(quickTitle) {
                        title = quickTitle
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Toggle("计划开始时间", isOn: $hasScheduledStart)
                .toggleStyle(.checkbox)

            if hasScheduledStart {
                DatePicker(
                    "开始",
                    selection: $scheduledStart,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
            }

            Stepper("时长 \(durationMinutes) 分钟", value: $durationMinutes, in: 1...999)
                .font(StudioTheme.body())

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(mode.submitTitle) {
                    guard let input = normalizedInput else { return }
                    onApply(input)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(normalizedInput == nil)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var normalizedInput: AgendaMarkerInput? {
        AgendaMarkerInput(
            title: title,
            scheduledStartAt: hasScheduledStart ? scheduledStart : nil,
            duration: TimeInterval(durationMinutes * 60)
        ).normalized()
    }

    private static func durationMinutes(from duration: TimeInterval) -> Int {
        let normalized = min(max(duration.isFinite ? duration : AgendaMarkerInput.defaultDuration, AgendaMarkerInput.minDuration), AgendaMarkerInput.maxDuration)
        return Int((normalized / 60).rounded())
    }
}

