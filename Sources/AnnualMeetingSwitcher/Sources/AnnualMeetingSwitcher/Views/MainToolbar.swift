import SwiftUI

// MARK: - 主工具栏

struct MainToolbar: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var showHelp = false
    var embedded: Bool = false

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
            HelpView()
        }
    }

    private var embeddedToolbarActionCluster: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                liveControlButton(
                    title: viewModel.isSpeakerMode ? "主讲中" : "主讲人",
                    subtitle: viewModel.isSpeakerMode ? "BGM 7%" : "压低 BGM",
                    systemName: viewModel.isSpeakerMode ? "mic.fill" : "mic",
                    tint: speakerTint,
                    isCritical: false,
                    help: viewModel.isSpeakerMode
                        ? "主讲人模式已开启：BGM 已压低至 7%，再次点击恢复"
                        : "主讲人模式：一键压低 BGM，突出现场人声"
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
                    subtitle: viewModel.isSpeakerMode ? "BGM 7%" : "压低 BGM",
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack(spacing: 8) {
                    Text("❓")
                        .font(.system(size: 22))
                    Text("LiveSwitcher · Help")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                }

                Divider()

                HelpSectionView(title: "🔥 常用必备功能（绿灯亮起 = 功能已开启）", items: [
                    "主讲人模式：顶部【主讲人】按钮，开启后按钮变绿，BGM 压至 7% 突出人声",
                    "PPT翻页笔：顶部【PPT模式】开启后按钮变绿，翻页笔方向键控制 WPS/PPT 翻页（需辅助功能权限，开启失败时 App 会自动引导设置）",
                    "投射副屏：左侧底部【投射：关/开】，开启后按钮变绿，画面推至现场大屏 (1080P)",
                    "老板键：顶部【老板键】紧急切黑副屏并静音，开启后按钮变红，再点恢复"
                ])

                HelpSectionView(title: "🎬 视频与音频操作", items: [
                    "添加视频：左侧【选择视频】按钮，支持 MP4/MOV/AVI 等格式，支持拖拽入列",
                    "添加HTML大屏：左侧【选择 HTML】绿色按钮，选择 HTML 文件，点击即推流至副屏全屏展示",
                    "切换画面：点击播放列表中的项目立即切换大屏（切换时自动淡出音频防止音画撕裂）",
                    "背景音乐：预览页中栏【BGM快控】可直接播控当前曲目、拖动进度，并一键跳到完整音乐库",
                    "音频混音：顶部切换至【音频混音】页面，可管理 BGM 列表、音频策略，以及主音量 / 媒体 / BGM 三路推子"
                ])

                HelpSectionView(title: "🎭 壁纸与叠层", items: [
                    "背景壁纸：中栏底部【壁纸库】，导入图片后点击即激活为大屏背景",
                    "倒计时叠层：叠层控制面板开启【倒计时】，直接输入分钟/秒数（默认10分钟），叠加显示在大屏",
                    "游动字幕：叠层控制面板开启【游动字幕】，输入内容后在大屏顶部横向滚动（字体已放大）",
                    "下三分之一：叠层控制面板开启【人名条】，展示嘉宾姓名/职位，点击上屏/退场控制显示"
                ])

                HelpSectionView(title: "⌨️ 键盘快捷键", items: [
                    "⌘⌥M：切换主讲人模式，压低媒体声道和 BGM，突出现场人声",
                    "⌘⌥B：老板键，一键切黑副屏并静音",
                    "⌘⌥P：切换 PPT 模式，接管翻页笔/方向键",
                    "数字键 1-9：快速切换对应播放列表编号的信号源",
                    "空格键：暂停/继续当前媒体播放",
                    "[ / ] 键：BGM 音量减小 / 增大",
                    ", 键：快速切换 BGM 播放/暂停",
                    "← → 方向键：Keynote 上一页 / 下一页（PPT模式关闭时有效）"
                ])

                Text("Version 0.2.0 | live safety · BGM takeover · desktop commands")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(24)
        }
        .frame(width: 420, height: 500)
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
