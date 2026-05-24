# Preflight Header Badge Implementation Plan

**Goal:** Finish status-by-exception cleanup for the preflight popover header so passing preflight state does not render a prominent default badge.

**Scope:** One pure model plus the preflight popover header. No preflight check logic or report behavior changes.

---

### Task 1: Gate Preflight Header Badge

**Files:**
- Add: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PreflightHeaderBadgeModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PreflightHeaderBadgeModelTests.swift`

- [x] **Step 1: Write failing model test**

Assert passing preflight hides the header badge while warn/fail remain visible.

- [x] **Step 2: Verify RED**

Run: `swift test --filter PreflightHeaderBadgeModelTests`

- [x] **Step 3: Implement minimal header badge model**

Use `StatusBadgeVisibilityPolicy` from a dedicated `PreflightHeaderBadgeModel` and render only visible states in `PreflightPopoverView`.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter PreflightHeaderBadgeModelTests`

- [x] **Step 5: Full verification and screenshot**

Run the standard verification chain and capture the app to confirm the top-level console is unaffected.
