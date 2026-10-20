# LiveSwitcher 项目精简规划

English summary: remove confirmed orphan Theme declarations first; investigate inert helpers separately; require a SENSITIVE review before changing packaging or runtime ownership. Preserve current behavior, useful tests, resources, and historical release evidence.

## 基线与范围

- Exact parent: `6766640bd583652c735fb42af65f1ca844622061`。
- Parent tree: `0ab301f3d2733f791651ed3c86675bd0c7ca3afd`。
- 当前源码库存按 tracked files、`wc -l` 计数，排除 `.build` 和 `dist`：

| Owner | Swift 文件 | 物理行数 |
| --- | ---: | ---: |
| Production app target | 359 | 32,061 |
| Root / nested `Package.swift` | 2 | 50 |
| 非测试 Swift 合计 | 361 | 32,111 |
| Tests，含测试 helper | 520 | 69,669 |

“361 个 production Swift”包含两个 manifest；32,061 行只对应 app target，不能混用计数口径。数量用于说明范围，不是删除指标。

当前 parent 在 Swift 6.4 / Xcode 27.1、macOS 26.7.1、arm64 上 `swift build` 成功，`swift test` 为 3,894 tests / 0 failures / 0 skips；workspace guard、guard tests、normal / minimal-PATH hygiene 均通过。旧工具链结果未直接继承。当前 candidate 的 full Stack 与独立验收仍 pending，不作已验收声明。

旧 frozen release S1 `aabe3fbf04080ff4362d5648fa7df6ac290a6447`、S2 `846ce95eebd0d682ff3a0f3c4a32a0ae317048dd` 保留在独立分支，不作为本次 cleanup 的 parent。旧 worktree、dirty bytes 和 release evidence 全部保留。

## P1: Theme orphan deletion

本片是 STANDARD、单 owner、behavior-neutral 的本地候选，只修改以下三个源码文件及本规划：

| 文件，路径相对 app target | 精确删除名单 |
| --- | --- |
| `Views/Theme/StudioTheme+Components.swift` | `CriticalActionButton` |
| `Views/Theme/StudioTheme+Layout.swift` | `spacingXS`、`spacingXL`、`Spacing.xxs`、`Spacing.xl`、`Spacing.m` |
| `Views/Theme/StudioTheme+Colors.swift` | `Surface.Opacity.subtle`、`actionGradient` |

价值：收缩不可达声明，降低读者判断有效 Theme API 的成本，不改 active UI。施工前在 exact parent 的全部 tracked text 中复核，只有定义和 `spacingXS -> Spacing.xxs`、`spacingXL -> Spacing.xl` 两条内部 alias 边；`Spacing.m` 无 consumer。远程页面的 `.subtle` 是 HTML/CSS class，与 Swift token 无关。

这里只证明维护表面下降，不声称运行速度、内存或产物体积改善；compiler 可能已剔除这些死声明。本片 STANDARD 不依赖 Planner，历史 release Plan / PASS 不作为本轮证据或授权。

Theme 入口为 Swift enum，各 token 为静态成员，组件为 SwiftUI struct；本名单没有 Objective-C、selector、注册表或 Interface Builder 入口。不得把名字相近、声明较短或只缺少限定名命中的其他符号顺手删除。

风险与 KEEP：保留相邻 `EmptyStateView`、`SecondaryActionButton`，保留 `hairline`、`Surface.pressed`、monitor tokens 和 Typography aliases；它们有 active caller 或显式测试。保留所有未列名的 spacing、radius、status token。测试文件不修改、不删除、不弱化。

可观察验收与检查映射：

- Theme 声明及既有 consumer -> `swift build`，证明所有当前 app target caller 仍可编译。
- Theme namespaces、动态颜色、monitor 与 typography contract -> `swift test --filter 'StudioThemeTokenContractTests|ThemeTokenTests|StudioThemeSplitTests'`，断言保持原样，0 failures / 0 skips。
- 授权 diff -> 只出现三个源码路径和本规划，源码仅有上述删除；`git diff --check` 无错误。
- 本次没有新 bug 或新 control，不构造 parent RED，也不新增“符号已删除”镜像测试。

Slice checks 可在 dirty bytes 上运行；clean-only workspace guard 留到提交后。形成一个 exact-parent direct-child 本地 commit 后，先交独立 Pre-Stack Semantic Review。通过后才运行授权的 root / nested full tests、CI-shaped build / guard / guard tests / hygiene（normal 与 minimal PATH）/ `build_v33` / plist / codesign / diff，并做 Post-Stack Attestation。当前 full Stack 尚未执行。

本片不改 active view body，若出现动态可达性疑点即停止对应删除；纯不可达代码删除不要求新启动 App。任何 UI 行为变化都需另行界定范围与截图验收。

## P2: 独立 inert code / test-maintenance 候选

以下只是后续建议，不属于本片施工授权：

