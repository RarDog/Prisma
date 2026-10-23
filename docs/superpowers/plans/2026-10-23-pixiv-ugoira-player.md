# Pixiv Ugoira (Animated Illustration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement native playback support for Pixiv animated artworks (Ugoira / うごイラ) including metadata fetching, background isolate ZIP extraction, interactive playback controls (play/pause, scrubber, frame stepping, speed control), feed badges, and release `4.2.1-beta.4` split APKs.

**Architecture:** Detect Ugoira via `illustType == 2` in Pixiv API responses, fetch `/ajax/illust/{id}/ugoira_meta` for ZIP URLs and frame delays, download and extract JPEG/PNG frames in a background isolate via `package:archive`, render via a custom `UgoiraPlayer` widget with precise millisecond delay scheduling, and display an `UGOIRA` badge on feed cards.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, `package:archive` (ZipDecoder), `compute` (isolates).

**Spec:** file:///home/rardog/.gemini/antigravity/brain/b888ccf2-7790-45f3-a6d8-5f16b1e34262/pixiv_ugoira_design.md

## Global Constraints

- Preserve all existing comments and docstrings.
- Zero UI stalls: ZIP decompression MUST occur off the main UI thread via `compute`.
- Exact author timing: frames must advance strictly following `delayMs` defined in Pixiv metadata.
- Backward compatibility: static image fallbacks must display immediately during download.

## Review Focus

1. Corrupted or partial ZIP downloads must fail gracefully and show a retry button without crashing the player.
2. Unpack operations with unexpected archive file naming must sort frames accurately by numeric index.
3. Rapid post switching / navigation away from an active Ugoira post must cancel ongoing downloads and release frame memory.
4. Pausing and scrubbing to an arbitrary frame must immediately render that exact frame without index out-of-bounds errors.
5. Zoom and pan gestures in fullscreen mode must remain functional while animation is actively playing.

---

### Task 1: Ugoira Models and Detection in PixivMapper & Post

**Files:**
- Create: `lib/sources/models/ugoira_metadata.dart`
- Modify: `lib/core/models/post.dart`
- Modify: `lib/sources/mappers/pixiv_mapper.dart`
- Test: `test/backend/pixiv_ugoira_test.dart`

- [ ] **Step 1: Write failing unit test for Ugoira detection & metadata parsing**
  - Create `test/backend/pixiv_ugoira_test.dart` verifying:
    - Post with `fileType == 'ugoira'` reports `post.isUgoira == true`.
    - `PixivMapper._postsFromIllustList` marks items with `illustType == 2` as `fileType = 'ugoira'`.
    - `PixivMapper.postsFromRankingResponse` marks items with `illust_type == '2'` as `fileType = 'ugoira'`.
    - `PixivMapper.ugoiraMetaFromResponse` correctly parses `src`, `mime_type`, and `frames` list with `file` and `delay`.

- [ ] **Step 2: Run test to confirm it fails**
  - Run `flutter test test/backend/pixiv_ugoira_test.dart`.

- [ ] **Step 3: Implement `UgoiraMetadata`, `post.isUgoira`, and `PixivMapper` parsing**
  - Create `lib/sources/models/ugoira_metadata.dart` with `UgoiraFrame` and `UgoiraMetadata`.
  - Add `bool get isUgoira => fileType.toLowerCase() == 'ugoira' || (tagGroups['media_type']?.contains('ugoira') ?? false);` to `Post`.
  - In `PixivMapper`:
    - Check `illustType == 2` in `_postsFromIllustList`.
    - Check `illust_type == '2'` or `2` in `postsFromRankingResponse`.
    - When true, set `fileType = 'ugoira'` and add `'ugoira'` to `tagGroups['media_type']`.
    - Add `static UgoiraMetadata? ugoiraMetaFromResponse(dynamic data)` to parse `/ajax/illust/{id}/ugoira_meta`.

- [ ] **Step 4: Run test to ensure it passes**
  - Run `flutter test test/backend/pixiv_ugoira_test.dart`.

- [ ] **Step 5: Commit changes**
  - `git add lib/sources/models/ugoira_metadata.dart lib/core/models/post.dart lib/sources/mappers/pixiv_mapper.dart test/backend/pixiv_ugoira_test.dart`
  - `git commit -m "feat(pixiv): add Ugoira detection, models, and metadata parser"`

---

