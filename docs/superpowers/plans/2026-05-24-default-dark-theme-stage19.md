# Default Dark Theme Stage 19 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make LiveSwitcher cold-start into the dark broadcast-console theme while preserving explicit user theme overrides.

**Architecture:** Keep the existing `ThemeOverride` enum, app menu, dynamic color tokens, and persisted override behavior. Only change the initial `SwitcherViewModel.themeOverride` value and update tests so an unset preference defaults to `.dark`.

**Tech Stack:** SwiftPM, Swift, XCTest, SwiftUI `ColorScheme`.

---

### Task 1: Default Theme Override

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/ThemeTokenTests.swift`
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift`

- [ ] **Step 1: Write the failing test**

Update `testThemeOverrideMapsToExpectedColorSchemeAndPersists` so a fresh `SwitcherViewModel` with no stored theme expects `.dark`:

```swift
XCTAssertEqual(viewModel.themeOverride, .dark)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter ThemeTokenTests/testThemeOverrideMapsToExpectedColorSchemeAndPersists
```

Expected: failure showing `.system` is not equal to `.dark`.

- [ ] **Step 3: Write minimal implementation**

Change the initial value in `ViewModel.swift`:

```swift
@Published var themeOverride: ThemeOverride = .dark {
    didSet {
        userDefaults.set(themeOverride.rawValue, forKey: UDKeys.themeOverride)
    }
}
```

- [ ] **Step 4: Run targeted tests**

Run:

```bash
swift test --filter ThemeTokenTests
```

Expected: all theme tests pass.

- [ ] **Step 5: Full verification and PR**

Run the required LiveSwitcher gates, screenshot the running app, commit, open a PR, wait for CI, and merge when green.

## Acceptance

- Fresh installs default to the dark console theme.
- Explicit persisted `system`, `light`, or `dark` choices still restore correctly.
- No layout, playback, projection, audio-routing, dependency, or version changes.
