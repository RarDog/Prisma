# Download Dynamic Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy rectangular bottom-pinned download panel with a responsive, modern frosted-glass Dynamic Island component floating at the top of the screen on mobile and top-right on desktop.

**Architecture:** A reactive widget `DownloadDynamicIslandOverlay` listening to `downloadTasksProvider`, wrapping the app root and rendering `DownloadDynamicIsland` with fluid state transitions (collapsed capsule, expanded queue card, success pulse, swipe dismissal).

**Tech Stack:** Flutter 3.24+, Riverpod, `cached_network_image`, Liquid Glass (`BackdropFilter`), Dart 3.3+.

**Spec:** `docs/superpowers/specs/2026-10-24-download-dynamic-island-design.md`

## Global Constraints
* AMOLED black compatibility (`0xFF000000`) and Material 3 Liquid Glass theme support.
* Bilingual localized strings for Russian (`isRu`) and English.
* No regressions to `DownloadManagerService` or background download queue.
* Zero layout overflow (`RenderFlex overflowed`) across narrow mobile screens (320px–420px) and wide desktop displays.

## Review Focus
* Active download stream with zero percentage (indeterminate or starting).
* Rapid task completion auto-dismissal without memory leaks or unmounted state updates.
* Multi-task batch download (e.g. downloading all pages of a post set).
* Tap outside expanded card or swipe-to-dismiss behavior.
* Thumbnail image load error or null post fallback.

---

### Task 1: Create `DownloadDynamicIsland` and `DownloadDynamicIslandOverlay`

**Files:**
- Create: `lib/features/downloads/presentation/widgets/download_dynamic_island.dart`
- Test: `test/features/download_dynamic_island_test.dart`

**Steps:**
- [ ] Write initial widget test in `test/features/download_dynamic_island_test.dart` verifying `DownloadDynamicIsland` renders collapsed pill with progress and thumbnail placeholder when a task is running.
- [ ] Implement `DownloadDynamicIsland`:
  - Frosted glass container with `BackdropFilter`, rounded capsule border, and AMOLED/dark theme adaptation.
  - Collapsed state: thumbnail preview (from `task.post?.previewUrl` / `sampleUrl`), task count, percentage, progress indicator, and expand indicator.
  - Expanded state: detailed queue list, queue pause/resume controls, cancel buttons, and retry buttons.
  - Completed state: emerald success badge with action to open/dismiss.
  - Gestures: tap to toggle expand/collapse, swipe gesture (`Dismissible` or `onHorizontalDragEnd`) to dismiss.
- [ ] Implement `DownloadDynamicIslandOverlay`:
  - Listens to `downloadTasksProvider`.
  - Renders `DownloadDynamicIsland` at top center on mobile (`SafeArea(top: true) + 8px`) and top-right on desktop.
- [ ] Run `flutter test test/features/download_dynamic_island_test.dart` to verify the test passes.
- [ ] Commit: `feat(downloads): create DownloadDynamicIsland and overlay component`.

---

### Task 2: Integrate `DownloadDynamicIslandOverlay` into `PrismaApp` and Remove Legacy Panel

**Files:**
- Modify: `lib/app/app.dart:160-340`

**Steps:**
- [ ] Import `download_dynamic_island.dart` in `lib/app/app.dart`.
- [ ] Replace `_DownloadOverlay(child: widget.child)` with `DownloadDynamicIslandOverlay(child: widget.child)` in `PrismaApp.build()`.
- [ ] Remove legacy `_DownloadOverlay` and `_DownloadPanel` classes from `lib/app/app.dart`.
- [ ] Run `dart analyze` to ensure zero compilation warnings or dead code.
- [ ] Commit: `refactor(app): wire DownloadDynamicIslandOverlay and remove legacy download panel`.

---

### Task 3: Comprehensive Widget Tests & Verification

**Files:**
- Modify/Extend: `test/features/download_dynamic_island_test.dart`

**Steps:**
- [ ] Add widget test for expanding on tap and collapsing on toggle.
- [ ] Add widget test for completed task rendering and clear/dismissal.
- [ ] Add widget test verifying pause queue and cancel buttons trigger `DownloadManagerService` methods.
- [ ] Run full test suite: `flutter test test/features/` and `dart analyze`.
- [ ] Commit: `test(downloads): add comprehensive test suite for DownloadDynamicIsland`.
