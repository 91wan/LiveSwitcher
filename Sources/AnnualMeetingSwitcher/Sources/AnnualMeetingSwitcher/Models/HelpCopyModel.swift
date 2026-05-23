import Foundation

struct HelpCopySection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let items: [String]
}

enum HelpCopyModel {
    static let sections: [HelpCopySection] = [
        HelpCopySection(title: "常用必备功能（红色 = ON AIR / 危险状态）", items: [
            "主讲人模式：顶部【主讲人】按钮，开启后进入 warning/review 状态，媒体声道和 BGM 压至 7% 突出人声",
            "PPT翻页笔：顶部【PPT模式】开启后进入 warning/review 状态，翻页笔方向键控制 WPS/PPT 翻页（需辅助功能权限，开启失败时 App 会自动引导设置）",
            "投射副屏：左侧底部【投射：关/开】，ON AIR 为红色 live 状态；无外接屏时不会投射，副屏断开会立即停止投射",
            "Panic / 老板键：顶部【老板键】紧急切黑副屏并静音，激活时为 critical red，再点恢复"
        ]),
        HelpCopySection(title: "视频与音频操作", items: [
            "添加视频：左侧【选择视频】按钮，支持 MP4/MOV/AVI 等格式，支持拖拽入列",
            "添加HTML大屏：左侧【选择 HTML】按钮，选择 HTML 文件，点击即推流至副屏全屏展示",
            "切换画面：点击播放列表中的项目立即切换大屏（切换时自动淡出音频防止音画撕裂）",
            "背景音乐：预览页右侧【现场 BGM】可直接播控当前曲目、查看列表、拖动进度，并一键跳到完整音乐库",
            "音频混音：顶部切换至【音频混音】页面，可管理 BGM 列表、音频策略，以及主音量 / 媒体 / BGM 三路推子"
        ]),
        HelpCopySection(title: "壁纸与叠层", items: [
            "背景壁纸：中栏底部【壁纸库】，导入图片后点击即激活为大屏背景",
            "倒计时叠层：叠层控制面板开启【倒计时】，直接输入分钟/秒数（默认10分钟），叠加显示在大屏",
            "游动字幕：叠层控制面板开启【游动字幕】，输入内容后在大屏顶部横向滚动（字体已放大）",
            "下三分之一：叠层控制面板开启【人名条】，展示嘉宾姓名/职位，点击上屏/退场控制显示"
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
