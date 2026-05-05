import AppKit
import SwiftUI

// MARK: - 主工具栏

struct MainToolbar: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var showHelp = false
    var embedded: Bool = false
    var onOpenPreview: () -> Void = {}
    var onOpenAudioMixer: () -> Void = {}
    var onOpenOverlays: () -> Void = {}

    var body: some View {
        Group {
            if embedded {
                embeddedToolbarActionCluster
            } else {
                HStack(spacing: 14) {
                    Spacer()
                    embeddedToolbarActionCluster
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.clear)
                .overlay(
                    Divider()
                        .background(Color(NSColor.separatorColor)),
                    alignment: .bottom
                )
            }
        }
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            HelpView(onPreflightAction: handlePreflightAction)
        }
    }

    private func handlePreflightAction(_ action: LivePreflightActionKind) {
        switch action {
        case .clearOverlays, .turnOffPanic:
            viewModel.performLivePreflightAction(action)
        case .openPreview:
            onOpenPreview()
            showHelp = false
        case .openAudioMixer:
            onOpenAudioMixer()
            showHelp = false
        case .openOverlays:
            onOpenOverlays()
            showHelp = false
        case .needsHardware, .manualReview:
            break
        }
    }

    private var embeddedToolbarActionCluster: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                liveControlButton(
                    title: viewModel.isSpeakerMode ? "主讲中" : "主讲人",
                    subtitle: viewModel.isSpeakerMode ? "声道 7%" : "压低声道",
                    systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic",
                    tint: speakerTint,
                    isCritical: false,
                    help: viewModel.isSpeakerMode
                        ? "主讲人模式已开启：媒体声道和 BGM 已压低至 7%，再次点击恢复"
                        : "主讲人模式：一键压低媒体声道和 BGM，突出现场人声"
                ) {
                    viewModel.toggleSpeakerMode()
                }

                liveControlButton(
                    title: viewModel.isPanicMode ? "老板键: 开" : "老板键",
                    subtitle: viewModel.isPanicMode ? "切黑静音" : "紧急切黑",
                    systemName: viewModel.isPanicMode ? "eye.slash.fill" : "bolt.fill",
                    tint: panicTint,
                    isCritical: viewModel.isPanicMode,
                    help: viewModel.isPanicMode
                        ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
                        : "老板键（紧急）：一键切黑副屏并静音所有音频"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.togglePanicMode()
                    }
                }

                liveControlButton(
                    title: viewModel.isPageInterceptEnabled ? "PPT: 开" : "PPT: 关",
                    subtitle: viewModel.isPageInterceptEnabled ? "翻页接管" : "点击开启",
                    systemName: viewModel.isPageInterceptEnabled ? "hand.raised.fill" : "hand.raised.slash",
                    tint: pptTint,
                    isCritical: false,
                    help: viewModel.isPageInterceptEnabled
                        ? "PPT 模式已开启：翻页笔按键将转发给演示软件"
                        : "PPT 模式：开启翻页笔接管，可能需要辅助功能权限"
                ) {
                    viewModel.isPageInterceptEnabled.toggle()
                }

                helpButton
            }

            HStack(spacing: 8) {
                compactToolbarButton(
                    title: viewModel.isSpeakerMode ? "主讲中" : "主讲人",
                    subtitle: viewModel.isSpeakerMode ? "声道 7%" : "压低声道",
                    systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic",
                    fill: speakerTint
                ) {
                    viewModel.toggleSpeakerMode()
                }

                compactToolbarButton(
                    title: viewModel.isPanicMode ? "老板键: 开" : "老板键",
                    subtitle: viewModel.isPanicMode ? "切黑静音" : "紧急切黑",
                    systemName: viewModel.isPanicMode ? "eye.slash.fill" : "bolt.fill",
                    fill: panicTint
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.togglePanicMode()
                    }
                }

                compactToolbarButton(
                    title: viewModel.isPageInterceptEnabled ? "PPT: 开" : "PPT: 关",
                    subtitle: viewModel.isPageInterceptEnabled ? "翻页接管" : "点击开启",
                    systemName: viewModel.isPageInterceptEnabled ? "hand.raised.fill" : "hand.raised.slash",
                    fill: pptTint
                ) {
                    viewModel.isPageInterceptEnabled.toggle()
                }

                helpButton
            }
        }
    }

    private var speakerTint: Color {
        viewModel.isSpeakerMode
            ? Color(red: 0.05, green: 0.65, blue: 0.35)
            : Color(red: 0.18, green: 0.42, blue: 0.88)
    }

    private var panicTint: Color {
        viewModel.isPanicMode
            ? Color(red: 0.88, green: 0.16, blue: 0.12)
            : Color(red: 0.18, green: 0.42, blue: 0.88)
    }

    private var pptTint: Color {
        viewModel.isPageInterceptEnabled
            ? Color(red: 0.05, green: 0.65, blue: 0.35)
            : Color(red: 0.18, green: 0.42, blue: 0.88)
    }

    // MARK: - V25: 翻页拦截开关

    private var pageInterceptToggle: some View {
        Button(action: {
            viewModel.isPageInterceptEnabled.toggle()
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isPageInterceptEnabled
                      ? "hand.raised.fill"
                      : "hand.raised.slash")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isPageInterceptEnabled ? "PPT模式: 开" : "PPT模式: 关")
                        .font(.system(size: 15, weight: .bold))
                    Text(viewModel.isPageInterceptEnabled ? "翻页笔已接管 · 点击关闭" : "点击开启翻页笔接管")
                        .font(.system(size: 11))
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(viewModel.isPageInterceptEnabled
                          ? Color(red: 0.05, green: 0.65, blue: 0.35)
                          : Color(red: 0.18, green: 0.42, blue: 0.88))
            )
            .shadow(color: viewModel.isPageInterceptEnabled
                    ? Color.green.opacity(0.4)
                    : Color.blue.opacity(0.3),
                    radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(viewModel.isPageInterceptEnabled
              ? "翻页笔拦截已开启：PageUp/Down/左右箭头 将被拦截并转发给后台 WPS（点击关闭）"
              : "翻页笔拦截已关闭：点击开启，接管翻页键并定向发送给 WPS")
    }

    // MARK: - ❓ 使用说明按钮

    private var helpButton: some View {
        Button(action: { showHelp.toggle() }) {
            Image(systemName: "questionmark")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.red)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.88), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("使用说明")
    }

    // MARK: - Tier1: 老板键按钮

    private var panicButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.togglePanicMode()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isPanicMode
                      ? "eye.slash.fill"
                      : "bolt.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.isPanicMode ? "🚨 老板键: 开" : "🚨 老板键")
                        .font(.system(size: 15, weight: .bold))
                    Text(viewModel.isPanicMode ? "副屏已切黑静音 · 点击恢复" : "一键切黑副屏并静音")
                        .font(.system(size: 11))
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(viewModel.isPanicMode
                          ? Color(red: 0.05, green: 0.65, blue: 0.35)
                          : Color(red: 0.18, green: 0.42, blue: 0.88))
            )
            .shadow(color: viewModel.isPanicMode
                    ? Color.green.opacity(0.4)
                    : Color.blue.opacity(0.3),
                    radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(viewModel.isPanicMode
              ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
              : "老板键（紧急）：一键切黑副屏并静音所有音频")
    }

    private func compactToolbarButton(
        title: String,
        subtitle: String,
        systemName: String,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: fill.opacity(0.28), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func embeddedActionButton(
        title: String,
        systemName: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: tint.opacity(0.24), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func liveControlButton(
        title: String,
        subtitle: String,
        systemName: String,
        tint: Color,
        isCritical: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0.88)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 112, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isCritical
                                ? [tint, Color(red: 0.98, green: 0.36, blue: 0.2)]
                                : [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isCritical ? 0.46 : 0.18), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isCritical ? 0.36 : 0.24), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(help)
    }
}

