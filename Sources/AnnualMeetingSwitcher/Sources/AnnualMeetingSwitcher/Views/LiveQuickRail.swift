import SwiftUI

@MainActor
struct LiveQuickRail: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @State var liveBGMCategory: BGMCategory = .warmUp
    @State var isBGMChooserPresented = false
    @State var bgmChooserSearchText = ""
    @State var bgmChooserCategory: BGMCategory?
    let onOpenMixer: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                outputCard
                cutBusCard
                bgmCard
                wallpaperCard
                overlayCard
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("现场快速控制")
    }

}

extension LiveQuickRail {
    private var outputCard: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return quickCard(title: "输出", status: model.statusText, kind: model.statusKind) {
            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: model.screenSystemImage)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .accessibilityHidden(true)
                    ProjectionOutputOperatorLabel(model: model)
                    Spacer()
                }
                .foregroundStyle(model.isEnabled ? .white : StudioTheme.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 42)
                .background(outputFill(model), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!model.isEnabled)
            .help(model.helpText)
            .accessibilityLabel(model.operatorLine)
            .accessibilityHint(model.subtitle)
        }
    }

    private var cutBusCard: some View {
        let model = LiveCutBusModel.make(
            programItems: viewModel.programItems,
            currentProgramItem: viewModel.currentProgramItem
        )
        let returnToStart = LiveMediaReturnToStartControlModel.make(currentItem: viewModel.currentProgramItem)

        return quickCard(title: "切换", status: viewModel.isFadeToBlackActive ? "已切黑" : "", kind: viewModel.isFadeToBlackActive ? .warn : .idle) {
            HStack(spacing: 7) {
                Button {
                    if let index = model.nextIndex {
                        viewModel.switchToProgram(at: index)
                    }
                } label: {
                    Label("下一项", systemImage: "arrow.right.to.line.compact")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.Action.primary)
                .disabled(!model.canTakeNext)
                .help(model.canTakeNext ? "切换到下一项：\(model.nextTitle)" : "没有下一项")

                ftbButton
            }

            if returnToStart.isEnabled {
                Button {
                    viewModel.returnCurrentMediaToStart()
                } label: {
                    Label(returnToStart.title, systemImage: "backward.end.fill")
                        .font(StudioTheme.TypeScale.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(returnToStart.help ?? "")
                .accessibilityLabel(returnToStart.title)
                .accessibilityHint(returnToStart.help ?? "")
            }
        }
    }

    @ViewBuilder
    private var ftbButton: some View {
        let button = Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.toggleFadeToBlack()
            }
        } label: {
            Label(viewModel.isFadeToBlackActive ? "恢复" : "切黑", systemImage: viewModel.isFadeToBlackActive ? "play.fill" : "moon.fill")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .frame(width: LiveModeLayoutMetrics.ftbButtonWidth, height: 40)
        }
        .help(viewModel.isFadeToBlackActive ? "从黑场恢复" : "淡出至黑场")
        .accessibilityLabel(viewModel.isFadeToBlackActive ? "恢复画面" : "切黑")

        if viewModel.isFadeToBlackActive {
            button
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.Action.danger)
        } else {
            button
                .buttonStyle(.bordered)
                .tint(StudioTheme.Action.danger)
        }
    }


    private var wallpaperCard: some View {
        let picker = LiveWallpaperQuickPickerModel.make(
            wallpapers: viewModel.backgroundWallpapers,
            activeWallpaperURL: viewModel.activeWallpaperURL
        )

        return quickCard(title: "待机", status: picker.statusText, kind: picker.statusKind) {
            Text(picker.displayTitle)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(picker.displayTitle)

            if picker.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.navigateToSetup(.preview)
                    }
                } label: {
                    Label("添加壁纸", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("打开准备模式节目单导入待机壁纸。")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(picker.items) { item in
                            Button {
                                viewModel.setActiveWallpaper(url: item.url)
                            } label: {
                                LiveWallpaperPickerThumb(item: item)
                            }
                            .buttonStyle(.plain)
                            .help(item.title)
                            .accessibilityLabel("选择待机壁纸")
                            .accessibilityValue(item.isActive ? "\(item.title)，当前启用" : item.title)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .accessibilityLabel("选择待机壁纸")
            }
        }
    }


    func quickCard<Content: View>(
        title: String,
        status: String,
        kind: StudioTheme.StatusKind,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                if !status.isEmpty && StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind) {
                    StatusBadge(status, kind: kind)
                }
            }
            content()
        }
        .padding(10)
        .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay), in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(kind == .warn || kind == .fail || kind == .live ? StudioTheme.color(for: kind).opacity(0.28) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    func transportButton(_ systemName: String, label: String, enabled: Bool, disabledHint: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .frame(width: LiveModeLayoutMetrics.transportButtonSize, height: LiveModeLayoutMetrics.transportButtonSize)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
        .help(enabled ? label : disabledHint ?? label)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : disabledHint ?? "")
    }

    func outputFill(_ model: ProjectionButtonModel) -> Color {
        if !model.isEnabled { return StudioTheme.Tone.muted.opacity(0.18) }
        if model.statusKind == .fail { return StudioTheme.Action.danger }
        if model.isBroadcasting { return StudioTheme.Tone.live }
        return model.hasExternalDisplay ? StudioTheme.Action.primary : StudioTheme.Tone.muted
    }

}
