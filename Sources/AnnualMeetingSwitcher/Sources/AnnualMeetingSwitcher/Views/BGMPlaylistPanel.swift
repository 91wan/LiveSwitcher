import SwiftUI
import UniformTypeIdentifiers

// MARK: - 音乐播放列表面板（V20：独立一栏，夹在监视器与音频推子之间）

enum BGMPlaylistPanelMode {
    case library
    case liveDock
}

struct BGMPlaylistPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var bgmCategory: BGMCategory = .warmUp
    @State private var didManuallySelectBGMCategory = false

    let mode: BGMPlaylistPanelMode

    init(mode: BGMPlaylistPanelMode = .library) {
        self.mode = mode
    }

    var body: some View {
        Group {
            if mode == .liveDock {
                panelContent
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    panelContent
                }
            }
        }
        .frame(
            minWidth: mode == .liveDock ? 0 : 260,
            idealWidth: mode == .liveDock ? StudioTheme.directorRailWidth : 272,
            maxWidth: mode == .liveDock ? .infinity : 292
        )
        .background(mode == .liveDock ? StudioTheme.surfacePrimary.opacity(0.78) : StudioTheme.surfacePrimary)
        .clipShape(.rect(cornerRadius: mode == .liveDock ? StudioTheme.radiusXL : StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: mode == .liveDock ? StudioTheme.radiusXL : StudioTheme.radiusM, style: .continuous)
                .stroke(mode == .liveDock ? StudioTheme.borderSubtle : .clear, lineWidth: 1)
        )
        .shadow(color: StudioTheme.shadowSoft, radius: mode == .liveDock ? 6 : 8, x: 0, y: 2)
        .onAppear {
            syncLiveDockCategoryWithCurrentTrack()
        }
        .onChange(of: viewModel.currentBGMItem) { _, _ in
            syncLiveDockCategoryWithCurrentTrack()
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if mode == .liveDock {
            liveDockContent
        } else {
            libraryContent
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            bgmControlButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            bgmProgressBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()

            categoryPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            bgmList
                .padding(.horizontal, 16)

            statusRow
                .padding(.horizontal, 16)
                .padding(.top, 10)

            addMusicButton
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 14)
        }
    }

    private var liveDockContent: some View {
        VStack(spacing: 0) {
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            currentTrackStrip
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            bgmControlButtons
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            bgmProgressBar
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                statusRow
                Spacer(minLength: 0)
                categoryPicker
                    .frame(maxWidth: 144)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            bgmList
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            addMusicButton
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    // MARK: - 标题行

    private var headerRow: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(mode == .liveDock ? "现场 BGM" : "音乐播放机")
                    .font(mode == .liveDock ? StudioTheme.sectionTitle() : StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(viewModel.bgmItems.count) 首已入库")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                StatusBadge(viewModel.isBGMPlaying ? "Playing" : "Ready", kind: viewModel.isBGMPlaying ? .live : .ready)
            }
        }
    }

    private var currentTrackStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.isBGMPlaying ? "waveform" : "music.note")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(viewModel.isBGMPlaying ? StudioTheme.statusLive : StudioTheme.textSecondary)
                .frame(width: 24, height: 24)
                .background(StudioTheme.surfacePrimary, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(currentTrackTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(viewModel.isBGMPlaying ? "Playing now" : "Ready for live playback")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill((viewModel.isBGMPlaying ? StudioTheme.statusLive : StudioTheme.actionPrimary).opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(viewModel.isBGMPlaying ? StudioTheme.statusLive.opacity(0.22) : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current BGM: \(currentTrackTitle)")
    }

    private var currentTrackTitle: String {
        viewModel.currentBGMItem?.title ?? "No BGM selected"
    }

    // MARK: - BGM 五颗大媒体控制键（V20 新增"跳回开头"）

    private var bgmControlButtons: some View {
        let diskSize: CGFloat = mode == .liveDock ? 30 : 32
        let iconSize: CGFloat = mode == .liveDock ? 18 : 20
        let playSize: CGFloat = mode == .liveDock ? 32 : 34
        let controls = BGMControlsState.make(items: viewModel.bgmItems, currentItem: viewModel.currentBGMItem)

        return HStack(spacing: 8) {
            Spacer()

            // 跳回开头（V20 新增）
            Button(action: { viewModel.seekBGMToBeginning() }) {
                Image(systemName: "backward.end.alt.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSeekToBeginning)
            .opacity(controls.canSeekToBeginning ? 1 : 0.38)
            .help("跳回开头")
            .accessibilityLabel("BGM seek to beginning")
            .accessibilityHint(controls.canSeekToBeginning ? "Seek the current BGM track to the beginning." : "Select or start a BGM track before seeking.")

            // 上一首
            Button(action: { viewModel.playPreviousBGM() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipPrevious)
            .opacity(controls.canSkipPrevious ? 1 : 0.38)
            .help("上一首")
            .accessibilityLabel("Previous BGM track")
            .accessibilityHint(controls.canSkipPrevious ? "Play the previous BGM track in the current category." : "Add another track in the current BGM category before skipping.")

            // 播放 / 暂停
            Button(action: {
                if let current = viewModel.currentBGMItem {
                    viewModel.toggleBGM(current)
                } else if let first = viewModel.bgmItems.first {
                    viewModel.toggleBGM(first)
                }
            }) {
                Image(systemName: viewModel.isBGMPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: playSize))
                    .foregroundStyle(viewModel.isBGMPlaying ? StudioTheme.statusLive : StudioTheme.actionPrimary)
            }
            .buttonStyle(.plain)
            .disabled(!controls.canPlay)
            .opacity(controls.canPlay ? 1 : 0.38)
            .help(viewModel.isBGMPlaying ? "暂停 BGM" : "播放 BGM")
            .accessibilityLabel(viewModel.isBGMPlaying ? "Pause BGM" : "Play BGM")
            .accessibilityHint(controls.canPlay ? "Start or pause BGM playback." : "Add a BGM track before starting playback.")

            // 下一首
            Button(action: { viewModel.playNextBGM() }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipNext)
            .opacity(controls.canSkipNext ? 1 : 0.38)
            .help("下一首")
            .accessibilityLabel("Next BGM track")
            .accessibilityHint(controls.canSkipNext ? "Play the next BGM track in the current category." : "Add another track in the current BGM category before skipping.")

            // 循环模式
            Button(action: { viewModel.toggleLoopMode() }) {
                Image(systemName: viewModel.bgmPlayMode == .loopOne ? "repeat.1" : "repeat")
                    .font(.system(size: iconSize))
                    .foregroundStyle(viewModel.bgmPlayMode == .sequential ? StudioTheme.textSecondary : StudioTheme.actionPrimary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.bgmItems.isEmpty)
            .opacity(viewModel.bgmItems.isEmpty ? 0.38 : 1)
            .help(viewModel.bgmPlayMode.rawValue)
            .accessibilityLabel("BGM loop mode")
            .accessibilityValue(viewModel.bgmPlayMode.rawValue)
            .accessibilityHint(viewModel.bgmItems.isEmpty ? "Add BGM tracks before changing loop mode." : "Change BGM loop mode.")

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.surfaceSecondary)
        )
    }

    // MARK: - V24 BGM 播放进度条（可拖拽）

    private var bgmProgressBar: some View {
        VStack(spacing: 4) {
            // 可拖拽进度滑块
            Slider(
                value: Binding(
                    get: { viewModel.bgmProgress },
                    set: { newVal in
                        viewModel.bgmProgress = newVal
                        if let player = viewModel.bgmAudioPlayer {
                            player.currentTime = player.duration * newVal
                            viewModel.bgmCurrentTime = player.currentTime
                        }
                    }
                ),
                in: 0...1
            )
            .tint(StudioTheme.actionPrimary)
            .frame(height: 20)
            .disabled(viewModel.currentBGMItem == nil)
            .accessibilityLabel("BGM progress")
            .accessibilityValue("\(formatTime(viewModel.bgmCurrentTime)) of \(viewModel.bgmDuration.map { formatTime($0) } ?? "unknown duration")")

            // 时间标签行
            HStack {
                Text(formatTime(viewModel.bgmCurrentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                if let dur = viewModel.bgmDuration {
                    Text(formatTime(dur))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(StudioTheme.textSecondary)
                } else {
                    Text("--:--")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(StudioTheme.surfaceSecondary)
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    // MARK: - 分类选择器

    private var categoryPicker: some View {
        HStack {
            Text(mode == .liveDock ? "分类" : "当前分类")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            Picker("", selection: bgmCategoryBinding) {
                ForEach(BGMCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(.system(size: 15))
            .accessibilityLabel("BGM category")
            .accessibilityValue(bgmCategory.rawValue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                .fill(StudioTheme.surfaceSecondary)
        )
    }

    // MARK: - 曲目列表

    private var bgmList: some View {
        let filteredBGM = viewModel.bgmItems.filter { $0.category == bgmCategory }

        return Group {
            if filteredBGM.isEmpty {
                EmptyStateView(
                    title: "暂无曲目",
                    message: "添加音乐后，现场 BGM 列表会显示在这里。",
                    systemImage: "music.note.list"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, mode == .liveDock ? 14 : 20)
                .background(StudioTheme.surfaceSecondary)
                .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
            } else {
                List {
                    ForEach(filteredBGM) { bgm in
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16))
                                .foregroundStyle(StudioTheme.textTertiary)
                                .frame(width: 20)
                                .help("拖动此图标可排序")
                            BGMItemRow(bgm: bgm, viewModel: viewModel, compact: mode == .liveDock)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        viewModel.moveBGMItems(in: bgmCategory, from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(filteredBGM.count) * 52, mode == .liveDock ? 156 : 280))
                .background(StudioTheme.surfaceSecondary)
                .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
            }
        }
    }

    // MARK: - 添加音乐按钮

    private var addMusicButton: some View {
        Button {
            openMusicPicker()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("添加音乐文件")
                    .font(.system(size: mode == .liveDock ? 14 : 16, weight: .bold))
                Spacer()
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, mode == .liveDock ? 11 : 13)
        }
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.actionPrimary)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Add music files")
    }

    // MARK: - 状态指示行

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.bgmItems.isEmpty ? StudioTheme.statusIdle.opacity(0.4) : StudioTheme.statusReady)
                .frame(width: 8, height: 8)
            Text(viewModel.bgmItems.isEmpty ? "引擎已停止" : "BGM 已就绪")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private var controlDiskFill: some View {
        Circle()
            .fill(StudioTheme.surfacePrimary)
            .shadow(color: StudioTheme.shadowSoft, radius: 3, x: 0, y: 1)
    }

    private var bgmCategoryBinding: Binding<BGMCategory> {
        Binding(
            get: { bgmCategory },
            set: { newCategory in
                var selection = BGMCategorySelectionState(
                    selectedCategory: bgmCategory,
                    didManuallySelectCategory: didManuallySelectBGMCategory
                )
                selection.selectCategory(newCategory)
                bgmCategory = selection.selectedCategory
                didManuallySelectBGMCategory = selection.didManuallySelectCategory
            }
        )
    }

    private func syncLiveDockCategoryWithCurrentTrack() {
        var selection = BGMCategorySelectionState(
            selectedCategory: bgmCategory,
            didManuallySelectCategory: didManuallySelectBGMCategory
        )
        selection.syncWithCurrentItem(viewModel.currentBGMItem, allowsAutoSync: mode == .liveDock)
        bgmCategory = selection.selectedCategory
        didManuallySelectBGMCategory = selection.didManuallySelectCategory
    }

    // MARK: - 文件选择

    private func openMusicPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择音乐文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.audio, .mp3, .wav]
            guard panel.runModal() == .OK else { return }
            for url in panel.urls {
                let decision = BGMDuplicatePolicy.decision(for: url, existingItems: viewModel.bgmItems)
                guard case let .importable(title) = decision else { continue }
                let bgm = BGMItem(
                    title: title,
                    url: url,
                    category: self.bgmCategory
                )
                viewModel.addBGMItem(bgm)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BGMPlaylistPanel()
        .environmentObject(SwitcherViewModel())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