// MARK: - 使用说明弹窗

struct HelpView: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    @State private var selectedPanel: HelpPanel = .help
    @State private var copiedReport = false
    @State private var preflightListMode: PreflightListMode = .needsAttention
    @State private var preflightActionMessage: String?
    var onPreflightAction: (LivePreflightActionKind) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("LiveSwitcher")
                    .font(.system(size: 16, weight: .black))

                Spacer()

                Picker("", selection: $selectedPanel) {
                    Text("Help").tag(HelpPanel.help)
                    Text("Preflight").tag(HelpPanel.preflight)
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                Group {
                    switch selectedPanel {
                    case .help:
                        helpContent
                    case .preflight:
                        preflightContent
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpSectionView(title: "常用必备功能（绿灯亮起 = 功能已开启）", items: [
                "主讲人模式：顶部【主讲人】按钮，开启后按钮变绿，媒体声道和 BGM 压至 7% 突出人声",
                "PPT翻页笔：顶部【PPT模式】开启后按钮变绿，翻页笔方向键控制 WPS/PPT 翻页（需辅助功能权限，开启失败时 App 会自动引导设置）",
                "投射副屏：左侧底部【投射：关/开】，无外接屏时不会投射；副屏断开会立即停止投射",
                "老板键：顶部【老板键】紧急切黑副屏并静音，开启后按钮变红，再点恢复"
            ])

            HelpSectionView(title: "视频与音频操作", items: [
                "添加视频：左侧【选择视频】按钮，支持 MP4/MOV/AVI 等格式，支持拖拽入列",
                "添加HTML大屏：左侧【选择 HTML】绿色按钮，选择 HTML 文件，点击即推流至副屏全屏展示",
                "切换画面：点击播放列表中的项目立即切换大屏（切换时自动淡出音频防止音画撕裂）",
                "背景音乐：预览页右侧【现场 BGM】可直接播控当前曲目、查看列表、拖动进度，并一键跳到完整音乐库",
                "音频混音：顶部切换至【音频混音】页面，可管理 BGM 列表、音频策略，以及主音量 / 媒体 / BGM 三路推子"
            ])

            HelpSectionView(title: "壁纸与叠层", items: [
                "背景壁纸：中栏底部【壁纸库】，导入图片后点击即激活为大屏背景",
                "倒计时叠层：叠层控制面板开启【倒计时】，直接输入分钟/秒数（默认10分钟），叠加显示在大屏",
                "游动字幕：叠层控制面板开启【游动字幕】，输入内容后在大屏顶部横向滚动（字体已放大）",
                "下三分之一：叠层控制面板开启【人名条】，展示嘉宾姓名/职位，点击上屏/退场控制显示"
            ])

            HelpSectionView(title: "键盘快捷键", items: [
                "⌘⌥M：切换主讲人模式，压低媒体声道和 BGM，突出现场人声",
                "⌘⌥B：老板键，一键切黑副屏并静音",
                "⌘⌥P：切换 PPT 模式，接管翻页笔/方向键",
                "数字键 1-9：快速切换对应播放列表编号的信号源",
                "空格键：暂停/继续当前媒体播放",
                "[ / ] 键：BGM 音量减小 / 增大",
                ", 键：快速切换 BGM 播放/暂停",
                "← → 方向键：Keynote 上一页 / 下一页（PPT模式关闭时有效）"
            ])

            Text("Version 0.2.5 | preflight focus · operator attention")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var preflightContent: some View {
        let checks = preflightDisplayedChecks

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live Preflight / 现场检查")
                        .font(.system(size: 18, weight: .black))
                    Text("Reads the current runtime state. Use the summary first, then review fail/warn rows before a show.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: copyPreflightReport) {
                    Label(copiedReport ? "Copied" : "Copy Report", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            PreflightSummaryCard(summary: viewModel.livePreflightSummary)

            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $preflightListMode) {
                    Text("Needs attention").tag(PreflightListMode.needsAttention)
                    Text("All checks").tag(PreflightListMode.allChecks)
                }
                .pickerStyle(.segmented)

                if preflightListMode == .needsAttention {
                    Text("Shows only fail and warn rows, so the operator sees what must be handled first.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let preflightActionMessage {
                Text(preflightActionMessage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if checks.isEmpty {
                PreflightEmptyAttentionView()
            }

            ForEach(LivePreflightGroup.allCases, id: \.self) { group in
                let groupChecks = checks.filter { $0.group == group }
                if !groupChecks.isEmpty {
                    PreflightGroupView(
                        group: group,
                        checks: groupChecks,
                        onAction: handlePreflightRowAction
                    )
                }
            }
        }
    }

    private var preflightDisplayedChecks: [LivePreflightCheck] {
        switch preflightListMode {
        case .needsAttention:
            return LivePreflightCheck.attentionChecks(from: viewModel.livePreflightChecks)
        case .allChecks:
            return viewModel.livePreflightChecks
        }
    }

    private func handlePreflightRowAction(_ action: LivePreflightActionKind) {
        onPreflightAction(action)
        switch action {
        case .clearOverlays:
            showPreflightActionMessage("Overlays cleared")
        case .turnOffPanic:
            showPreflightActionMessage("Panic turned off")
        case .openPreview, .openAudioMixer, .openOverlays, .needsHardware, .manualReview:
            break
        }
    }

    private func showPreflightActionMessage(_ message: String) {
        preflightActionMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if preflightActionMessage == message {
                preflightActionMessage = nil
            }
        }
    }

    private func copyPreflightReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.livePreflightReportText(), forType: .string)
        copiedReport = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copiedReport = false
        }
    }
}

private enum HelpPanel {
    case help
    case preflight
}

private enum PreflightListMode: Hashable {
    case needsAttention
    case allChecks
}

private struct PreflightEmptyAttentionView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("No rows need attention")
                    .font(.system(size: 13, weight: .bold))
                Text("Switch to All checks if you want to audit every passing row.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct PreflightSummaryCard: View {
    let summary: LivePreflightSummary

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(summary.title)
                        .font(.system(size: 15, weight: .black))

                    Text(summary.status.displayTitle)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(summary.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                countPill("P", summary.passCount, .green)
                countPill("W", summary.warnCount, .orange)
                countPill("F", summary.failCount, .red)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(statusColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(statusColor.opacity(0.22), lineWidth: 1)
        )
    }

    private func countPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        Text("\(label) \(count)")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        switch summary.status {
        case .pass:
            return .green
        case .warn:
            return .orange
        case .fail:
            return .red
        }
    }

    private var iconName: String {
        switch summary.status {
        case .pass:
            return "checkmark.seal.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }
}

private struct PreflightGroupView: View {
    let group: LivePreflightGroup
    let checks: [LivePreflightCheck]
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayTitle)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(checks) { check in
                    PreflightRowView(check: check, onAction: onAction)
                }
            }
        }
    }
}

