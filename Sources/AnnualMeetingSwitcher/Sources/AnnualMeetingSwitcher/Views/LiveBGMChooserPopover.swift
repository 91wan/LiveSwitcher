import SwiftUI

@MainActor
struct LiveBGMChooserPopover: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    @Binding var searchText: String
    @Binding var selectedCategory: BGMCategory?
    let onSelect: () -> Void

    var body: some View {
        let model = LiveBGMChooserModel.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            phase: viewModel.runtime.state.bgm.phase,
            selectedCategory: selectedCategory,
            searchText: searchText
        )

        VStack(alignment: .leading, spacing: 10) {
            header(model)

            TextField("搜索曲目", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("搜索 BGM 曲目")

            HStack(spacing: 8) {
                Picker("分类", selection: $selectedCategory) {
                    Text("全部").tag(nil as BGMCategory?)
                    ForEach(BGMCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("筛选 BGM 分类")

                Spacer(minLength: 0)

                Text("\(model.filteredCount) / \(model.totalCount) 首")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .monospacedDigit()
            }

            if model.rows.isEmpty {
                chooserEmptyState(model)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 6) {
                        ForEach(model.rows) { row in
                            chooserRow(row)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 380)
            }
        }
        .padding(14)
        .frame(width: 440, height: 520, alignment: .top)
        .background(StudioTheme.Surface.base)
    }

    private func header(_ model: LiveBGMChooserModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("选择任意曲目")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("现场只选择已有 BGM，不编辑曲库。")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            Spacer(minLength: 0)
            CountPill("\(model.totalCount)", kind: model.totalCount == 0 ? .warn : .ready)
        }
    }

    private func chooserEmptyState(_ model: LiveBGMChooserModel) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(StudioTheme.TypeScale.title.weight(.bold))
                .foregroundStyle(StudioTheme.textTertiary)
            Text(model.emptyTitle)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .foregroundStyle(StudioTheme.textPrimary)
            Text(model.emptyMessage)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.emptyTitle)，\(model.emptyMessage)")
    }

    private func chooserRow(_ row: LiveBGMChooserModel.Row) -> some View {
        Button {
            viewModel.toggleBGM(row.item)
            onSelect()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: row.systemImage)
                    .font(StudioTheme.TypeScale.body.weight(.black))
                    .foregroundStyle(row.isCurrent ? StudioTheme.Action.primary : StudioTheme.textTertiary)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(StudioTheme.TypeScale.body.weight(row.isCurrent ? .black : .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(row.categoryTitle)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(row.stateText)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(row.isCurrent ? StudioTheme.Action.primary : StudioTheme.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 46)
            .background(
                row.isCurrent ? StudioTheme.Action.primary.opacity(0.10) : StudioTheme.Surface.raised.opacity(0.72),
                in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .stroke(row.isCurrent ? StudioTheme.Action.primary.opacity(0.32) : StudioTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(row.title)
        .accessibilityLabel(row.accessibilityLabel)
    }
}
