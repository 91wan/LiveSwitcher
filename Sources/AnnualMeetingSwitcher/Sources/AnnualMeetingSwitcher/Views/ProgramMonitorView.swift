import SwiftUI

// MARK: - Program Monitor

struct ProgramMonitorView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isHoveringPreviewDeck = false
    var isLiveMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isLiveMode ? 0 : 12) {
            if !isLiveMode {
                HStack(alignment: .firstTextBaseline) {
                    Text("主输出")
                        .font(StudioTheme.title())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("监看")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textTertiary)
                    Spacer()
                }
            }

            previewDeck

            if !isLiveMode {
                monitorUtilitiesStack
            }

            Spacer(minLength: 0)
        }
        .padding(isLiveMode ? 12 : 18)
        .studioCard(cornerRadius: 24)
    }

    private var previewDeck: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .fill(StudioTheme.monitorGradient)

            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .stroke(StudioTheme.monitorBorder, lineWidth: 1)

            mediaLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(.rect(cornerRadius: StudioTheme.monitorRadius, style: .continuous))
                .animation(.easeInOut(duration: viewModel.crossfadeDuration),
                           value: viewModel.currentProgramItem)

            monitorCornerLogoOverlay

            if viewModel.isBroadcasting {
                RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                    .stroke(StudioTheme.borderCritical.opacity(0.95), lineWidth: 3)
                    .padding(1)
            }
        }
        .overlay(alignment: .top) {
            monitorTopChrome
                .opacity(monitorChromeVisibility.inlineChromeOpacity)
                .allowsHitTesting(monitorChromeVisibility.inlineChromeAllowsHitTesting)
        }
        .overlay(alignment: .bottomTrailing) {
            if monitorChromeVisibility.showsCompactLiveIndicator {
                compactLiveIndicator
                    .opacity(monitorChromeVisibility.compactLiveIndicatorOpacity)
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: livePreviewMaxHeight)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .shadow(color: StudioTheme.shadowStrong, radius: 12, x: 0, y: 8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHoveringPreviewDeck = hovering
            }
        }
        .animation(.easeInOut(duration: 0.16), value: monitorChromeVisibility)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isBroadcasting ? "主输出正在直播" : "主输出待机")
    }

    private var livePreviewMaxHeight: CGFloat {
        isLiveMode ? .infinity : 342
    }

    private var compactLiveIndicator: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(StudioTheme.Tone.live)
                .frame(width: 8, height: 8)
            Text("直播")
                .font(StudioTheme.TypeScale.caption.weight(.black))
                .foregroundStyle(StudioTheme.monitorText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderCritical.opacity(0.75), lineWidth: 1))
        .accessibilityLabel("主输出正在直播")
    }

    @ViewBuilder
    private var monitorCornerLogoOverlay: some View {
        AsyncLocalImage(url: viewModel.cornerLogoURL) {
            EmptyView()
        } content: { image in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: isLiveMode ? 52 : 42)
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: viewModel.cornerLogoPosition.monitorAlignment
                )
                .accessibilityLabel("角标 Logo 监看")
        }
    }

    private var monitorTopChrome: some View {
        GeometryReader { proxy in
            let layout = ProgramMonitorChromeLayoutModel.make(width: Double(proxy.size.width))

            HStack(spacing: 10) {
                monitorStatePill

                if layout.showsFullInlineStatus {
                    monitorInlineStatusRow
                } else if layout.showsCompactInlineStatus {
                    monitorCompactStatusPill
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 12)
            .padding(.horizontal, 12)
        }
    }

    private var monitorStatePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Tone.idle)
                .frame(width: 8, height: 8)
            Text(monitorStateLabel)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(StudioTheme.monitorText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioTheme.monitorOverlayFill, in: Capsule())
    }

    private var monitorInlineStatusRow: some View {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: viewModel.avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return HStack(spacing: 10) {
            monitorInlineStatusItem(current)
            Divider()
                .frame(height: 30)
            monitorInlineStatusItem(next)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(StudioTheme.monitorOverlayFill, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(viewModel.isBroadcasting ? StudioTheme.borderCritical : StudioTheme.monitorBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitorInlineAccessibilityLabel)
    }

    private func monitorInlineStatusItem(_ model: ProgramMonitorInfoBlockModel) -> some View {
        HStack(spacing: 8) {
            Text(model.title.uppercased())
                .font(StudioTheme.statusLabel())
                .foregroundStyle(StudioTheme.monitorText.opacity(0.58))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(model.value)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .foregroundStyle(StudioTheme.monitorText)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(model.badgeText)
                .font(StudioTheme.TypeScale.label)
                .foregroundStyle(StudioTheme.color(for: model.status))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monitorCompactStatusPill: some View {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: viewModel.avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return HStack(spacing: 7) {
            Text(current.value)
                .foregroundStyle(StudioTheme.monitorText)
            Text("->")
                .foregroundStyle(StudioTheme.monitorText.opacity(0.55))
            Text(next.value)
                .foregroundStyle(StudioTheme.monitorText.opacity(0.82))
        }
        .font(StudioTheme.TypeScale.caption.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monitorInlineAccessibilityLabel)
    }

    private var monitorInlineAccessibilityLabel: String {
        let current = ProgramMonitorInfoBlockModel.current(
            item: viewModel.currentProgramItem,
            isBroadcasting: viewModel.isBroadcasting,
            isPlaying: viewModel.avCoordinator.isPlaying,
            isHTMLLoaded: viewModel.currentHTMLURL != nil
        )
        let next = ProgramMonitorInfoBlockModel.next(item: nextProgramItem)

        return "主输出状态。当前 \(current.accessibilityLabel)。下一项 \(next.accessibilityLabel)。"
    }

    private var monitorChromeVisibility: MonitorChromeVisibility {
        MonitorChromeVisibility.make(
            isPlaying: isMediaPlaybackActive,
            isHovering: isHoveringPreviewDeck,
            isBroadcasting: viewModel.isBroadcasting
        )
    }

    private var isMediaPlaybackActive: Bool {
        viewModel.currentProgramItem?.supportsSeeking == true && viewModel.avCoordinator.isPlaying
    }

    private var monitorUtilitiesStack: some View {
        VStack(spacing: 10) {
            transitionControlCard
            if !isLiveMode {
                wallpaperTrayCard
                CornerLogoCard()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.overlay))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var transitionControlCard: some View {
        let model = ProgramTransitionControlModel(crossfadeDuration: viewModel.crossfadeDuration)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("转场")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("节目")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }

            Slider(
                value: $viewModel.crossfadeDuration,
                in: 0.5...3.0,
                step: 0.05
            )
            .tint(model.controlTone.sliderTint)
            .accessibilityLabel("转场时长")
            .accessibilityValue(String(format: "%.1f 秒", viewModel.crossfadeDuration))

            Text(model.statusText)
                .font(StudioTheme.TypeScale.numeric.weight(.bold))
                .foregroundStyle(model.controlTone.valueTint)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var wallpaperTrayCard: some View {
        let wallpaperCount = viewModel.backgroundWallpapers.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待机壁纸")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                }
                Spacer()
                if CountPillVisibilityPolicy.shouldShow(count: wallpaperCount) {
                    CountPill("\(wallpaperCount) 张", kind: .ready)
                }
            }

            if viewModel.backgroundWallpapers.isEmpty {
                InlineWarningBanner(title: "没有待机壁纸", message: "导入一张中性图片作为备用画面。", kind: .warn)
                Button {
                    WallpaperImportService.presentPicker(viewModel: viewModel)
                } label: {
                    Label("导入壁纸...", systemImage: "photo.badge.plus")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                WallpaperGalleryRow()
                    .frame(maxHeight: 92)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if VideoLayerVisibilityModel.shouldShowVideoLayer(
            sourceKind: viewModel.currentProgramItem?.sourceKind,
            hasLoadedMedia: viewModel.avCoordinator.hasLoadedMedia
        ) {
            VideoPlayerView(coordinator: viewModel.avCoordinator)
                .transition(.opacity)
                .overlay(alignment: .bottomTrailing) {
                    if !viewModel.avCoordinator.isPlaying {
                        Text("暂停")
                            .font(StudioTheme.TypeScale.caption.weight(.black))
                            .foregroundStyle(StudioTheme.monitorText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(StudioTheme.monitorOverlayFill, in: Capsule(style: .continuous))
                            .padding(12)
                    }
                }
        } else if let item = viewModel.currentProgramItem {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(StudioTheme.TypeScale.display.weight(.bold))
                    .foregroundStyle(StudioTheme.monitorText)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(StudioTheme.TypeScale.heading.weight(.regular))
                        .foregroundStyle(StudioTheme.monitorText.opacity(0.6))
                }
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Text("待机中")
                    .font(StudioTheme.TypeScale.display.weight(.bold))
                    .foregroundStyle(StudioTheme.monitorText)
                Text("未载入信号")
                    .font(StudioTheme.TypeScale.body.weight(.black))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.7))
            }
            .transition(.opacity)
        }
    }

    private var monitorState: ProgramMonitorStateModel {
        ProgramMonitorStateModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            currentItem: viewModel.currentProgramItem
        )
    }

    private var monitorStateLabel: String {
        monitorState.label
    }

    private var monitorStateKind: StudioTheme.StatusKind {
        monitorState.kind
    }

    private var nextProgramItem: ProgramItem? {
        ProgramQueueStore.nextPlayableAfterCurrent(
            current: viewModel.currentProgramItem,
            in: viewModel.programItems
        )
    }
}

#Preview {
    ProgramMonitorView()
        .environmentObject(SwitcherViewModel())
        .frame(width: 700, height: 620)
}
