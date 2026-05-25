import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 叠层控制面板

struct OverlayControlPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    private var activeOverlayCount: Int {
        [
            viewModel.isLowerThirdVisible,
            viewModel.isCountdownActive,
            viewModel.isTickerActive
        ].filter { $0 }.count
    }

    private var hasActiveOverlay: Bool {
        activeOverlayCount > 0
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                composerColumn
                    .frame(minWidth: 420, maxWidth: 560)
                livePreviewColumn
                    .frame(minWidth: 360, maxWidth: 460)
            }

            VStack(alignment: .leading, spacing: 18) {
                composerColumn
                livePreviewColumn
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusXL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: 18, x: 0, y: 10)
        .onAppear {
            syncTickerSpeedFromViewModel()
        }
        .onChange(of: viewModel.tickerSpeed) { _, _ in
            syncTickerSpeedFromViewModel()
        }
    }

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    private func composerBinding<Value>(_ keyPath: WritableKeyPath<OverlayComposerState, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.overlayComposerState[keyPath: keyPath] },
            set: { viewModel.overlayComposerState[keyPath: keyPath] = $0 }
        )
    }

    private var composerColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            composerPicker
            activeComposerCard
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .fill(StudioTheme.Action.primary.opacity(0.12))
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(StudioTheme.TypeScale.title.weight(.bold))
                    .foregroundStyle(StudioTheme.Action.primary)
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text("Overlay Composer")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(.primary)
                Text("一次准备一种叠层；Preview 和 Active Stack 会显示当前上屏状态。")
                    .font(StudioTheme.TypeScale.body.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasActiveOverlay {
                StatusBadge("\(activeOverlayCount) LIVE", kind: .live)
            }
        }
    }

    private var composerPicker: some View {
        Picker("Overlay composer", selection: composerBinding(\.selectedKind)) {
            ForEach(OverlayComposerKind.allCases) { kind in
                Label(kind.pickerTitle, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: composerState.selectedKind) { _, newKind in
            viewModel.overlayComposerState.select(newKind)
        }
        .accessibilityLabel("Overlay composer")
    }

    @ViewBuilder
    private var activeComposerCard: some View {
        switch composerState.selectedKind {
        case .lowerThird:
            lowerThirdEditor
        case .countdown:
            countdownEditor
        case .ticker:
            tickerEditor
        }
    }

    private var lowerThirdEditor: some View {
        overlaySection(
            kind: .lowerThird,
            isLive: viewModel.isLowerThirdVisible,
            hasDraftInput: !composerState.trimmedLowerThirdName.isEmpty,
            disabledReason: OverlayUIState.lowerThirdDisabledReason(
                name: composerState.lowerThirdNameDraft,
                isLive: viewModel.isLowerThirdVisible
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                lowerThirdPresetShelf

                TextField("嘉宾姓名", text: composerBinding(\.lowerThirdNameDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                TextField("职务 / 单位（可留空）", text: composerBinding(\.lowerThirdTitleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "arrow.up.to.line",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.lowerThirdDisabledReason(
                            name: composerState.lowerThirdNameDraft,
                            isLive: viewModel.isLowerThirdVisible
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showLowerThird(
                                name: composerState.lowerThirdNameDraft,
                                title: composerState.lowerThirdTitleDraft
                            )
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "arrow.down.to.line",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isLowerThirdVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissLowerThird()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.lowerThirdDisabledReason(
                        name: composerState.lowerThirdNameDraft,
                        isLive: viewModel.isLowerThirdVisible
                    )
                )
            }
        }
    }

    private var lowerThirdPresetShelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Lower Third Presets")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button {
                        viewModel.clearLowerThirdPresetDraft()
                    } label: {
                        Label("New Preset", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        _ = viewModel.saveLowerThirdPresetFromDraft()
                    } label: {
                        Label("Save Preset", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(StudioTheme.Action.primary)
                    .disabled(composerState.trimmedLowerThirdName.isEmpty)

                    Button {
                        if let selectedID = composerState.selectedLowerThirdPresetID {
                            viewModel.deleteLowerThirdPreset(id: selectedID)
                        }
                    } label: {
                        Label("Delete Preset", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(composerState.selectedLowerThirdPresetID == nil)
                }

                HStack(spacing: 8) {
                    Button {
                        importLowerThirdPresetsFromFile()
                    } label: {
                        Label("Import...", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        exportLowerThirdPresets()
                    } label: {
                        Label("Export...", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.lowerThirdPresets.isEmpty)

                    Spacer(minLength: 0)
                }
            }

            if viewModel.lowerThirdPresets.isEmpty {
                Text("No saved lower thirds")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.lowerThirdPresets) { preset in
                            Button {
                                viewModel.loadLowerThirdPreset(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name)
                                        .font(StudioTheme.TypeScale.caption.weight(.black))
                                        .foregroundStyle(StudioTheme.textPrimary)
                                        .lineLimit(1)
                                    if !preset.subtitle.isEmpty {
                                        Text(preset.subtitle)
                                            .font(StudioTheme.caption())
                                            .foregroundStyle(StudioTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 10)
                                .background(
                                    preset.id == composerState.selectedLowerThirdPresetID
                                    ? StudioTheme.Action.primary.opacity(0.14)
                                    : StudioTheme.Surface.raised,
                                    in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                        .stroke(
                                            preset.id == composerState.selectedLowerThirdPresetID
                                            ? StudioTheme.Action.primary.opacity(0.45)
                                            : StudioTheme.borderSubtle,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Load lower third preset")
                            .accessibilityLabel("Load lower third preset")
                            .accessibilityValue(preset.subtitle.isEmpty ? preset.name : "\(preset.name), \(preset.subtitle)")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func importLowerThirdPresetsFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Lower Third Speakers"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .plainText]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let data = try? Data(contentsOf: url),
              let presets = try? SpeakerImportService.parse(data: data) else {
            NSSound.beep()
            return
        }

        confirmAndImportSpeakerPresets(presets, sourceLabel: url.lastPathComponent)
    }

    private func exportLowerThirdPresets() {
        let panel = NSSavePanel()
        panel.title = "Export Lower Third Speakers"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "lower-third-speakers.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            try viewModel.exportLowerThirdPresetsCSV().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    private func confirmAndImportSpeakerPresets(_ presets: [LowerThirdPreset], sourceLabel: String) {
        let preview = presets.prefix(5).map { preset in
            preset.subtitle.isEmpty ? preset.name : "\(preset.name) - \(preset.subtitle)"
        }.joined(separator: "\n")

        let previewAlert = NSAlert()
        previewAlert.messageText = "Import \(presets.count) lower third speakers?"
        previewAlert.informativeText = [sourceLabel, preview].filter { !$0.isEmpty }.joined(separator: "\n\n")
        previewAlert.addButton(withTitle: "Import")
        previewAlert.addButton(withTitle: "Cancel")
        guard previewAlert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let policy = duplicatePolicy(for: presets)
        viewModel.importLowerThirdPresets(presets, duplicatePolicy: policy)
    }

    private func duplicatePolicy(for presets: [LowerThirdPreset]) -> SpeakerImportDuplicatePolicy {
        let existingNames = Set(viewModel.lowerThirdPresets.map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        let hasConflicts = presets.contains {
            existingNames.contains($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
        guard hasConflicts else {
            return .skipExisting
        }

        let alert = NSAlert()
        alert.messageText = "Matching speaker names already exist"
        alert.informativeText = "Choose how to handle imported lower-third speakers with the same trimmed name."
        alert.addButton(withTitle: "Skip Existing")
        alert.addButton(withTitle: "Overwrite")
        alert.addButton(withTitle: "Import All")

        switch alert.runModal() {
        case .alertSecondButtonReturn:
            return .overwriteExisting
        case .alertThirdButtonReturn:
            return .importAll
        default:
            return .skipExisting
        }
    }

    private var countdownEditor: some View {
        overlaySection(
            kind: .countdown,
            isLive: viewModel.isCountdownActive,
            hasDraftInput: composerState.countdownTotalSeconds > 0,
            disabledReason: OverlayUIState.countdownDisabledReason(
                minutes: composerState.countdownMinutesDraft,
                seconds: composerState.countdownSecondsDraft,
                isLive: viewModel.isCountdownActive
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                countdownPresetShelf

                TextField("标题（如：活动即将开始）", text: composerBinding(\.countdownTitleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                HStack(spacing: 8) {
                    numberInput(title: "分", value: composerBinding(\.countdownMinutesDraft))
                    Text(":")
                        .font(StudioTheme.TypeScale.heading.weight(.bold))
                        .foregroundStyle(.secondary)
                    numberInput(title: "秒", value: composerBinding(\.countdownSecondsDraft))
                    Spacer()
                    if viewModel.isCountdownActive {
                        Text("剩余 \(formattedTime(viewModel.countdownSeconds))")
                            .font(StudioTheme.TypeScale.mono.weight(.bold))
                            .foregroundStyle(StudioTheme.Tone.warn)
                    }
                }

                HStack(spacing: 10) {
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "play.fill",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.countdownDisabledReason(
                            minutes: composerState.countdownMinutesDraft,
                            seconds: composerState.countdownSecondsDraft,
                            isLive: viewModel.isCountdownActive
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startCountdown(
                                minutes: composerState.countdownMinutesDraft,
                                seconds: composerState.countdownSecondsDraft,
                                title: composerState.countdownTitleDraft
                            )
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isCountdownActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopCountdown()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.countdownDisabledReason(
                        minutes: composerState.countdownMinutesDraft,
                        seconds: composerState.countdownSecondsDraft,
                        isLive: viewModel.isCountdownActive
                    )
                )
            }
        }
    }

    private var countdownPresetShelf: some View {
        let disabledReason = OverlayUIState.countdownDisabledReason(
            minutes: composerState.countdownMinutesDraft,
            seconds: composerState.countdownSecondsDraft,
            isLive: false
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Countdown Presets")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textSecondary)

                Spacer()

                Button {
                    viewModel.clearCountdownPresetDraft()
                } label: {
                    Label("New Countdown Preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    _ = viewModel.saveCountdownPresetFromDraft()
                } label: {
                    Label("Save Countdown Preset", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Action.primary)
                .disabled(disabledReason != nil)

                Button {
                    if let selectedID = composerState.selectedCountdownPresetID {
                        viewModel.deleteCountdownPreset(id: selectedID)
                    }
                } label: {
                    Label("Delete Countdown Preset", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(composerState.selectedCountdownPresetID == nil)
            }

            if viewModel.countdownPresets.isEmpty {
                Text("No saved countdowns")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.countdownPresets) { preset in
                            Button {
                                viewModel.loadCountdownPreset(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.title)
                                        .font(StudioTheme.TypeScale.caption.weight(.black))
                                        .foregroundStyle(StudioTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(formattedTime(preset.totalSeconds))
                                        .font(StudioTheme.caption())
                                        .foregroundStyle(StudioTheme.textTertiary)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 120, alignment: .leading)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 10)
                                .background(
                                    preset.id == composerState.selectedCountdownPresetID
                                    ? StudioTheme.Action.primary.opacity(0.14)
                                    : StudioTheme.Surface.raised,
                                    in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                        .stroke(
                                            preset.id == composerState.selectedCountdownPresetID
                                            ? StudioTheme.Action.primary.opacity(0.45)
                                            : StudioTheme.borderSubtle,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Load countdown preset")
                            .accessibilityLabel("Load countdown preset")
                            .accessibilityValue("\(preset.title), \(formattedTime(preset.totalSeconds))")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var tickerEditor: some View {
        overlaySection(
            kind: .ticker,
            isLive: viewModel.isTickerActive,
            hasDraftInput: !composerState.trimmedTickerText.isEmpty,
            disabledReason: OverlayUIState.tickerDisabledReason(
                text: composerState.tickerTextDraft,
                isLive: viewModel.isTickerActive
            )
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
                    overlayActionButton(
                        title: "Send Live",
                        systemImage: "play.fill",
                        fill: StudioTheme.Action.primary,
                        isDisabled: OverlayUIState.tickerDisabledReason(
                            text: composerState.tickerTextDraft,
                            isLive: viewModel.isTickerActive
                        ) != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.startTicker(text: composerState.tickerTextDraft)
                        }
                    }

                    overlayActionButton(
                        title: "Stop",
                        systemImage: "stop.fill",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isTickerActive
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.stopTicker()
                        }
                    }
                }

                disabledReasonText(
                    OverlayUIState.tickerDisabledReason(
                        text: composerState.tickerTextDraft,
                        isLive: viewModel.isTickerActive
                    )
                )
            }
        }
    }

    private var tickerPresetShelf: some View {
        let disabledReason = OverlayUIState.tickerDisabledReason(
            text: composerState.tickerTextDraft,
            isLive: false
        )

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Ticker Presets")
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textSecondary)

                Spacer()

                Button {
                    viewModel.clearTickerPresetDraft()
                } label: {
                    Label("New Ticker Preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    _ = viewModel.saveTickerPresetFromDraft()
                } label: {
                    Label("Save Ticker Preset", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(StudioTheme.Action.primary)
                .disabled(disabledReason != nil)

                Button {
                    if let selectedID = composerState.selectedTickerPresetID {
                        viewModel.deleteTickerPreset(id: selectedID)
                    }
                } label: {
                    Label("Delete Ticker Preset", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(composerState.selectedTickerPresetID == nil)
            }

            if viewModel.tickerPresets.isEmpty {
                Text("No saved tickers")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tickerPresets) { preset in
                            Button {
                                viewModel.loadTickerPreset(preset)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.text)
                                        .font(StudioTheme.TypeScale.caption.weight(.black))
                                        .foregroundStyle(StudioTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("Speed: \(OverlaySpeedSelection.label(at: preset.speedIndex))")
                                        .font(StudioTheme.caption())
                                        .foregroundStyle(StudioTheme.textTertiary)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 150, alignment: .leading)
                                .padding(.vertical, 7)
                                .padding(.horizontal, 10)
                                .background(
                                    preset.id == composerState.selectedTickerPresetID
                                    ? StudioTheme.Action.primary.opacity(0.14)
                                    : StudioTheme.Surface.raised,
                                    in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                                        .stroke(
                                            preset.id == composerState.selectedTickerPresetID
                                            ? StudioTheme.Action.primary.opacity(0.45)
                                            : StudioTheme.borderSubtle,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help("Load ticker preset")
                            .accessibilityLabel("Load ticker preset")
                            .accessibilityValue("\(preset.text), speed \(OverlaySpeedSelection.label(at: preset.speedIndex))")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var livePreviewColumn: some View {
        let previewModel = livePreviewModel
        let isEmptyPreview = previewModel.layers.isEmpty

        return StudioSectionCard(
            title: "Live Preview",
            subtitle: "16:9 preview and active overlay stack",
            status: (hasActiveOverlay ? "\(activeOverlayCount) LIVE" : "OFF", hasActiveOverlay ? .live : .idle)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OverlayLivePreviewCanvas(model: previewModel)
                    .frame(maxWidth: isEmptyPreview ? 320 : .infinity)
                    .frame(height: isEmptyPreview ? 180 : nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                activeStackCard
            }
        }
    }

    private var activeStackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Active Stack")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.clearAllOverlays()
                    }
                } label: {
                    Label("Clear All", systemImage: "xmark.circle.fill")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!hasActiveOverlay)
            }

            activeOverlaySummaryRow(title: "Lower Third", isLive: viewModel.isLowerThirdVisible)
            activeOverlaySummaryRow(title: "Countdown", isLive: viewModel.isCountdownActive)
            activeOverlaySummaryRow(title: "Ticker", isLive: viewModel.isTickerActive)
        }
        .padding(12)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
    }

    private var livePreviewModel: OverlayLivePreviewModel {
        OverlayLivePreviewModel.make(
            isLowerThirdVisible: viewModel.isLowerThirdVisible,
            lowerThirdName: viewModel.lowerThirdName,
            lowerThirdTitle: viewModel.lowerThirdTitle,
            isCountdownActive: viewModel.isCountdownActive,
            countdownSeconds: viewModel.countdownSeconds,
            countdownTitle: viewModel.countdownTitle,
            isTickerActive: viewModel.isTickerActive,
            tickerText: viewModel.tickerText,
            composerState: composerState
        )
    }

    private func activeOverlaySummaryRow(title: String, isLive: Bool) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            if isLive {
                StatusBadge("LIVE", kind: .live)
            } else {
                Text("OFF")
                    .font(StudioTheme.caption().weight(.semibold))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
        }
    }

    private func overlaySection<Content: View>(
        kind: OverlayComposerKind,
        isLive: Bool,
        hasDraftInput: Bool,
        disabledReason: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(kind.title, systemImage: kind.systemImage)
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                statusBadge(
                    title: OverlayComposerStatus.text(
                        isLive: isLive,
                        hasDraftInput: hasDraftInput,
                        disabledReason: disabledReason
                    ),
                    isLive: isLive
                )
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(isLive ? StudioTheme.borderCritical.opacity(0.50) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func statusBadge(title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? StudioTheme.Tone.live : StudioTheme.Tone.idle.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(title)
                .font(StudioTheme.TypeScale.label.weight(.black))
        }
        .foregroundStyle(isLive ? StudioTheme.Tone.live : StudioTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isLive ? StudioTheme.Tone.live.opacity(0.12) : StudioTheme.Surface.raised)
        )
    }

    @ViewBuilder
    private func disabledReasonText(_ reason: String?) -> some View {
        if let reason {
            Text(reason)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
    }

    private func numberInput(title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
                .multilineTextAlignment(.center)
                .font(StudioTheme.TypeScale.mono.weight(.medium))
            Text(title)
                .font(StudioTheme.TypeScale.body.weight(.medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func overlayActionButton(
        title: String,
        systemImage: String,
        fill: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(StudioTheme.TypeScale.body.weight(.bold))
                .foregroundStyle(isDisabled ? .white.opacity(0.55) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .fill(isDisabled ? fill.opacity(0.25) : fill)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "This overlay action is currently unavailable." : "Run overlay action.")
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func syncTickerSpeedFromViewModel() {
        let index = OverlaySpeedSelection.nearestIndex(for: viewModel.tickerSpeed)
        viewModel.overlayComposerState.tickerSpeedIndex = index
        let normalizedSpeed = OverlaySpeedSelection.speed(at: index)
        if viewModel.tickerSpeed != normalizedSpeed {
            viewModel.tickerSpeed = normalizedSpeed
        }
    }
}
