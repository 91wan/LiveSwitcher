# LiveSwitcher Release Candidate Rehearsal

## Scope and honesty rule

Automated tests are not hardware evidence. A row is PASS only after direct observation by the operator running this rehearsal. Unavailable hardware is BLOCKED or NOT RUN, not PASS.

Do not commit customer files, raw system logs, screenshots, videos, local paths, or private event content. Store sanitized evidence outside the repository or in the release issue.

Each rehearsal records SHA, version, environment, automated checks, manual results, failures, and the release decision in the PR body, release issue, or external acceptance record. Do not create a new version-specific QA markdown file for each rehearsal.

Legacy baseline continuity:

- Preconditions: latest `main`, clean worktree, macOS 14+, app built from this repository.
- Steps: run `swift build`, `swift test`, `./script/build_and_run.sh --verify`.
- Expected: build and tests pass; app launches and remains running.

## Candidate metadata

| Field | Value |
|---|---|
| Commit SHA | |
| VERSION | |
| macOS version | |
| Mac model / architecture | |
| Display setup | |
| Audio output device | |
| Keynote version | |
| WPS version | |
| Accessibility permission state | |
| Apple Events permission state | |
| Operator | |
| Start time | |
| End time | |

## Automated gate

Run from a clean worktree at the exact release candidate commit.

```bash
git status --short
git rev-parse HEAD
cat VERSION

swift build
swift test
swift test --package-path Sources/AnnualMeetingSwitcher

git diff --check

./script/check_workspace_guard.sh --dev
./script/test_workspace_guard.sh

./script/check_release_hygiene.sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh

./script/build_and_run.sh --verify
bash Sources/AnnualMeetingSwitcher/build_v33.sh

plutil -lint dist/LiveSwitcher.app/Contents/Info.plist
codesign --verify --deep --strict dist/LiveSwitcher.app

plutil -p dist/LiveSwitcher.app/Contents/Info.plist \
  | grep -E 'CFBundleShortVersionString|CFBundleIdentifier|LSMinimumSystemVersion'

shasum -a 256 dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher
```

| Gate | Result | Evidence |
|---|---|---|
| Clean worktree | | |
| Root build | | |
| Root tests | | |
| Package tests | | |
| Workspace guard | | |
| Workspace guard tests | | |
| Release hygiene | | |
| Fallback PATH hygiene | | |
| App launch verification | | |
| Release bundle build | | |
| Info.plist lint | | |
| Signature verification | | |
| Version/bundle metadata | | |

## Test media and isolated profile

Use a separate defaults suite:

```bash
export LIVESWITCHER_DEMO_SUITE="com.91wan.liveswitcher.rc"
./script/seed_demo_data.sh

LIVESWITCHER_USER_DEFAULTS_SUITE=com.91wan.liveswitcher.rc \
  ./dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher
```

`seed_demo_data.sh` creates media and audio placeholders suitable for UI and persistence smoke only. They are not valid playable media. Real playback rehearsal requires neutral, non-sensitive, valid fixtures.

Prepare:

- 2 valid 10-30 second videos: Video A, Video B
- 3 valid 10-30 second audio files: BGM A, BGM B, BGM C
- 1 local HTML file
- 1 non-sensitive Keynote deck: Deck A
- 1 non-sensitive PPTX deck
- 1 test wallpaper
- 1 neutral overlay text set

Do not use customer files.

## Preflight and support evidence

Before manual scenarios:

1. Open `? -> Preflight`.
2. Review `Needs attention`.
3. Open Safety Cockpit.
4. Use `Copy Support`.
5. Save one sanitized support report outside the repository.
6. Do not commit screenshots, logs, or customer data.

Record:

- Preflight FAIL count
- Preflight WARN count
- highest risk item
- whether Support Report contains paths or filenames

After manual scenarios, repeat Preflight, Safety Cockpit, and `Copy Support`.

Compare start and end:

- unexpected FAIL rows
- Panic still active
- Projection still on
- PPT mode still on
- BGM takeover still on
- active overlay still visible
- privacy redaction failure

## Manual scenario matrix
Use this result vocabulary only: PASS, FAIL, BLOCKED, NOT RUN.
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|

### Hardware rehearsal closeout
Codex-created PRs must keep every row at NOT RUN until direct operator observation updates the result.

Latest operator smoke note:

