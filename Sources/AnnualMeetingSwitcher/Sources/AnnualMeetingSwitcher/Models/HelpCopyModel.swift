import Foundation

struct HelpCopySection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let items: [String]
}

enum HelpCopyModel {
    static let sections: [HelpCopySection] = [
        HelpCopySection(title: "常用必备功能（红色 = ON AIR / 危险状态）", items: [
            "主讲人模式：右侧 Live Ops 的 Modes 卡片集中控制；开启后进入 warning/review 状态，媒体声道和 BGM 压至 7% 突出人声",
            "PPT翻页笔：右侧 Live Ops 的 Modes 卡片集中控制；开启后进入 warning/review 状态，翻页笔方向键控制 WPS/PPT 翻页（需辅助功能权限，开启失败时 App 会自动引导设置）",
            "投射副屏：右侧 Live Ops 的 Output 卡片控制；ON AIR 为红色 live 状态，无外接屏时不会投射，副屏断开会显示 Display Lost",
            "Panic / 老板键：顶部【老板键】紧急切黑副屏并静音，激活时为 critical red，再点恢复"
        ]),
        HelpCopySection(title: "视频与音频操作", items: [
            "添加素材：左侧 Run Queue 顶部【Add Source】菜单导入 Video / Audio、HTML、PPTX、Keynote，也支持拖拽入列",
            "添加HTML大屏：在 Add Source 菜单选择 HTML 文件，点击队列项目即推流至副屏全屏展示",
            "切换画面：点击播放列表中的项目立即切换大屏（切换时自动淡出音频防止音画撕裂）",
            "背景音乐：右侧 Live Ops 的 BGM mini 只提供当前曲目、基础播控和进度；完整 BGM Library 位于 Audio 页面",
            "音频混音：顶部切换至 Audio 页面，可管理 BGM Library、音频策略，以及主音量 / 媒体 / BGM 三路推子"
        ]),
        HelpCopySection(title: "壁纸与叠层", items: [
            "背景壁纸：中栏底部【壁纸库】，导入图片后点击即激活为大屏背景",
            "倒计时叠层：Overlays / Overlay Composer 页面准备倒计时，再 Send Live 上屏",
            "游动字幕：Overlays / Overlay Composer 页面输入内容后上屏，在大屏顶部横向滚动",
            "下三分之一：Overlays / Overlay Composer 页面准备嘉宾姓名/职位，再 Send Live 或 Stop 控制显示"
        ]),
        HelpCopySection(title: "键盘快捷键", items: [
            "⌘⌥M：切换主讲人模式，压低媒体声道和 BGM，突出现场人声",
            "⌘⌥B：Panic / 老板键，一键切黑副屏并静音",
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
