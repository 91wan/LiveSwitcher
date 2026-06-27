import SwiftUI

@MainActor
struct TickerComposerCard: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    var body: some View {
        OverlayComposerSection(
            kind: .ticker,
            isLive: viewModel.isTickerActive,
            hasDraftInput: !composerState.trimmedTickerText.isEmpty,
            disabledReason: disabledReason
        ) {
            VStack(alignment: .leading, spacing: 10) {
                tickerPresetShelf

                TextEditor(text: composerBinding(\.tickerTextDraft))
                    .font(StudioTheme.TypeScale.body)
                    .frame(height: 76)
                    .padding(6)
                    .background(StudioTheme.Surface.raised)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .stroke(StudioTheme.borderSubtle, lineWidth: 1)
                    )

                HStack {
                    Text("速度")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Picker("", selection: composerBinding(\.tickerSpeedIndex)) {
                        ForEach(OverlaySpeedSelection.options.indices, id: \.self) { index in
                            Text(OverlaySpeedSelection.label(at: index)).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: composerState.tickerSpeedIndex) { _, index in
                        viewModel.tickerSpeed = OverlaySpeedSelection.speed(at: index)
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
                            viewModel.startTicker(text: composerState.tickerTextDraft)
                        }
                    }

                    OverlayActionButton(
                        title: "关闭",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isTickerActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopTicker()
                        }
                    }
                }

                OverlayDisabledReasonText(reason: disabledReason)
            }
        }
    }

    private var disabledReason: String? {
        OverlayUIState.tickerDisabledReason(
            text: composerState.tickerTextDraft,
            isLive: viewModel.isTickerActive
        )
    }

    private var tickerPresetShelf: some View {
        let saveDisabled = OverlayUIState.tickerDisabledReason(
            text: composerState.tickerTextDraft,
            isLive: false
        ) != nil

        return OverlayPresetList(
            title: "游动字幕预设",
            newTitle: "新建游动字幕",
            saveTitle: "保存游动字幕预设",
            deleteTitle: "删除游动字幕预设",
            emptyText: "暂无游动字幕预设",
            items: viewModel.tickerPresets,
            selectedID: composerState.selectedTickerPresetID,
            saveDisabled: saveDisabled,
            deleteDisabled: composerState.selectedTickerPresetID == nil,
            importTitle: nil,
            exportTitle: nil,
            exportDisabled: true,
            rowMinWidth: 150,
            loadHelp: "载入游动字幕预设",
            onNew: viewModel.clearTickerPresetDraft,
            onSave: { _ = viewModel.saveTickerPresetFromDraft() },
            onDelete: {
                if let selectedID = composerState.selectedTickerPresetID {
                    viewModel.deleteTickerPreset(id: selectedID)
                }
            },
            onImport: nil,
            onExport: nil,
            onLoad: { preset in viewModel.loadTickerPreset(preset) },
            accessibilityValue: { "\($0.text)，速度 \(OverlaySpeedSelection.label(at: $0.speedIndex))" }
        ) { preset in
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.text)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                Text("速度：\(OverlaySpeedSelection.label(at: preset.speedIndex))")
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
