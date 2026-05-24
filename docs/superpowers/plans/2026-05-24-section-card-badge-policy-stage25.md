# Section Card Badge Policy Implementation Plan

**Goal:** Finish status-by-exception cleanup for shared section cards by preventing default idle section metadata from rendering as prominent status badges.

**Scope:** One shared SwiftUI component plus static coverage. No card layout or runtime behavior changes.

---

### Task 1: Gate StudioSectionCard Status Badges

**Files:**
- Modify: `Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift`
- Test: `Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SectionCardBadgePolicyTests.swift`

- [x] **Step 1: Write failing static test**

Assert `StudioSectionCard` only renders `StatusBadge` when `StatusBadgeVisibilityPolicy.shouldShow(text:kind:)` returns true.

- [x] **Step 2: Verify RED**

Run: `swift test --filter SectionCardBadgePolicyTests`

- [x] **Step 3: Implement minimal shared component cleanup**

Wrap the `StatusBadge(status.0, kind: status.1)` call in the shared policy.

- [x] **Step 4: Verify GREEN**

Run: `swift test --filter SectionCardBadgePolicyTests`

- [x] **Step 5: Full verification and screenshot**

Run the standard verification chain and capture the app to confirm the shared card change does not disturb the visible Run console.
