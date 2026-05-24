# Status Badge Exception Stage 20 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce post-redesign status noise by hiding normal idle/ready card badges in the operator rails while preserving exception, live, muted, and active-audio badges.

**Architecture:** Add a tiny pure `StatusBadgeVisibilityPolicy` model and use it only in `LiveOpsPanel.opsCard` and `LiveModeView.quickCard`. The policy keeps exception semantics testable without changing business state models or shared `StatusBadge` rendering.

**Tech Stack:** SwiftPM, Swift, XCTest, SwiftUI.

---

### Task 1: Status Badge Visibility Policy

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/StatusBadgeVisibilityPolicy.swift`
- Create: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/StatusBadgeVisibilityPolicyTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveOpsPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`

- [ ] **Step 1: Write failing policy tests**

Add tests for:

```swift
XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "NORMAL", kind: .ready))
XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "IDLE", kind: .idle))
XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "STANDBY", kind: .idle))
XCTAssertFalse(StatusBadgeVisibilityPolicy.shouldShow(text: "OFF", kind: .idle))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "WARN", kind: .warn))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "DISPLAY LOST", kind: .fail))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "ON AIR", kind: .live))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "MUTED", kind: .muted))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "PLAYING", kind: .ready))
XCTAssertTrue(StatusBadgeVisibilityPolicy.shouldShow(text: "EMPTY", kind: .warn))
```

- [ ] **Step 2: Verify red**

Run:

```bash
swift test --filter StatusBadgeVisibilityPolicyTests
```

Expected: compile failure because `StatusBadgeVisibilityPolicy` does not exist.

- [ ] **Step 3: Implement policy**

Create:

```swift
struct StatusBadgeVisibilityPolicy {
    static func shouldShow(text: String, kind: StudioTheme.StatusKind) -> Bool {
        switch kind {
        case .fail, .warn, .live, .muted:
            return true
        case .ready:
            return activeReadyTexts.contains(normalized(text))
        case .idle:
            return false
        }
    }

    private static let activeReadyTexts: Set<String> = ["PLAYING"]

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
```

- [ ] **Step 4: Wire operator rail cards**

Wrap the trailing `StatusBadge` in both `opsCard` and `quickCard`:

```swift
if StatusBadgeVisibilityPolicy.shouldShow(text: status, kind: kind) {
    StatusBadge(status, kind: kind)
}
```

- [ ] **Step 5: Verify**

Run targeted tests, full gates, screenshot the running app, commit, open PR, wait for CI, and merge when green.

## Acceptance

- Normal/idle card badges no longer render by default in Live Ops and Live mode quick rail.
- Warn/fail/live/muted and BGM `PLAYING`/`EMPTY` remain visible.
- No changes to playback, projection, audio routing, source switching, or shared status badge styling.
