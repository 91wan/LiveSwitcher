# Panic Danger Toolbar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the global Panic button visually critical in every console mode so emergency blackout is never presented as a normal blue action.

**Architecture:** Add a tiny pure `PanicButtonModel` for MainToolbar labels, metrics, and visual role. MainToolbar consumes the model instead of deriving panic tint/size inline.

**Tech Stack:** SwiftPM, Swift, SwiftUI, XCTest.

---

### Task 1: Panic Button Model

**Files:**
- Create: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PanicButtonModel.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/MainToolbar.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PanicButtonModelTests.swift`

- [ ] **Step 1: Write the failing model test**

Add tests proving inactive setup panic is still `.danger`, live mode keeps a large target, and active state changes copy.

- [ ] **Step 2: Run targeted test to verify RED**

Run: `swift test --filter PanicButtonModelTests`

Expected: compile failure because `PanicButtonModel` does not exist.

- [ ] **Step 3: Implement model and wire MainToolbar**

Create `PanicButtonModel` with `visualRole == .danger` for every state, `height`, `minWidth`, title/subtitle, icon, and accessibility strings. Replace `MainToolbar` inline panic derivation with the model.

- [ ] **Step 4: Run targeted test to verify GREEN**

Run: `swift test --filter PanicButtonModelTests`

Expected: pass.

- [ ] **Step 5: Run full verification and screenshot**

Run the standard build/test/release-hygiene/package chain, then launch the app and capture a Run Desk screenshot proving the top Panic button is red.
