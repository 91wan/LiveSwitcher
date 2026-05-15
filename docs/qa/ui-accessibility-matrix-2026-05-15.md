# UI Accessibility Matrix / UI 可访问性矩阵

Version context: LiveSwitcher `0.4.0` UI-only hardening branch.

Scope: final accessibility and responsive sweep after the live-console hierarchy, design-system adoption, preview-console polish, and audio/overlay/safety surface passes.

## Automated Gates

- `swift build`: passed.
- `swift test`: passed.
- `cd Sources/AnnualMeetingSwitcher && swift test`: passed.
- `git diff --check`: passed.
- `./script/check_release_hygiene.sh`: passed.
- `PATH=/usr/bin:/bin:/usr/sbin:/sbin ./script/check_release_hygiene.sh`: passed.
- `./script/build_and_run.sh --verify`: passed.

## Static UI Sweep

Checked the main control UI files for raw status colors, legacy foreground APIs, and ad-hoc rounded rectangles:

```bash
rg -n "Color\(red:|foregroundColor\(|\.red\b|\.blue\b|\.orange\b|\.purple\b|\.gray\b|\.green\b|Color\.black|Color\.white|RoundedRectangle\(cornerRadius: [0-9]|cornerRadius\(" \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RightPanel.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/BGMPlaylistPanel.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AudioMixerView.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift \
  Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SafetyCockpitView.swift
```

Result: no matches outside approved theme/component surfaces.

## Runtime Matrix

Runtime target: `dist/LiveSwitcher.app`, launched with `./script/build_and_run.sh --verify`.

Screenshots were used for local review only and intentionally not committed because local runtime data can contain operator media names, wallpaper text, or other non-public content.

| Size | Preview / Switch | Audio Mixer | Overlays | Preflight / Help |
| --- | --- | --- | --- | --- |
| `1360x700` | Checked: top status bar, navigation, Speaker/Panic/PPT/Preflight/Help, queue, Program Monitor, right live rail visible without clipping. | Checked: selected tab renders with accessible toolbar state and visible audio controls. | Checked: overlay controls remain reachable through the existing scroll layout. | Checked: Preflight is separate from Help and exposes result/action feedback labels. |
| `1360x760` | Checked: Preview layout remains readable with no toolbar clipping. | Noted for follow-up manual screenshot pass if release packaging requests public images. | Noted for follow-up manual screenshot pass if release packaging requests public images. | Noted for follow-up manual screenshot pass if release packaging requests public images. |
| `1440x800` | Checked: Preview layout keeps Program Monitor as the center focus and rails remain secondary. | Noted for follow-up manual screenshot pass if release packaging requests public images. | Noted for follow-up manual screenshot pass if release packaging requests public images. | Noted for follow-up manual screenshot pass if release packaging requests public images. |
| Maximized | Checked during prior UI matrix runs; no new layout behavior was introduced in this slice. | Not changed in this slice. | Not changed in this slice. | Not changed in this slice. |

## Accessibility Notes

- Compact toolbar controls now expose labels, values, hints, and help text.
- Preflight summary, empty attention state, action result, support result, row actions, and non-mutating guidance badges expose readable labels/hints.
- Hidden keyboard shortcut buttons are hidden from accessibility.
- Program queue transport buttons expose specific actions: play/pause, jump to beginning, skip to end, delete.
- Program and BGM progress sliders expose time values.
- Channel faders expose percentage values.
- BGM category picker exposes the selected category.
- Overlay action buttons expose action labels and disabled hints.

## Public Asset Hygiene

No screenshots were committed in this pass. Future public README or release screenshots should be captured with neutral seeded demo data only.
