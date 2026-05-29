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

    // MARK: - 标题行

    private var headerRow: some View {
        let controls = bgmControlsState

        return ZStack {
            VStack(spacing: 2) {
                Text("音乐播放机")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(viewModel.bgmItems.count) 首已入库")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()
                if StatusBadgeVisibilityPolicy.shouldShow(
                    text: controls.displayStatusText,
                    kind: controls.displayStatusKind
                ) {
                    StatusBadge(controls.displayStatusText, kind: controls.displayStatusKind)
                }
            }
        }
    }

    // MARK: - BGM 五颗大媒体控制键（V20 新增"跳回开头"）

    private var bgmControlButtons: some View {
        let diskSize: CGFloat = 32
        let controls = bgmControlsState

        return HStack(spacing: 8) {
            Spacer()

            // 跳回开头（V20 新增）
            Button(action: { viewModel.seekBGMToBeginning() }) {
                Image(systemName: "backward.end.alt.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSeekToBeginning ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSeekToBeginning)
            .opacity(controls.canSeekToBeginning ? 1 : 0.42)
            .help("跳回开头")
            .accessibilityLabel("BGM 跳回开头")
            .accessibilityHint(controls.seekDisabledReason ?? "将当前 BGM 跳回开头。")

            // 上一首
            Button(action: { viewModel.playPreviousBGM() }) {
                Image(systemName: "backward.end.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSkipPrevious ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipPrevious)
            .opacity(controls.canSkipPrevious ? 1 : 0.42)
            .help("上一首")
            .accessibilityLabel("上一首 BGM")
            .accessibilityHint(controls.skipDisabledReason ?? "播放当前分类的上一首 BGM。")

            // 播放 / 暂停
            Button(action: {
                if let item = BGMDefaultSelectionPolicy.defaultItem(
                    items: viewModel.bgmItems,
                    currentItem: viewModel.currentBGMItem,
                    selectedCategory: viewModel.bgmLibraryCategorySelection.selectedCategory
                ) {
                    viewModel.toggleBGM(item)
                }
            }) {
                Image(systemName: viewModel.isBGMPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(StudioTheme.TypeScale.display)
                    .foregroundStyle(controls.canPlay ? (viewModel.isBGMPlaying ? StudioTheme.Tone.live : StudioTheme.Action.primary) : StudioTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!controls.canPlay)
            .opacity(controls.canPlay ? 1 : 0.42)
            .help(viewModel.isBGMPlaying ? "暂停 BGM" : "播放 BGM")
            .accessibilityLabel(viewModel.isBGMPlaying ? "暂停 BGM" : "播放 BGM")
            .accessibilityHint(controls.playDisabledReason ?? "切换 BGM 播放状态。")

            // 下一首
            Button(action: { viewModel.playNextBGM() }) {
                Image(systemName: "forward.end.fill")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(controls.canSkipNext ? StudioTheme.textPrimary : StudioTheme.textTertiary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!controls.canSkipNext)
            .opacity(controls.canSkipNext ? 1 : 0.42)
            .help("下一首")
            .accessibilityLabel("下一首 BGM")
            .accessibilityHint(controls.skipDisabledReason ?? "播放当前分类的下一首 BGM。")

            // 循环模式
            Button(action: { viewModel.toggleLoopMode() }) {
                Image(systemName: viewModel.bgmPlayMode == .loopOne ? "repeat.1" : "repeat")
                    .font(StudioTheme.TypeScale.title)
                    .foregroundStyle(viewModel.bgmPlayMode == .sequential ? StudioTheme.textSecondary : StudioTheme.Action.primary)
                    .frame(width: diskSize, height: diskSize)
                    .background(controlDiskFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(viewModel.bgmPlayMode.rawValue)
            .accessibilityLabel("BGM 循环模式")
            .accessibilityValue(viewModel.bgmPlayMode.rawValue)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.raised)
        )
    }

    // MARK: - V24 BGM 播放进度条（可拖拽）

    private var bgmProgressBar: some View {
        BGMProgressBar(progressStore: viewModel.bgmProgressStore, canSeek: bgmControlsState.canSeekToBeginning) { progress in
            viewModel.seekBGM(toProgress: progress)
        }
    }

    // MARK: - 分类选择器

    private var categoryPicker: some View {
        HStack {
            Text("当前分类")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            Picker("", selection: selectedCategoryBinding) {
                ForEach(BGMCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .font(StudioTheme.TypeScale.heading)
            .accessibilityLabel("BGM 分类")
            .accessibilityValue(viewModel.bgmLibraryCategorySelection.selectedCategory.rawValue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                .fill(StudioTheme.Surface.raised)
        )
    }

    // MARK: - 曲目列表

    private var bgmList: some View {
        let filteredBGM = viewModel.bgmItems.filter { $0.category == viewModel.bgmLibraryCategorySelection.selectedCategory }

        return Group {
            if filteredBGM.isEmpty {
                EmptyStateView(
                    title: "暂无曲目",
                    message: "添加音乐后，现场 BGM 列表会显示在这里。",
                    systemImage: "music.note.list"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(StudioTheme.Surface.raised)
                .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
            } else {
                List {
                    ForEach(filteredBGM) { bgm in
                        BGMItemRow(bgm: bgm, viewModel: viewModel)
                            .accessibilityHint("拖拽调整顺序。")
                        .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        viewModel.moveBGMItems(in: viewModel.bgmLibraryCategorySelection.selectedCategory, from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(filteredBGM.count) * 52, 280))
                .background(StudioTheme.Surface.raised)
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
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                    .accessibilityHidden(true)
                Text("添加音乐文件")
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                Spacer()
                Image(systemName: "arrow.up.doc.fill")
                    .font(StudioTheme.TypeScale.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Action.primary)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("添加音乐文件")
    }

    // MARK: - 状态指示行

    private var statusRow: some View {
        let controls = bgmControlsState

        return HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.color(for: controls.displayStatusKind))
                .frame(width: 8, height: 8)
            Text(statusRowText(for: controls))
                .font(StudioTheme.TypeScale.body.weight(.semibold))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func statusRowText(for controls: BGMControlsState) -> String {
        switch controls.displayStatusText {
        case "播放中":
            return "BGM 播放中"
        case "已选":
            return "BGM 已选中"
        case "待选":
            return "请选择 BGM"
        case "空":
            return "请添加 BGM"
        default:
            return controls.displayStatusText
        }
    }

    private var controlDiskFill: some View {
        Circle()
            .fill(StudioTheme.Surface.base)
            .shadow(color: StudioTheme.shadowSoft, radius: 3, x: 0, y: 1)
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
            isPlaying: viewModel.isBGMPlaying
        )
    }
}

private struct BGMProgressBar: View {
    @ObservedObject var progressStore: BGMProgressStore
    let canSeek: Bool
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { progressStore.progress },
                    set: { onSeek($0) }
                ),
                in: 0...1
            )
            .tint(StudioTheme.Action.primary)
            .frame(height: 20)
            .disabled(!canSeek)
            .accessibilityLabel("BGM 进度")
            .accessibilityValue("\(formatTime(progressStore.currentTime)) / \(progressStore.duration.map { formatTime($0) } ?? "未知时长")")

            HStack {
                Text(formatTime(progressStore.currentTime))
                    .font(StudioTheme.TypeScale.monoCaption)
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                if let duration = progressStore.duration {
                    Text(formatTime(duration))
                        .font(StudioTheme.TypeScale.monoCaption)
                        .foregroundStyle(StudioTheme.textSecondary)
                } else {
                    Text("--:--")
                        .font(StudioTheme.TypeScale.monoCaption)
                        .foregroundStyle(StudioTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(StudioTheme.Surface.raised)
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let seconds = Int(seconds)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

// MARK: - BGM 曲目行

@MainActor
struct BGMItemRow: View {
    let bgm: BGMItem
    var viewModel: SwitcherViewModel
    var compact: Bool = false
    @State private var isHovered = false

    var isCurrentTrack: Bool {
        viewModel.currentBGMItem?.id == bgm.id
    }

    var isPlaying: Bool {
        isCurrentTrack && viewModel.isBGMPlaying
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ProgramThumbnailView(
                    sourceURL: bgm.url,
                    kind: .media,
                    isVideo: false,
                    displaySize: CGSize(width: compact ? 42 : 54, height: compact ? 24 : 30)
                )

                if isCurrentTrack {
                    Image(systemName: isPlaying ? "waveform" : "checkmark")
                        .font(StudioTheme.TypeScale.monoCaption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(StudioTheme.Action.primary))
                        .accessibilityHidden(true)
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bgm.title)
                    .font(compact ? StudioTheme.TypeScale.heading.weight(.semibold) : StudioTheme.TypeScale.title)
                    .fontWeight(isCurrentTrack ? .semibold : .regular)
                    .foregroundStyle(isCurrentTrack ? StudioTheme.Action.primary : StudioTheme.textPrimary)
                    .lineLimit(1)
                Text(bgm.category.rawValue)
                    .font(compact ? StudioTheme.TypeScale.caption : StudioTheme.TypeScale.body)
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .layoutPriority(1)

            Spacer()

            HStack(spacing: compact ? 8 : 10) {
                Button(action: { viewModel.toggleBGM(bgm) }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(compact ? StudioTheme.TypeScale.body : StudioTheme.TypeScale.heading)
                        .foregroundStyle(isCurrentTrack ? StudioTheme.Action.primary : StudioTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "暂停" : "播放")
                .accessibilityLabel(isPlaying ? "暂停 \(bgm.title)" : "播放 \(bgm.title)")

                Button(action: { viewModel.removeBGMItem(bgm) }) {
                    Image(systemName: "trash")
                        .font(compact ? StudioTheme.TypeScale.caption : StudioTheme.TypeScale.body)
                        .foregroundStyle(isHovered ? StudioTheme.Action.danger : StudioTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("删除")
                .accessibilityLabel("删除 \(bgm.title)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 6 : 8)
        .background(isCurrentTrack ? StudioTheme.Action.primary.opacity(0.08) : (isHovered ? StudioTheme.Surface.raised : Color.clear))
        .clipShape(.rect(cornerRadius: StudioTheme.radiusS, style: .continuous))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bgm.title), \(bgm.category.rawValue)")
        .accessibilityValue(isPlaying ? "播放中" : (isCurrentTrack ? "当前曲目" : "待播"))
    }
}

// MARK: - Preview

#Preview {
    BGMPlaylistPanel()
        .environment(SwitcherViewModel())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
