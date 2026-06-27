# LiveSwitcher Release Candidate Rehearsal

## Scope and Honesty

This file is the canonical rehearsal template for future release candidates. It is not a historical results log.

Automated tests are not hardware evidence. A scenario is PASS only after direct operator observation during the rehearsal. Unavailable hardware is BLOCKED or NOT RUN, not PASS.

Do not commit customer files, raw system logs, screenshots, videos, local paths, private event content, or real media filenames. Store sanitized evidence outside the repository or in the release issue.

For frozen v0.5.0 release evidence, see [`release-acceptance-v0.5.0.md`](release-acceptance-v0.5.0.md). Future release candidates should record results in the PR body, release issue, or external acceptance record, then keep this template clean.

## Candidate Metadata

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

## Automated Gate

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
| Executable SHA-256 recorded | | |

## Test Media and Isolated Profile

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

## Preflight and Support Evidence

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

## Manual Scenario Matrix

Use this result vocabulary only: PASS, FAIL, BLOCKED, NOT RUN.

| ID | Area | Preconditions | Steps | Expected | Result | Evidence |
|---|---|---|---|---|---|---|

Suggested scenario areas:

- Clean launch and persistence
- Media lifecycle
- BGM lifecycle
- Audio routing
- Projection and hot-plug
- Panic
- PPT EventTap
- Keynote and WPS
- Overlays
- Support-report privacy
- Soak and lifecycle cycling

Every filled row must include sanitized evidence or an external evidence pointer. Do not pre-fill historical results in this template.

## Soak and Lifecycle Cycling

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

## Stop Conditions

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

## Go / No-Go Decision

GO requires:

- automated gate all PASS
- P0 count is 0
- P1 count is 0
- all applicable hardware scenarios PASS
- unexecuted scenarios have explicit BLOCKED reason
- 60-minute soak completed when hardware is required for the candidate
- start/end Support Reports show no privacy leak
- release commit matches tested commit

NO-GO if any P0/P1 exists, hardware skips are unexplained, tested commit differs from release commit, hardware PASS is claimed from unit tests, or applicable hot-plug/Panic/PPT scenarios are not completed.

## Failure Report Template

```markdown
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
```

One failure gets one bug PR. Do not mix domains in one fix. Do not refactor while fixing. Start with a failing behavior test.
