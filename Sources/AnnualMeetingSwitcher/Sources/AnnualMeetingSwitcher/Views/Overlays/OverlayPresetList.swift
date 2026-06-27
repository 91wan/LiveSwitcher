import SwiftUI

struct OverlayPresetList<Item: Identifiable, RowContent: View>: View where Item.ID: Equatable {
    let title: String
    let newTitle: String
    let saveTitle: String
    let deleteTitle: String
    let emptyText: String
    let items: [Item]
    let selectedID: Item.ID?
    let saveDisabled: Bool
    let deleteDisabled: Bool
    let importTitle: String?
    let exportTitle: String?
    let exportDisabled: Bool
    let rowMinWidth: CGFloat
    let loadHelp: String
    let onNew: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    let onImport: (() -> Void)?
    let onExport: (() -> Void)?
    let onLoad: (Item) -> Void
    let accessibilityValue: (Item) -> String
    @ViewBuilder let rowContent: (Item) -> RowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerActions
            secondaryActions
            listContent
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            presetButton(title: newTitle, systemImage: "plus", action: onNew)
            presetButton(title: saveTitle, systemImage: "tray.and.arrow.down.fill", prominent: true, isDisabled: saveDisabled, action: onSave)
            presetButton(title: deleteTitle, systemImage: "trash", isDisabled: deleteDisabled, action: onDelete)
        }
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if let importTitle, let onImport, let exportTitle, let onExport {
            HStack(spacing: 8) {
                presetButton(title: importTitle, systemImage: "square.and.arrow.down", action: onImport)
                presetButton(title: exportTitle, systemImage: "square.and.arrow.up", isDisabled: exportDisabled, action: onExport)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        presetRow(for: item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func presetRow(for item: Item) -> some View {
        let isSelected = item.id == selectedID
        return Button {
            onLoad(item)
        } label: {
            rowContent(item)
                .frame(minWidth: rowMinWidth, alignment: .leading)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    isSelected ? StudioTheme.Action.primary.opacity(0.14) : StudioTheme.Surface.raised,
                    in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .stroke(isSelected ? StudioTheme.Action.primary.opacity(0.45) : StudioTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(loadHelp)
        .accessibilityLabel(loadHelp)
        .accessibilityValue(accessibilityValue(item))
    }

    @ViewBuilder
    private func presetButton(
        title: String,
        systemImage: String,
        prominent: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(StudioTheme.Action.primary)
            .disabled(isDisabled)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isDisabled)
        }
    }
}
