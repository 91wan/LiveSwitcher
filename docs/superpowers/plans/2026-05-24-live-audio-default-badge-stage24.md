# Live Audio Default Badge Implementation Plan

**Goal:** Make Live Mode audio status follow status-by-exception by hiding the default routing badge and keeping warning/fail/live states visible.

**Scope:** One SwiftUI view plus static/model coverage. No audio routing behavior changes.

---

### Task 1: Live Audio Strip Badge Policy

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LiveAudioDefaultBadgeTests.swift`

- [x] **Step 1: Write failing static test**

Assert `LiveModeView.swift` no longer directly renders `StatusBadge(viewModel.audioStrategy.displayTitle, kind: audioStatusKind)` and instead gates the badge through `StatusBadgeVisibilityPolicy`.

- [x] **Step 2: Verify RED**

Run: `swift test --filter LiveAudioDefaultBadgeTests`

- [x] **Step 3: Implement minimal view cleanup**

Wrap the Live Audio Strip routing badge in `StatusBadgeVisibilityPolicy.shouldShow(text:kind:)`.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter LiveAudioDefaultBadgeTests`

- [x] **Step 5: Full verification and screenshot**

Run the standard verification chain and capture LiveSwitcher after launch to confirm no regression in the visible console.
