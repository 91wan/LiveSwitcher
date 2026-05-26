import Foundation

struct HelpCopySection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let items: [String]
}

enum HelpCopyModel {
    static let sections: [HelpCopySection] = [
        HelpCopySection(title: "常用必备功能（红色 = 直播 / 危险状态）", items: [
            "主讲人模式：右侧现场控制的模式卡片集中控制；开启后进入警告状态，媒体声道和 BGM 压至 7% 突出人声",
            "PPT翻页笔：右侧现场控制的模式卡片集中控制；开启后翻页笔方向键控制 WPS/PPT 翻页（需辅助功能权限，开启失败时 App 会自动引导设置）",
            "投射副屏：右侧现场控制的输出卡片控制；直播为红色状态，无外接屏时不会投射，副屏断开会显示副屏丢失",
            "紧急切黑：顶部【紧急切黑】会让副屏黑屏并静音，激活时为红色危险状态，再点恢复"
        ]),
        HelpCopySection(title: "视频与音频操作", items: [
            "添加素材：左侧节目单顶部按钮导入视频 / 音频、HTML、PPTX、Keynote，也支持拖拽入列",
            "添加 HTML 大屏：选择 HTML 文件后点击队列项目，即推流至副屏全屏展示",
            "切换画面：点击播放列表中的项目立即切换大屏（切换时自动淡出音频防止音画撕裂）",
            "背景音乐：右侧现场控制的 BGM 卡片只提供当前曲目、基础播控和进度；完整 BGM 库位于音频页面",
            "音频混音：顶部切换至音频页面，可管理 BGM 库、音频策略，以及主音量 / 媒体 / BGM 三路推子"
        ]),
        HelpCopySection(title: "壁纸与叠层", items: [
            "背景壁纸：中栏底部【壁纸库】，导入图片后点击即激活为大屏背景",
            "倒计时叠层：叠层字幕页面准备倒计时，再点上屏",
            "游动字幕：叠层字幕页面输入内容后上屏，在大屏顶部横向滚动",
            "人名条：叠层字幕页面准备嘉宾姓名/职位，再用上屏或关闭控制显示"
        ]),
        HelpCopySection(title: "键盘快捷键", items: [
            "⌘⌥M：切换主讲人模式，压低媒体声道和 BGM，突出现场人声",
            "⌘⌥B：紧急切黑，一键切黑副屏并静音",
            "⌘⌥P：切换 PPT 模式，接管翻页笔/方向键",
            "数字键 1-9：快速切换对应播放列表编号的信号源",
            "空格键：暂停/继续当前媒体播放",
            "[ / ] 键：BGM 音量减小 / 增大",
            ", 键：快速切换 BGM 播放/暂停",
            "← → 方向键：Keynote 上一页 / 下一页（PPT模式关闭时有效）"
        ])
    ]

    static var allText: String {
        sections.map { section in
            ([section.title] + section.items).joined(separator: "\n")
        }.joined(separator: "\n")
    }
}
