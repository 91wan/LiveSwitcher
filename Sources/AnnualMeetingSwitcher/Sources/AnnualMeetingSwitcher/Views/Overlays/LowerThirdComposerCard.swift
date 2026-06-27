import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct LowerThirdComposerCard: View {
    @Environment(SwitcherViewModel.self) private var viewModel

    private var composerState: OverlayComposerState {
        viewModel.overlayComposerState
    }

    var body: some View {
        OverlayComposerSection(
            kind: .lowerThird,
            isLive: viewModel.isLowerThirdVisible,
            hasDraftInput: !composerState.trimmedLowerThirdName.isEmpty,
            disabledReason: disabledReason
        ) {
            VStack(alignment: .leading, spacing: 10) {
                lowerThirdPresetShelf

                TextField("嘉宾姓名", text: composerBinding(\.lowerThirdNameDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                TextField("职位（可留空）", text: composerBinding(\.lowerThirdRoleDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                TextField("公司名称（可留空）", text: composerBinding(\.lowerThirdOrganizationDraft))
                    .textFieldStyle(.roundedBorder)
                    .font(StudioTheme.TypeScale.body)

                HStack(spacing: 10) {
                    OverlayActionButton(
                        title: "上屏",
                        systemImage: "arrow.up.to.line",
                        fill: StudioTheme.Action.primary,
                        isDisabled: disabledReason != nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showLowerThird(
                                name: composerState.lowerThirdNameDraft,
                                role: composerState.lowerThirdRoleDraft,
                                organization: composerState.lowerThirdOrganizationDraft
                            )
                        }
                    }

                    OverlayActionButton(
                        title: "关闭",
                        systemImage: "arrow.down.to.line",
                        fill: StudioTheme.Action.secondary,
                        isDisabled: !viewModel.isLowerThirdVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissLowerThird()
                        }
                    }
                }

                OverlayDisabledReasonText(reason: disabledReason)
            }
        }
    }

    private var disabledReason: String? {
        OverlayUIState.lowerThirdDisabledReason(
            name: composerState.lowerThirdNameDraft,
            isLive: viewModel.isLowerThirdVisible
        )
    }

    private var lowerThirdPresetShelf: some View {
        OverlayPresetList(
            title: "人名条预设",
            newTitle: "新建人名条",
            saveTitle: "保存预设",
            deleteTitle: "删除预设",
            emptyText: "暂无人名条预设",
            items: viewModel.lowerThirdPresets,
            selectedID: composerState.selectedLowerThirdPresetID,
            saveDisabled: composerState.trimmedLowerThirdName.isEmpty,
            deleteDisabled: composerState.selectedLowerThirdPresetID == nil,
            importTitle: "导入...",
            exportTitle: "导出...",
            exportDisabled: viewModel.lowerThirdPresets.isEmpty,
            rowMinWidth: 120,
            loadHelp: "载入人名条预设",
            onNew: viewModel.clearLowerThirdPresetDraft,
            onSave: { _ = viewModel.saveLowerThirdPresetFromDraft() },
            onDelete: {
                if let selectedID = composerState.selectedLowerThirdPresetID {
                    viewModel.deleteLowerThirdPreset(id: selectedID)
                }
            },
            onImport: importLowerThirdPresetsFromFile,
            onExport: exportLowerThirdPresets,
            onLoad: { preset in viewModel.loadLowerThirdPreset(preset) },
            accessibilityValue: lowerThirdPresetAccessibilityValue
        ) { preset in
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(StudioTheme.TypeScale.caption.weight(.black))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                let details = lowerThirdPresetDetails(preset)
                if !details.isEmpty {
                    Text(details)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func importLowerThirdPresetsFromFile() {
        let panel = NSOpenPanel()
        panel.title = "导入人名条发言人"
        panel.prompt = "导入"
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
        panel.title = "导出人名条发言人"
        panel.prompt = "导出"
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
            lowerThirdPresetAccessibilityValue(preset)
        }.joined(separator: "\n")

        let previewAlert = NSAlert()
        previewAlert.messageText = "导入 \(presets.count) 位人名条发言人？"
        previewAlert.informativeText = [sourceLabel, preview].filter { !$0.isEmpty }.joined(separator: "\n\n")
        previewAlert.addButton(withTitle: "导入")
        previewAlert.addButton(withTitle: "取消")
        guard previewAlert.runModal() == .alertFirstButtonReturn else {
            return
        }

        viewModel.importLowerThirdPresets(presets, duplicatePolicy: duplicatePolicy(for: presets))
    }

    private func lowerThirdPresetDetails(_ preset: LowerThirdPreset) -> String {
        [preset.role, preset.organization]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func lowerThirdPresetAccessibilityValue(_ preset: LowerThirdPreset) -> String {
        let details = lowerThirdPresetDetails(preset)
        return details.isEmpty ? preset.name : "\(preset.name), \(details)"
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
        alert.messageText = "已存在同名发言人"
        alert.informativeText = "请选择如何处理导入文件中同名的人名条发言人。"
        alert.addButton(withTitle: "跳过已有")
        alert.addButton(withTitle: "覆盖")
        alert.addButton(withTitle: "全部导入")

        switch alert.runModal() {
        case .alertSecondButtonReturn:
            return .overwriteExisting
        case .alertThirdButtonReturn:
            return .importAll
        default:
            return .skipExisting
        }
    }

    private func composerBinding<Value>(_ keyPath: WritableKeyPath<OverlayComposerState, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel.overlayComposerState[keyPath: keyPath] },
            set: { viewModel.overlayComposerState[keyPath: keyPath] = $0 }
        )
    }
}
