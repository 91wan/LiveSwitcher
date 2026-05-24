# Residual Default Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the status-by-exception cleanup by removing residual default idle badges from Help, Overlay, BGM Library, and Audio Library surfaces.

**Architecture:** Reuse `StatusBadgeVisibilityPolicy` where a model already supplies status text/kind. Replace overlay default `OFF` badges with muted plain text while preserving `LIVE` badges.

**Tech Stack:** SwiftPM, SwiftUI, XCTest static coverage.

---

### Task 1: Residual Default Badge Cleanup

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/HelpPopoverView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/OverlayControlPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/BGMPlaylistPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AudioMixerView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ResidualDefaultBadgeTests.swift`

- [x] **Step 1: Write failing static tests**

Assert default Help/LIBRARY/OFF badge literals are gone and BGMPlaylistPanel uses `StatusBadgeVisibilityPolicy`.

- [x] **Step 2: Run targeted test to verify RED**

Run: `swift test --filter ResidualDefaultBadgeTests`

Expected: fail against current sources.

- [x] **Step 3: Implement minimal view cleanup**

Remove Help and Audio Library idle badges, hide BGM idle/cued badges through the policy, and replace Overlay OFF badges with subdued plain text.

- [x] **Step 4: Run targeted test to verify GREEN**

Run: `swift test --filter ResidualDefaultBadgeTests`

Expected: pass.

- [x] **Step 5: Run full verification and screenshot**

Run the standard verification chain and capture the app to confirm default idle badges are reduced on the live console; Overlay and Audio surfaces are locked by static source tests.