| Owner / 文件 | 价值与已知证据 | 风险与可观察验收 |
| --- | --- | --- |
| `Tests/.../RuntimeTestFactory.swift` | `audioOwnedStore`、`recordingOnlyStore` 为 definition-only；收缩无调用的测试 factory | 另片限定删除名单，复核全仓引用；保留有实际调用的 `fullRuntimeStore`，受影响测试及完整 discovery 维持有效 |
| `Views/LowerThirdOverlay.swift` 与 `Tests/.../LowerThirdOverlaySplitTests.swift` | 旧文件只有两行注释，去除为旧路径保留的 shell | 现有测试显式读取该路径，须先取得合适的测试契约变更范围；保留 `LowerThirdView`、`TickerTrackGeometry`、`TickerEngine`、`TickerOverlay` 四个 renderer 的存在与复杂度检查 |
| `Models/BGMRuntimeCleanupCoordinator.swift`、`Models/PanicTransitionPlan.swift`、`Models/PPTModeToggleModel.swift` 及各自测试 | Coordinator / Panic plans 当前仅测试消费；PPT 文件仅 `PPTModeToggleModel.nextState` helper 为 test-only | 同文件 `PPTModeToggleSource` 有 Runtime、ViewModel、toolbar 的 production consumer，必须 KEEP，不能整文件删。先 characterise 真实 production replacement，证明 generation guard、Panic 恢复和 PPT toggle 的有效行为由当前路径覆盖；按 owner 分片，不直接删除保护测试来制造 GREEN |

每片先绑定调用路径、要保留的 invariant 和现有决定性检查；替代覆盖不足时 KEEP。涉及 test contract 或 ownership 变化时由对应风险范围审查，不把本规划当作预授权。

## P3: SENSITIVE natural seam 提案

以下两项均需独立 Plan Review，当前仅记录方向：

| Owner / 受影响文件 | 价值 | 风险与可观察验收 |
| --- | --- | --- |
| Bundle assembly：`Sources/AnnualMeetingSwitcher/build_v33.sh`、`script/build_and_run.sh` | 沿 app-bundle 装配职责收敛重复流程，减少 plist / resources / icon / codesign 的维护触点 | 不机械合并入口；保留 release / debug 的现有差异。以各入口实际 bundle 的版本、ID、权限说明、localizations、icon、resources 和签名检查证明等价；新增共享代码必须有明确单一 owner |
| Runtime stage factories 与 `Runtime/LiveRuntimeBridgeMode.swift` 的 consumer | 澄清 stage factory 与 bridge mode 的真实差异，减少无效组合与重复 writer | 先裁定 `.panicOwned` 与 `.fullRuntime` 的真实语义和调用约定；保留单 writer、现有 ownership 与 effect 边界。以各 stage 的 action -> state / effect / callback acceptance characterization 证明行为，不通过改名或删模式假装收敛 |

若不能减少普通修复触及的实质 owner 或重复决策，选择 KEEP，不新建通用 Manager、framework、gate、manifest 或 scan policy。

## 明确保留的路径

| KEEP | Consumer / 原因 |
| --- | --- |
| Root / nested `Package.swift` | Root build/test 与 nested package/build 入口都在使用；不是无用重复源码 |
| Localizations 与 `Bundle.module` | 两个 manifest 声明 resources；`AudioStrategy`、`ConsoleMode`、`AudioMixerView` 通过 `.module` 读本地化 |
| `AppIcon.icns` | 两个 bundle build script 复制并在 plist 引用；不覆盖其他 worktree 的本地图标 |
| `ConsoleModeSwitchProfiler` | `ContentView` 实际调用 begin / end / log，提供诊断 |
| Persistence migration keys | `SwitcherPersistenceStore` 读取旧 key 并迁移清理；无新写入不等于无 consumer |
| `script/seed_demo_data.sh` | 既有隔离演示流程入口，本次不运行；工具脚本不按 app target caller 数判死 |
| 历史 QA、release 与 frozen screenshot evidence | 保存原版本验收和恢复语境；不是当前 runtime dependency，不从历史少引用推导可删 |

## 研究边界与不做事项

[Periphery 原仓库](https://github.com/peripheryapp/periphery) 仅作历史调查资料：它已于 2026-08-12 archive，不推荐安装成新的 active dependency。其文档说明 index 必须覆盖所有相关 target；Objective-C 动态入口与 Codable 合成代码会影响 unused 判断。外部工具报告只给线索，删除由本地 caller 与入口证据决定。

[Apple 的 Swift package resource 文档](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package) 说明 resources 按 target 打包，并由 `Bundle.module` 定位。不能因文件没有普通 Swift caller 就删资源、manifest 或 build-copy 路径。

本片不做 Runtime / ports / bridge mode / persistence / build / workflow / VERSION 变更，不做 UI redesign，不调整源码根或 test discovery。只交本地候选，不 push、开 PR、merge、tag、release、install 或修改 `/Applications`、用户偏好和其他用户数据。旧 release 的 soak / promotion 不作为本次 cleanup 门禁；本地 cleanup 通过也不产生发布权限。