### Task 2: PixivProvider `getUgoiraMeta` & `UgoiraService`

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/sources/booru/pixiv_provider.dart`
- Create: `lib/features/post/services/ugoira_service.dart`
- Test: `test/backend/ugoira_service_test.dart`

- [ ] **Step 1: Write failing unit test for `UgoiraService`**
  - Create `test/backend/ugoira_service_test.dart` creating a synthetic in-memory ZIP archive using `package:archive` with 2 dummy image frames, verifying `UgoiraService.unpackFrames` sorts and returns the frame byte buffers correctly.

- [ ] **Step 2: Run test to confirm failure**
  - Run `flutter test test/backend/ugoira_service_test.dart`.

- [ ] **Step 3: Implement `getUgoiraMeta` and `UgoiraService`**
  - Add `archive: ^3.6.1` to `pubspec.yaml` if not explicitly present.
  - In `PixivProvider`, add:
    ```dart
    Future<UgoiraMetadata?> getUgoiraMeta(String illustId) async
    ```
    querying `/ajax/illust/$illustId/ugoira_meta` with `_authOptions`.
  - In `lib/features/post/services/ugoira_service.dart`:
    - Implement `loadUgoiraFrames(UgoiraMetadata meta, Map<String, String> headers, {void Function(double)? onProgress})`.
    - Download zip bytes via `Dio` with progress stream.
    - Offload unpacking to `compute(_decodeZipFrames, zipBytes)`.
    - Cache frames in-memory by `meta.zipUrl`.

- [ ] **Step 4: Run test to confirm it passes**
  - Run `flutter test test/backend/ugoira_service_test.dart`.

- [ ] **Step 5: Commit changes**
  - `git add pubspec.yaml lib/sources/booru/pixiv_provider.dart lib/features/post/services/ugoira_service.dart test/backend/ugoira_service_test.dart`
  - `git commit -m "feat(pixiv): implement PixivProvider getUgoiraMeta and UgoiraService isolate extractor"`

---

### Task 3: `UgoiraPlayer` Widget & Player Controls

**Files:**
- Create: `lib/features/post/presentation/widgets/ugoira_player.dart`
- Modify: `lib/features/post/presentation/widgets/post_media_viewer.dart`
- Modify: `lib/features/post/presentation/widgets/fullscreen_image_viewer_page.dart`
- Test: `test/features/ugoira_player_test.dart`

- [ ] **Step 1: Write failing widget test for `UgoiraPlayer`**
  - Create `test/features/ugoira_player_test.dart` rendering `UgoiraPlayer` with mock frames, testing play/pause toggle, scrubber slider, frame stepping `<` and `>`, and speed selector.

- [ ] **Step 2: Run test to confirm failure**
  - Run `flutter test test/features/ugoira_player_test.dart`.

- [ ] **Step 3: Implement `UgoiraPlayer` widget**
  - Show placeholder `previewUrl` with download progress bar.
  - Once frames are loaded, start cyclic animation with `Timer` or `Ticker` matching `frame.delayMs / speed`.
  - Overlay controls (tap to show/hide with auto-hide timer):
    - Play / Pause button
    - Progress slider
    - Step `<` and `>` buttons when paused
    - Speed multiplier chip: 0.5x, 1x, 1.5x, 2x
    - Frame counter: `frame 12 / 48`
  - In `post_media_viewer.dart`:
    - When `post.isUgoira`, render `UgoiraPlayer` instead of static `_buildImageViewer`.
  - In `fullscreen_image_viewer_page.dart`:
    - Support interactive zoom/pan with active `UgoiraPlayer`.

- [ ] **Step 4: Run test to confirm it passes**
  - Run `flutter test test/features/ugoira_player_test.dart`.

- [ ] **Step 5: Commit changes**
  - `git add lib/features/post/presentation/widgets/ugoira_player.dart lib/features/post/presentation/widgets/post_media_viewer.dart lib/features/post/presentation/widgets/fullscreen_image_viewer_page.dart test/features/ugoira_player_test.dart`
  - `git commit -m "feat(ui): add UgoiraPlayer widget with frame scrubber and playback controls"`

---

### Task 4: `PostCard` Ugoira Badge

**Files:**
- Modify: `lib/shared/widgets/post_card.dart`
- Test: `test/features/post_card_ugoira_badge_test.dart`

- [ ] **Step 1: Write failing widget test for Ugoira badge**
  - Create `test/features/post_card_ugoira_badge_test.dart` verifying that `PostCard` displays an `UGOIRA` badge when `post.isUgoira == true`.

- [ ] **Step 2: Run test to confirm failure**
  - Run `flutter test test/features/post_card_ugoira_badge_test.dart`.

- [ ] **Step 3: Implement badge in `post_card.dart`**
  - In `_buildBadge`: if `post.isUgoira`, render a badge pill with `Icons.motion_photos_on_rounded` and text `"UGOIRA"`.

- [ ] **Step 4: Run test to confirm it passes**
  - Run `flutter test test/features/post_card_ugoira_badge_test.dart`.

- [ ] **Step 5: Commit changes**
  - `git add lib/shared/widgets/post_card.dart test/features/post_card_ugoira_badge_test.dart`
  - `git commit -m "feat(ui): display UGOIRA badge on feed cards"`

---

### Task 5: Version Bump to `4.2.1-beta.4` & Split APK Compilation

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/app/app_version.dart`
- Modify: `lib/app/changelog.dart`

- [ ] **Step 1: Bump version in `pubspec.yaml` and `app_version.dart`**
  - `version: 4.2.1-beta.4+123`
  - `appDisplayVersion = '4.2.1-beta.4'`, `appBuildNumber = 123`.

- [ ] **Step 2: Add changelog entry in `changelog.dart`**
  - Document Ugoira animated illustration playback, background isolate decompression, frame scrubber, and beta.4 release.

- [ ] **Step 3: Run static analysis & test suite**
  - Run `dart analyze .`
  - Run `flutter test`

- [ ] **Step 4: Build Android split APKs**
  - Run `flutter build apk --release --split-per-abi`
  - Verify that `arm64-v8a`, `armeabi-v7a`, and `x86_64` APKs are generated successfully.

- [ ] **Step 5: Commit changes**
  - `git commit -am "chore(release): bump version to 4.2.1-beta.4, add Ugoira playback support"`
