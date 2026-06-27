import SwiftUI

extension LiveQuickRail {
    var overlayCard: some View {
        quickCard(title: "叠层", status: overlayStatusText, kind: overlayStatusKind) {
            compactOverlayRow(
                model: LiveOverlayRailRowModel.lowerThird(
                    presets: viewModel.lowerThirdPresets,
                    selectedID: viewModel.overlayComposerState.selectedLowerThirdPresetID,
                    isLive: viewModel.isLowerThirdVisible
                ),
                systemImage: OverlayComposerKind.lowerThird.systemImage
            ) {
                ForEach(viewModel.lowerThirdPresets) { preset in
                    Button {
                        viewModel.loadLowerThirdPreset(preset)
                        viewModel.showLowerThirdPreset(preset)
                    } label: {
                        Label(
                            preset.name,
                            systemImage: preset.id == viewModel.overlayComposerState.selectedLowerThirdPresetID ? "checkmark" : OverlayComposerKind.lowerThird.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isLowerThirdVisible {
                    viewModel.dismissLowerThird()
                } else if let preset = selectedLowerThirdPreset {
                    viewModel.showLowerThirdPreset(preset)
                }
            }

            compactOverlayRow(
                model: LiveOverlayRailRowModel.countdown(
                    presets: viewModel.countdownPresets,
                    selectedID: viewModel.overlayComposerState.selectedCountdownPresetID,
                    isLive: viewModel.isCountdownActive
                ),
                systemImage: OverlayComposerKind.countdown.systemImage
            ) {
                ForEach(viewModel.countdownPresets) { preset in
                    Button {
                        viewModel.loadCountdownPreset(preset)
                        viewModel.startCountdownPreset(preset)
                    } label: {
                        Label(
                            "\(preset.title) · \(formattedTime(preset.totalSeconds))",
                            systemImage: preset.id == viewModel.overlayComposerState.selectedCountdownPresetID ? "checkmark" : OverlayComposerKind.countdown.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isCountdownActive {
                    viewModel.stopCountdown()
                } else if let preset = selectedCountdownPreset {
                    viewModel.startCountdownPreset(preset)
                }
            }

            compactOverlayRow(
                model: LiveOverlayRailRowModel.ticker(
                    presets: viewModel.tickerPresets,
                    selectedID: viewModel.overlayComposerState.selectedTickerPresetID,
                    isLive: viewModel.isTickerActive
                ),
                systemImage: OverlayComposerKind.ticker.systemImage
            ) {
                ForEach(viewModel.tickerPresets) { preset in
                    Button {
                        viewModel.loadTickerPreset(preset)
                        viewModel.startTickerPreset(preset)
                    } label: {
                        Label(
                            "\(preset.text) · \(OverlaySpeedSelection.label(at: preset.speedIndex))",
                            systemImage: preset.id == viewModel.overlayComposerState.selectedTickerPresetID ? "checkmark" : OverlayComposerKind.ticker.systemImage
                        )
                    }
                }
            } onToggle: {
                if viewModel.isTickerActive {
                    viewModel.stopTicker()
                } else if let preset = selectedTickerPreset {
                    viewModel.startTickerPreset(preset)
                }
            }

            overlayClearAllButton
        }
    }

    private var overlayClearAllButton: some View {
        let hasActiveOverlay = overlayActiveCount > 0

        return Button {
            viewModel.clearAllOverlays()
        } label: {
            Label("全部清空", systemImage: "xmark.circle")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!hasActiveOverlay)
        .opacity(hasActiveOverlay ? 1 : 0.42)
        .help("关闭当前全部上屏叠层")
        .accessibilityLabel("全部清空叠层")
    }

    private func compactOverlayRow<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        @ViewBuilder menuContent: () -> MenuContent,
        onToggle: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            overlayPresetMenu(
                model: model,
                systemImage: systemImage,
                menuContent: menuContent
            )
            .frame(maxWidth: .infinity)

            Button(action: onToggle) {
                Text(model.toggleText)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(model.isLive ? StudioTheme.Tone.warn : StudioTheme.textTertiary)
                    .frame(width: 48, height: LiveModeLayoutMetrics.quickActionButtonHeight)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggle)
            .opacity(model.canToggle ? 1 : 0.48)
            .help(model.canToggle ? (model.isLive ? "停止\(model.title)" : "\(model.title)上屏") : model.disabledHint)
            .accessibilityLabel(model.isLive ? "停止\(model.title)" : "\(model.title)上屏")
            .accessibilityHint(model.canToggle ? model.presetLabel : model.disabledHint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.accessibilityLabel)
    }

    @ViewBuilder
    private func overlayPresetMenu<MenuContent: View>(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        switch model.presetInteraction {
        case .create(let kind):
            Button {
                openOverlaySetup(kind)
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: false)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("到叠层字幕页面新建\(model.title)。")
            .accessibilityLabel(model.presetLabel)
            .accessibilityHint("还没有保存\(model.title)预设。打开叠层字幕页面新建\(model.title)。")
        case .choose:
            Menu {
                menuContent()
            } label: {
                overlayPresetLabel(model: model, systemImage: systemImage, showsMenuIndicator: true)
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("\(model.title)预设")
            .accessibilityHint("选择一个已保存预设。")
        }
    }

    private func overlayPresetLabel(
        model: LiveOverlayRailRowModel,
        systemImage: String,
        showsMenuIndicator: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .accessibilityHidden(true)
            Text(model.presetLabel)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(model.isPlaceholder ? StudioTheme.textTertiary : StudioTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 2)
            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        .help(model.title)
    }

    private func openOverlaySetup(_ kind: OverlayComposerKind) {
        withAnimation(.easeInOut(duration: 0.16)) {
            viewModel.navigateToSetup(.overlays)
            viewModel.overlayComposerState.selectedKind = kind
        }
    }

    private var selectedLowerThirdPreset: LowerThirdPreset? {
        viewModel.lowerThirdPresets.first {
            $0.id == viewModel.overlayComposerState.selectedLowerThirdPresetID
        }
    }

    private var selectedCountdownPreset: CountdownPreset? {
        viewModel.countdownPresets.first {
            $0.id == viewModel.overlayComposerState.selectedCountdownPresetID
        }
    }

    private var selectedTickerPreset: TickerPreset? {
        viewModel.tickerPresets.first {
            $0.id == viewModel.overlayComposerState.selectedTickerPresetID
        }
    }


    private var overlayStatusText: String {
        overlayActiveCount == 0 ? "关闭" : "\(overlayActiveCount) 上屏"
    }

    private var overlayStatusKind: StudioTheme.StatusKind {
        overlayActiveCount > 0 ? .warn : .idle
    }

    private var overlayActiveCount: Int {
        [viewModel.isLowerThirdVisible, viewModel.isCountdownActive, viewModel.isTickerActive].filter { $0 }.count
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

}
