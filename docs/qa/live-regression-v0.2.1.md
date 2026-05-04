# LiveSwitcher v0.2.1 Live Regression Checklist

Use this checklist before publishing or using a public build at a live event. Mark hardware-only items honestly; do not mark external-display unplug checks as passed without hardware.

## Build And Launch

- Preconditions: latest `main`, clean worktree, macOS 14+, app built from this repository.
- Steps: run `swift build`, `swift test`, `./script/build_and_run.sh --verify`.
- Expected: build and tests pass; app launches and remains running.
- Result: `Pass / Fail / Not verified`

## Neutral Demo Data

- Preconditions: app is not running.
- Steps: run `./script/seed_demo_data.sh`, then launch with `LIVESWITCHER_USER_DEFAULTS_SUITE=com.91wan.liveswitcher.demo ./dist/LiveSwitcher.app/Contents/MacOS/LiveSwitcher`.
- Expected: queue shows `Opening Video`, `Product Highlights`, `Dinner Loop`; BGM list shows neutral music names; screenshots contain no real customer, city, activity, or local user path.
- Result: `Pass / Fail / Not verified`

## Projection Safety: No External Display

- Preconditions: no external display is connected.
- Steps: click `投射：关`.
- Expected: no full-screen black window appears on the main display; projection remains off; safety notice says no external display was detected.
- Result: `Pass / Fail / Not verified`

## Projection Safety: External Display Lost

- Preconditions: external display is connected and projection is on.
- Steps: unplug the external display while projection is active.
- Expected: projection stops, `isBroadcasting` becomes false, main display is not covered by an output window, and a safety notice says the external display was disconnected.
- Result: `Pass / Fail / Not verified: hardware unavailable`

## Panic Blackout

- Preconditions: app is running; optional external display connected.
- Steps: click `老板键` or press `⌘⌥B`; repeat to restore.
- Expected: button enters an obvious emergency state; audio is muted during panic; second activation restores the previous state.
- Result: `Pass / Fail / Not verified`

## Speaker Mode

- Preconditions: a video or BGM item is playing.
- Steps: click `主讲人` or press `⌘⌥M`; repeat to restore.
- Expected: media/video audio and BGM are both ducked to the 7% ceiling over about 2 seconds; closing speaker mode restores the previous routing without changing the selected audio strategy.
- Result: `Pass / Fail / Not verified`

## BGM Takeover

- Preconditions: a video item is playing and the BGM list has at least one item.
- Steps: start BGM from the right rail; stop the same BGM item.
- Expected: media audio fades down while BGM fades in; stopping BGM fades media audio back according to the current audio strategy.
- Result: `Pass / Fail / Not verified`

## Wallpaper Drop

- Preconditions: app is running on the preview tab.
- Steps: drag a local PNG or JPG onto `拖入图片`; then drag a non-image file onto the same area.
- Expected: image is added as a thumbnail and can become the active wallpaper; non-image file is ignored.
- Result: `Pass / Fail / Not verified`

## Auto-Next Video

- Preconditions: queue contains at least two video items followed by one non-video item.
- Steps: confirm the toggle is off and let a video end; then enable `播毕自动下一条视频` and let the first video end again.
- Expected: default off returns to wallpaper; enabled state only advances to the immediately next video and never opens HTML, PPTX, or Keynote.
- Result: `Pass / Fail / Not verified`

## PPT Mode Shortcut

- Preconditions: app is running.
- Steps: press `⌘⌥P`; repeat to restore.
- Expected: PPT mode toggles and matches the top button state. If macOS permission is missing, the app shows the normal permission path rather than failing silently.
- Result: `Pass / Fail / Not verified`