- Operator approved merging the current numbered-badge and BGM return-to-start PRs after app-launch/manual checks. No detailed hardware matrix row results, final app hash acceptance, or 60-minute soak evidence were provided in-repo, so the rows below remain `NOT RUN`.
- Operator manually tested and approved the live-ops rail chrome and blackout monitor status PRs in Codex thread. The rows directly covered by PR #375/#376 are recorded as `PASS`; final app hash acceptance, 60-minute soak evidence, and unrelated/unobserved detailed hardware rows remain `NOT RUN`.
- Operator confirmed manual test acceptance in Codex thread for the current production app. PR #359 changes docs/tests only; stable automated gates, bundle hash recording, and final human acceptance are recorded as `PASS`. The 60-minute soak remains `NOT RUN` until explicit soak evidence or waiver.

| 场景 | 结果 | 证据/备注 |
|---|---|---|
| 旧人名条 JSON 无损迁移 | NOT RUN | |
| 姓名+职位同一行 | NOT RUN | |
| 公司名称第二行 | NOT RUN | |
| 长文本缩放与 720/1080/4K | NOT RUN | |
| 进度轨道使用整行主要宽度 | NOT RUN | |
| 进度拖动仍走 Runtime | NOT RUN | |
| 节目拖出列表后释放不重排 | NOT RUN | |
| 演示就绪汇总条已移除 | NOT RUN | |
| readiness 行内提示全中文 | NOT RUN | |
| 拖入提示为一行 | NOT RUN | |
| 准备页主监看水平居中 | NOT RUN | |
| 现场叠层全部清空 | NOT RUN | |
| Monitor/Output 清空无残留 | NOT RUN | |
| 节目单首尾拖拽排序 | NOT RUN | |
| 当前节目移动不打断播放 | NOT RUN | |
| 排序后重启仍保留 | NOT RUN | |
| 拖拽不误触节目切换 | NOT RUN | |
| 三种新建按钮文案与跳转 | NOT RUN | |
| Monitor 人名条同步 | NOT RUN | |
| Monitor 倒计时实时同步 | NOT RUN | |
| Monitor ticker 同步 | NOT RUN | |
| Monitor 三叠层组合 | NOT RUN | |
| Monitor 清空无残留 | NOT RUN | |
| 媒体进度拖动 25%/75% | NOT RUN | |
| seek 时切换视频的 stale 防护 | NOT RUN | |
| 多项删除无误删/崩溃 | NOT RUN | |
| BGM 30s 暂停/原位恢复 | NOT RUN | |
| BGM pause/resume 20 次 | NOT RUN | |
| BGM 显式 stop 后从 0 开始 | NOT RUN | |
| 现场任意曲目选择/搜索 | NOT RUN | |
| 1080p ticker 顶边全宽 | NOT RUN | |
| 4K/缩放 ticker 顶边全宽 | NOT RUN | |
| ticker 文字从右侧画外进入 | NOT RUN | |
| 8 种叠层组合 | NOT RUN | |
| 人名条可读性 | NOT RUN | |
| Logo 四角与无碰撞 | NOT RUN | |
| Logo 换图/失败/移除/重启 | NOT RUN | |
| 壁纸监看实时更新 | NOT RUN | |
| 监看与副屏壁纸裁切一致 | NOT RUN | |
| 回到片头不播放 | NOT RUN | |
| 视频 pause/resume 20 次 | NOT RUN | |
| ended + auto-next off/on | NOT RUN | |
| 主持人/PPT 整卡命中 | NOT RUN | |
| 切黑/Panic 抢占恢复 | NOT RUN | |
| Toggle/Button/Slider 焦点下 Space/数字不被抢走 | NOT RUN | |
| 紧急快捷键在输入焦点下仍有效 | NOT RUN | |
| 公司名称设置/恢复默认 | NOT RUN | |
| 四个顶部标题同步 | NOT RUN | |
| 长公司名称最小窗口布局 | NOT RUN | |
| Support Report 不泄漏公司名 | NOT RUN | |
| Logo 显示/隐藏即时切换 | NOT RUN | |
| 隐藏 Logo 重启恢复 | NOT RUN | |
| 隐藏状态替换/失败保留 | NOT RUN | |
| Monitor/外屏 Logo 同步 | NOT RUN | |
| 新建 agenda marker | NOT RUN | |
| 编辑 marker 标题/时间/时长 | NOT RUN | |
| 旧 Break 数据不丢失 | NOT RUN | |
| marker 在 Live rail 不可误点 | NOT RUN | |
| “到点提醒”标签清晰 | NOT RUN | |
| 无 current 的第一项提醒 | NOT RUN | |
| marker 到点提醒 | NOT RUN | |
| idle 等待仍准时提醒 | NOT RUN | |
| 提醒不自动切换 | NOT RUN | |
| 提醒 Timer/clock 无残留 | NOT RUN | |
| 60 分钟 soak | NOT RUN | |
| 准备页节目编号可读 | NOT RUN | |
| 现场节目编号可读 | NOT RUN | |
| 10+ 节目编号不裁剪 | NOT RUN | |
| marker cue row 编号可读 | NOT RUN | |
| 现场 1.5–2 米距离编号可读 | NOT RUN | |
| BGM 播放中回到开头微淡化 | NOT RUN | |
| BGM 暂停中回到开头仍暂停 | NOT RUN | |
| BGM 静音/主持人模式回到开头无异常 | NOT RUN | |
| 快速连续回到开头不串音 | NOT RUN | |
| BGM 切歌中回到开头不拉高旧歌 | NOT RUN | |
| 准备页右侧现场控制侧栏外壳与左侧对称 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| 右侧现场控制底部 footer 对齐 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| 切黑监看同步黑场 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| 紧急切黑监看同步黑场 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| App monitor 显示 blackout 原因 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| 外接屏不显示本地 blackout 状态文字 | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |
| Stable final automated gates | PASS | Local release gate and GitHub Actions Smoke Tests passed for PR #359; details recorded in PR body. |
| Stable final app hash recorded | PASS | Bundle executable SHA-256 recorded in PR #359 body. |
| Stable final human acceptance recorded | PASS | Operator confirmed manual test acceptance in Codex thread; PR #359 production code changes are none. |
| Stable 60-minute soak | NOT RUN | |

