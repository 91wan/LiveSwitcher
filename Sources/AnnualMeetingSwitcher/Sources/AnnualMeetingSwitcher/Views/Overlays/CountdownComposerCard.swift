import SwiftUI

@MainActor
struct CountdownComposerCard: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    var body: some View {
        OverlayComposerSection(
            kind: .countdown,
            isLive: viewModel.isCountdownActive,
            hasDraftInput: composerState.countdownTotalSeconds > 0,
            disabledReason: disabledReason
        ) {
            VStack(alignment: .leading, spacing: 10) {
                countdownPresetShelf

                TextField("标题（如：活动即将开始）", text: composerBinding(\.countdownTitleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                HStack(spacing: 8) {
                    OverlayNumberInput(title: "分", value: composerBinding(\.countdownMinutesDraft))
                    Text(":")
                        .font(StudioTheme.TypeScale.heading.weight(.bold))
                        .foregroundStyle(.secondary)
                    OverlayNumberInput(title: "秒", value: composerBinding(\.countdownSecondsDraft))
                    Spacer()
                    if viewModel.isCountdownActive {
                        Text("剩余 \(overlayFormattedTime(viewModel.countdownSeconds))")
                            .font(StudioTheme.TypeScale.mono.weight(.bold))
                            .foregroundStyle(StudioTheme.Tone.warn)
                    }
                }

                HStack(spacing: 10) {
                    OverlayActionButton(
                        title: "上屏",
                        systemImage: "play.fill",
                        fill: StudioTheme.Action.primary,
                        isDisabled: disabledReason != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startCountdown(
                                minutes: composerState.countdownMinutesDraft,
                                seconds: composerState.countdownSecondsDraft,
                                title: composerState.countdownTitleDraft
                            )
                        }
                    }

                    OverlayActionButton(
                        title: "关闭",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isCountdownActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopCountdown()
                        }
                    }
                }

                OverlayDisabledReasonText(reason: disabledReason)
            }
        }
    }

    private var disabledReason: String? {
        OverlayUIState.countdownDisabledReason(
            minutes: composerState.countdownMinutesDraft,
            seconds: composerState.countdownSecondsDraft,
            isLive: viewModel.isCountdownActive
        )
    }

    private var countdownPresetShelf: some View {
        let saveDisabled = OverlayUIState.countdownDisabledReason(
            minutes: composerState.countdownMinutesDraft,
            seconds: composerState.countdownSecondsDraft,
            isLive: false
        ) != nil

        return OverlayPresetList(
            title: "倒计时预设",
            newTitle: "新建倒计时",
            saveTitle: "保存倒计时预设",
            deleteTitle: "删除倒计时预设",
            emptyText: "暂无倒计时预设",
            items: viewModel.countdownPresets,
            selectedID: composerState.selectedCountdownPresetID,
            saveDisabled: saveDisabled,
            deleteDisabled: composerState.selectedCountdownPresetID == nil,
            importTitle: nil,
            exportTitle: nil,
            exportDisabled: true,
            rowMinWidth: 120,
            loadHelp: "载入倒计时预设",
            onNew: viewModel.clearCountdownPresetDraft,
            onSave: { _ = viewModel.saveCountdownPresetFromDraft() },
            onDelete: {
                if let selectedID = composerState.selectedCountdownPresetID {
                    viewModel.deleteCountdownPreset(id: selectedID)
                }
            },
            onImport: nil,
            onExport: nil,
            onLoad: { preset in viewModel.loadCountdownPreset(preset) },
            accessibilityValue: { "\($0.title), \(overlayFormattedTime($0.totalSeconds))" }
        ) { preset in
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.title)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                Text(overlayFormattedTime(preset.totalSeconds))
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func composerBinding<Value>(_ keyPath: WritableKeyPath<OverlayComposerState, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.overlayComposerState[keyPath: keyPath] },
            set: { viewModel.overlayComposerState[keyPath: keyPath] = $0 }
        )
    }
}
