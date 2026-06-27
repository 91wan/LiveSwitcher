import SwiftUI

extension LiveQuickRail {
    var bgmCard: some View {
        let picker = LiveBGMQuickPickerModel.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem
        )
        let controls = BGMControlsState.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            isPlaying: viewModel.isBGMPlaying,
            phase: viewModel.runtime.state.bgm.phase
        )
        let playlist = LiveBGMPlaylistModel.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            selectedCategory: liveBGMCategory,
            isPlaying: viewModel.isBGMPlaying
        )

        return quickCard(title: "BGM", status: controls.displayStatusText, kind: controls.displayStatusKind) {
            Text(picker.currentTitle)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .help(picker.currentTitle)

            HStack(spacing: 6) {
                transportButton("gobackward", label: "回到开头", enabled: controls.canSeekToBeginning, disabledHint: controls.seekDisabledReason) {
                    viewModel.seekBGMToBeginning()
                }
                transportButton("backward.end.fill", label: "上一首", enabled: controls.canSkipPrevious, disabledHint: controls.skipDisabledReason) {
                    viewModel.playPreviousBGM()
                }
                transportButton(viewModel.isBGMPlaying ? "pause.fill" : "play.fill", label: viewModel.isBGMPlaying ? "暂停 BGM" : "播放 BGM", enabled: controls.canPlay, disabledHint: controls.playDisabledReason) {
                    if let item = BGMDefaultSelectionPolicy.defaultItem(
                        items: viewModel.bgmItems,
                        currentItem: viewModel.currentBGMItem,
                        selectedCategory: playlist.displayCategory
                    ) {
                        viewModel.toggleBGM(item)
                    }
                }
                transportButton("forward.end.fill", label: "下一首", enabled: controls.canSkipNext, disabledHint: controls.skipDisabledReason) {
                    viewModel.playNextBGM()
                }
            }

            bgmCategoryMenu(picker: picker, title: playlist.categoryButtonTitle)

            liveBGMPlaylistRows(playlist)

            fullBGMChooserButton()
        }
        .onAppear {
            syncLiveBGMCategoryToCurrent()
        }
        .onChange(of: viewModel.currentBGMItem?.id) { _, _ in
            syncLiveBGMCategoryToCurrent()
        }
    }

    private func bgmCategoryMenu(picker: LiveBGMQuickPickerModel, title: String) -> some View {
        Menu {
            if picker.isLibraryEmpty {
                Text("BGM 库为空")
            } else {
                ForEach(BGMCategory.allCases, id: \.self) { category in
                    if let section = picker.section(for: category) {
                        Button {
                            liveBGMCategory = category
                        } label: {
                            Label(section.title, systemImage: liveBGMCategory == category ? "checkmark" : "music.note.list")
                        }
                        .disabled(section.isEmpty)
                    }
                }
            }
        } label: {
            Text(title)
                .font(StudioTheme.TypeScale.label.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .frame(height: LiveModeLayoutMetrics.transportButtonSize)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("选择 BGM 分类")
    }

    private func fullBGMChooserButton() -> some View {
        Button {
            isBGMChooserPresented = true
        } label: {
            Label("全部曲目 · \(viewModel.bgmItems.count)", systemImage: "music.note.list")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(viewModel.bgmItems.isEmpty ? "曲库为空。" : "搜索并选择任意已有 BGM 曲目。")
        .accessibilityLabel("选择任意 BGM 曲目")
        .accessibilityValue("\(viewModel.bgmItems.count) 首")
        .popover(isPresented: $isBGMChooserPresented) {
            LiveBGMChooserPopover(
                searchText: $bgmChooserSearchText,
                selectedCategory: $bgmChooserCategory
            ) {
                isBGMChooserPresented = false
            }
        }
    }

    @ViewBuilder
    private func liveBGMPlaylistRows(_ playlist: LiveBGMPlaylistModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(playlist.displayCategory.rawValue)
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let remaining = playlist.remainingCountText {
                    Text(remaining)
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            if playlist.rows.isEmpty {
                Text(playlist.emptyMessage)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 26)
            } else {
                VStack(spacing: 3) {
                    ForEach(playlist.rows) { row in
                        Button {
                            viewModel.toggleBGM(row.item)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: row.systemImage)
                                    .font(StudioTheme.TypeScale.caption.weight(.black))
                                    .foregroundStyle(row.isCurrent ? StudioTheme.Action.primary : StudioTheme.textTertiary)
                                    .frame(width: 16)
                                    .accessibilityHidden(true)
                                Text(row.title)
                                    .font(StudioTheme.caption().weight(row.isCurrent ? .black : .semibold))
                                    .foregroundStyle(StudioTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6)
                            .frame(height: 28)
                            .background(
                                row.isCurrent ? StudioTheme.Action.primary.opacity(0.10) : StudioTheme.Surface.raised.opacity(0.58),
                                in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .help(row.title)
                        .accessibilityLabel(row.accessibilityLabel)
                    }
                }
            }
        }
    }

    private func syncLiveBGMCategoryToCurrent() {
        if let current = viewModel.currentBGMItem {
            liveBGMCategory = current.category
        }
    }
}