### Clean launch and persistence
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-01 | Candidate bundle built; app not running | Launch the app with the RC defaults suite | App starts, no crash, main window is operable, no unexpected output window covers the main screen | | |
| RC-02 | RC suite seeded | Confirm demo queue, BGM, and wallpaper state | RC suite is isolated from production user data; demo queue/BGM/wallpaper are visible | | |
| RC-03 | Settings changed: audio strategy, speaker mode, BGM play mode, auto-next, agenda reminder, agenda timeline, wallpaper, corner logo, queue order | Quit fully and relaunch with the same RC suite | Inputs restore, Runtime-derived Audio output recalculates, no duplicate queue item, no ghost BGM | | |

### Media lifecycle
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-10 | Video A loaded | Play, pause, restart, and seek | UI state and real player agree; restart starts at 0; seek does not trigger incorrect auto-next | | |
| RC-11 | Video A playing; Video B queued | Switch to Video B; wait past Video A's original end time | Stale callback from Video A does not clear or switch Video B | | |
| RC-12 | Auto-next off | Let Video A finish | No automatic switch; app returns to safe expected state | | |
| RC-13 | Auto-next on; queue Video A, Video B, HTML | Let Video A and then Video B finish | Video A advances to Video B; Video B does not auto-open HTML | | |
| RC-14 | Current program is media | Remove the current media item | Player stops, selection clears, no stale playback continues | | |

### BGM lifecycle
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-20 | BGM A available | Start and stop BGM | Audible fade in and configured fade out; UI state matches real audio | | |
| RC-21 | BGM A/B/C ordered | Use next and previous | Order is respected, no overlapping playback, old player eventually releases | | |
| RC-22 | BGM play modes available | Verify loop one, loop all, sequential | Behavior matches selected mode | | |
| RC-23 | Current BGM playing | Reorder BGM list | Current playback continues; next track uses new order | | |
| RC-24 | Current BGM playing | Remove a non-current BGM | Current playback continues; removed track is not selected by next or reached-end | | |
| RC-25 | Current BGM playing | Remove current BGM | Real player stops, current BGM clears, progress/time reset, track does not revive, timer stops | | |
| RC-26 | BGM list ready | Switch tracks 20 times quickly | No overlapping audio, no stale callback mutates new track, no timer spins while idle | | |

### Audio routing
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-30 | Media/BGM playable | Change master, media, BGM, master mute, media mute, BGM mute | Real output and UI state agree | | |
| RC-31 | Media or BGM playing | Toggle speaker mode on and off | Media/BGM duck together; restore after off; persisted strategy unchanged | | |
| RC-32 | Media playing; BGM ready | Start and stop BGM takeover | Media fades/ducks when BGM starts; media restores when BGM stops | | |
| RC-33 | Routing settings changed | Quit and relaunch | Strategy and speaker mode restore; effective output recalculates from final routing context | | |

### Projection and hot-plug
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-40 | No external display | Attempt projection | Projection fails closed, main screen is not covered, safety notice is visible | | |
| RC-41 | External display connected | Start projection | Output appears only on external display; main screen keeps console | | |
| RC-42 | Projection active on external display | Hot unplug display | Broadcasting stops immediately, output window does not migrate to main screen, display-lost notice appears | | |
| RC-43 | Display disconnected then reconnected | Reconnect and observe | Availability returns, projection does not auto-start, operator can start again | | |
| RC-44 | External display available | Repeat start/stop 10 times and unplug/replug 3 times | No residual output window, hang, or state mismatch | | |

