import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct BGMPlaylistPanel: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            libraryContent
        }
        .frame(
            minWidth: 320,
            idealWidth: 420,
            maxWidth: .infinity
        )
        .background(StudioTheme.Surface.base)
        .clipShape(.rect(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(.clear, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: 8, x: 0, y: 2)
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            BGMPlaylistHeader(itemCount: viewModel.bgmItems.count, controls: bgmControlsState)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            BGMTransportControls(
                controls: bgmControlsState,
                isPlaying: viewModel.isBGMPlaying,
                playMode: viewModel.bgmPlayMode,
                defaultPlaybackItem: defaultPlaybackItem,
                onSeekToBeginning: viewModel.seekBGMToBeginning,
                onPrevious: viewModel.playPreviousBGM,
                onToggleDefault: viewModel.toggleBGM,
                onNext: viewModel.playNextBGM,
                onToggleLoopMode: viewModel.toggleLoopMode
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            BGMProgressRow(progressStore: viewModel.bgmProgressStore, canSeek: bgmControlsState.canSeekToBeginning) { progress in
                viewModel.seekBGM(toProgress: progress)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            BGMCategoryPicker(selectedCategory: selectedCategoryBinding)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            BGMTrackList(
                items: filteredBGMItems,
                viewModel: viewModel,
                selectedCategory: viewModel.bgmLibraryCategorySelection.selectedCategory
            )
            .padding(.horizontal, 16)

            BGMPanelStatusRow(controls: bgmControlsState)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            BGMImportControls(onOpenMusicPicker: openMusicPicker)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
    }

    private var filteredBGMItems: [BGMItem] {
        viewModel.bgmItems.filter { $0.category == viewModel.bgmLibraryCategorySelection.selectedCategory }
    }

    private var defaultPlaybackItem: BGMItem? {
        BGMDefaultSelectionPolicy.defaultItem(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            selectedCategory: viewModel.bgmLibraryCategorySelection.selectedCategory
        )
    }

    private var selectedCategoryBinding: Binding<BGMCategory> {
        Binding(
            get: { viewModel.bgmLibraryCategorySelection.selectedCategory },
            set: { viewModel.bgmLibraryCategorySelection.selectCategory($0) }
        )
    }

    private var bgmControlsState: BGMControlsState {
        BGMControlsState.make(
            items: viewModel.bgmItems,
            currentItem: viewModel.currentBGMItem,
            isPlaying: viewModel.isBGMPlaying,
            phase: viewModel.runtime.state.bgm.phase
        )
    }

    private func openMusicPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择音乐文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.audio, .mp3, .wav]
            guard panel.runModal() == .OK else { return }

            var existingItems = viewModel.bgmItems
            var importedItems: [BGMItem] = []
            for url in panel.urls {
                let title = url.deletingPathExtension().lastPathComponent
                guard BGMDuplicatePolicy.decision(for: url, existingItems: existingItems) != .duplicateURL else {
                    viewModel.recordSupportEvent(kind: .bgmImportSkippedDuplicate, detail: "reason=duplicateURL")
                    continue
                }
                let bgm = BGMItem(
                    title: title,
                    url: url,
                    category: viewModel.bgmLibraryCategorySelection.selectedCategory
                )
                importedItems.append(bgm)
                existingItems.append(bgm)
            }
            viewModel.addBGMItems(importedItems)
        }
    }
}

#Preview {
    BGMPlaylistPanel()
        .environment(SwitcherViewModel())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
