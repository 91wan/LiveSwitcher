# Zero Count Pill Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove default `0` count pills from Run/Live setup surfaces so empty states are communicated by empty-state copy and warnings rather than extra badges.

**Architecture:** Add a pure `CountPillVisibilityPolicy` and apply it only to noisy count pills in Run Queue, Live source rail, and Standby Wallpaper. Keep Safety Cockpit summary counts unchanged.

**Tech Stack:** SwiftPM, Swift, SwiftUI, XCTest.

---

### Task 1: Count Pill Visibility Policy

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/CountPillVisibilityPolicy.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/CountPillVisibilityPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests for zero counts being hidden, positive counts remaining visible, and the three noisy views using the policy.

- [ ] **Step 2: Run targeted test to verify RED**

Run: `swift test --filter CountPillVisibilityPolicyTests`

Expected: compile failure because `CountPillVisibilityPolicy` does not exist.

- [ ] **Step 3: Implement policy and view wiring**

Create the policy and wrap the affected `CountPill` calls with `if CountPillVisibilityPolicy.shouldShow(count:)`.

- [ ] **Step 4: Run targeted test to verify GREEN**

Run: `swift test --filter CountPillVisibilityPolicyTests`

Expected: pass.

- [ ] **Step 5: Run full verification and screenshot**

Run the standard verification chain and capture the Run Desk screenshot confirming the zero pills are gone.