### Panic
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-50 | Media playing; BGM playing; projection active | Enter Panic | External screen enters safe state, Media stops/mutes by policy, BGM stops by fade/delay policy, no audible leak | | |
| RC-51 | Panic snapshot exists | Exit Panic | Only snapshot-eligible items restore; deleted or manually stopped items do not revive | | |
| RC-52 | Panic controls available | Repeat 20 cycles | No generation drift, timer residue, duplicate resume, or UI/Runtime split | | |

### PPT EventTap
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-60 | Accessibility permission missing | Start PPT mode | Failure is visible, facade returns off, permission guidance is clear | | |
| RC-61 | Accessibility permission granted | Start then stop PPT mode | Pending start shows on, started stays on, stop returns off | | |
| RC-62 | PPT mode on | Press PageDown/Right and PageUp/Left | Only expected keys forward; after PPT mode off, keys are not swallowed | | |
| RC-63 | Permission granted | Repeat 20 on/off cycles | No global intercept remains, app exits normally, resources do not keep growing | | |

### Keynote and WPS
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-70 | Apple Events permission missing | Trigger Keynote action | Visible failure, Automation Notice and Support Event are correct, no unredacted path | | |
| RC-71 | Keynote installed and permission granted | Open/present, next, previous, stop | Keynote control is stable and visible | | |
| RC-72 | WPS not running | Trigger WPS fallback path | No crash; clear notice/support event | | |
| RC-73 | WPS running with target deck | Forward page keys | Keys reach intended WPS process, not another app | | |

### Overlays
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-80 | Overlay presets configured | Show lower third, countdown, ticker, then clear all | Display and hide correctly; clear all leaves no residue; Panic/Projection do not corrupt state | | |

### Support-report privacy
| ID | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|
| RC-90 | Non-sensitive scenarios completed | Export Support Report | No `/Users/`, `/Volumes/`, `file://`, real media/deck names, overlay text, or customer content; includes app version, diagnostics, preflight, event kinds, redacted runtime actions | | |

## Soak and lifecycle cycling
Run a 60-minute soak when hardware is available.
Every 5 minutes:
- switch Media A/B
- BGM next/previous
- speaker mode on/off
- Panic on/off
- overlay show/clear
Every 10 minutes:
- projection start/stop
- PPT mode on/off
When hardware allows, include one external-display unplug/replug and one Keynote/WPS switch.

Sample resources at start, 30 minutes, 60 minutes, and after 5 idle minutes:

```bash
PID="$(pgrep -x LiveSwitcher | head -n1)"
ps -p "$PID" -o pid=,etime=,%cpu=,rss=,command=
```

Record CPU, RSS, trend, and whether idle state stabilizes.

## Stop conditions
P0 release blockers:
- crash, hang, or beachball
- main screen covered by output window
- broadcasting continues after external display disconnect
- audible leak during Panic
- Panic restore revives deleted or manually stopped items
- stale callback clears or switches new program
- deleted BGM reappears
- PPT mode swallows global keys after off
- Support Report leaks path or customer content
- persistence corruption or duplicate queue
P1 release blockers:
- core operator control unresponsive
- Media/BGM state differs from real player
- Keynote/WPS control consistently fails
- projection cannot recover after reconnect
- speaker/takeover routing is wrong
- repeated switching causes sustained resource growth
- app cannot exit normally

P2 issues are cosmetic or low-risk text, layout, animation, or visual inconsistencies that do not affect live operation.

## Go / no-go decision
GO requires:
- automated gate all PASS
- P0 count is 0
- P1 count is 0
- all applicable hardware scenarios PASS
- unexecuted scenarios have explicit BLOCKED reason
- 60-minute soak completed
- start/end Support Reports show no privacy leak
- release commit matches tested commit
NO-GO if any P0/P1 exists, hardware skips are unexplained, tested commit differs from release commit, hardware PASS is claimed from unit tests, or applicable hot-plug/Panic/PPT scenarios are not completed.

## Failure report template
## Failure report
- Scenario ID:
- Candidate SHA:
- Severity:
- Environment:
- Preconditions:
- Exact steps:
- Expected:
- Actual:
- Reproducibility:
- Sanitized Support Report attached:
- Screenshot/video contains only neutral fixtures:
- Suspected domain:
- Workaround:
- Release decision:
One failure gets one bug PR. Do not mix domains in one fix. Do not refactor while fixing. Start with a failing behavior test.
