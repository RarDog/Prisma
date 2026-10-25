# Design: Download Dynamic Island

## 1. Intent & Context
Prisma's download indicator has remained untouched since the project's inception. It currently renders as a monolithic, opaque rectangular `Material` card in the bottom-right corner (`_DownloadOverlay` and `_DownloadPanel` in `lib/app/app.dart`), completely obscuring bottom navigation bars on mobile, lacking thumbnails of the media being downloaded, and displaying raw technical filenames without percentages or Liquid Glass styling.

The goal is to replace this legacy panel with a modern **Dynamic Island** component: an unobtrusive, reactive frosted-glass pill floating at the top of the screen that expands on demand and auto-dismisses gracefully.

---

## 2. Goals & Non-Goals

### Goals
* **Zero UI Blockage**: Place the compact pill at the top of the screen under the status bar on mobile (and top-right on desktop), preventing any overlap with bottom navigation, feed controls, or post action docks.
* **Liquid Glass & AMOLED Aesthetics**: Use `BackdropFilter` (frosted blur), subtle glowing borders, and AMOLED-compatible black/dark palettes matching Prisma's visual language.
* **Visual Media Preview**: Render a small thumbnail of the artwork being downloaded from `task.post?.previewUrl` / `task.post?.sampleUrl`.
* **State Machine & Expansion**:
  * *Collapsed (Default)*: Mini capsule with thumbnail/spinner, percentage/count, and subtle expand indicator.
  * *Expanded*: Detailed card showing queue progress, individual items, gradient progress bars, and pause/cancel actions.
  * *Completed*: Soft emerald success pulse with direct "Open" action and 4-second auto-dismiss.
* **Interactive Dismissal**: Allow users to swipe the island away (horizontally or upwards) at any time.

### Non-Goals
* Re-architecting `DownloadManagerService` or storage logic (the existing queue, cancellation tokens, and storage services work well).
* A full-screen downloads manager page (this spec focuses solely on the in-app HUD/overlay).

---

## 3. Approaches Considered

1. **Bottom Floating Dock**:
   * *Description*: Floating dock pinned above the bottom navigation bar.
   * *Trade-off*: Clutters the thumb zone and frequently collides with post viewers, bottom sheets, and the main bottom nav bar.
2. **Standard SnackBar / Toast Notifications**:
   * *Description*: Simple system snackbars for download start and completion.
   * *Trade-off*: No live progress tracking, no queue pause/resume controls, and feels non-interactive.
3. **Top Dynamic Island (Selected)**:
   * *Description*: Centered top pill on mobile (`SafeArea.top + 8px`), top-right on desktop. Expands into a detailed frosted-glass card upon tap.
   * *Trade-off*: Best in class ergonomics; keeps the main viewing viewport clean while offering full control when tapped.

---

## 4. Architecture & Component Structure

### New File: `lib/features/downloads/presentation/widgets/download_dynamic_island.dart`
* **`DownloadDynamicIslandOverlay`**:
  * Wraps the application root in `Stack` (replacing `_DownloadOverlay` in `lib/app/app.dart`).
  * Listens to `downloadTasksProvider`.
  * Computes active and recently finished tasks.
  * Positions the island adaptively:
    * Mobile (`width < 720`): `Alignment.topCenter` with `top: MediaQuery.paddingOf(context).top + 8`.
    * Desktop (`width >= 720`): `Alignment.topRight` with `top: 16, right: 16`.
* **`DownloadDynamicIsland`**:
  * Stateful widget managing `_isExpanded` and swipe-to-dismiss states.
  * Uses `AnimatedContainer` and `AnimatedCrossFade` for fluid morphing between collapsed and expanded forms.
  * Liquid glass container: `ClipRRect(borderRadius: 24)` + `BackdropFilter(sigma: 16)` + `Container(decoration: ...)`.
  * **Collapsed Layout**:
    * Dimensions: height ~38px, width ~200–240px.
    * Left: 24x24 thumbnail (with fallback circular progress / icon).
    * Center: text `⬇ 1 файл • 65%` or `✓ Скачано`.
    * Right: mini chevron or clear icon.
  * **Expanded Layout**:
    * Dimensions: maxWidth 360px, height wraps content.
    * Header with title, active/finished counters, queue pause/resume button, clear all button.
    * Task rows with thumbnails, titles, speed/percentage, gradient progress indicators, and individual retry/cancel buttons.

### Modifications:
* `lib/app/app.dart`: remove legacy `_DownloadOverlay` and `_DownloadPanel`, replace with `DownloadDynamicIslandOverlay(child: widget.child)`.

---

## 5. Verification & Testing
* Unit & widget test: `test/features/download_dynamic_island_test.dart` verifying:
  1. Renders collapsed island when active tasks are present.
  2. Expands on tap to display detailed task list.
  3. Displays success state on download completion.
  4. Dismisses on swipe.