private struct PreflightRowView: View {
    let check: LivePreflightCheck
    let onAction: (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(statusColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(.system(size: 13, weight: .bold))
                    Text(check.status.displayTitle)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(check.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = check.actionLabel, let actionKind = check.actionKind {
                    Button(actionLabel) {
                        onAction(actionKind)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!actionKind.isEnabledInPreflightUI)
                    .help(preflightActionHelp(for: actionKind))
                    .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch check.status {
        case .pass:
            return .green
        case .warn:
            return .orange
        case .fail:
            return .red
        }
    }

    private var iconName: String {
        switch check.status {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }

    private func preflightActionHelp(for action: LivePreflightActionKind) -> String {
        switch action {
        case .clearOverlays:
            return "Clear countdown, ticker, and lower-third overlays."
        case .turnOffPanic:
            return "Turn off active panic blackout."
        case .openPreview:
            return "Open the Preview / Switch page."
        case .openAudioMixer:
            return "Open the Audio Mixer page."
        case .openOverlays:
            return "Open the Overlays / Captions page."
        case .needsHardware:
            return "Requires external display hardware. This action is not automatic."
        case .manualReview:
            return "Manual operator review only. This action does not change app state."
        }
    }
}

// 提取的局部辅助组件
struct HelpSectionView: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    MainToolbar()
        .environmentObject(SwitcherViewModel())
        .frame(width: 900)
}
