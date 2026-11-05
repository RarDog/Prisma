# Feed Display Page Filling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure the feed loads full display pages (30 posts) instead of stopping at 2–3 posts when multiple tags or filters discard most raw provider results.

**Architecture:** Introduce `_loadBatch()` in `FeedController` that loops over `_load()` until at least `_targetPageSize = 30` deduplicated posts are accumulated, or until providers are exhausted (`consecutiveEmptyBatches >= 3`), or safety limit `_maxLoadAttempts = 5` is reached.

**Tech Stack:** Flutter, Riverpod (`AsyncNotifier`), Dart 3.

**Spec:** [`docs/superpowers/specs/2026-11-05-feed-page-fill-design.md`](file:///home/rardog/Документы/Project/Prizma/docs/superpowers/specs/2026-11-05-feed-page-fill-design.md)

## Global Constraints

- Preserve all existing comments and docstrings.
- Ensure static analysis is completely clean (`dart analyze` with zero warnings/errors).
- All tests in `flutter test` must pass deterministically without network dependencies.
- Respect request cancellation via `_loadRequestId` and `CancelToken`.

## Review Focus

- When raw pages yield only 2 posts each, `loadInitial` and `loadNextPage` must fetch subsequent pages until reaching 30 posts or exhausting attempts.
- When providers return empty results immediately, the loop must terminate after 3 empty attempts and mark `hasMore: false`.
- If a user triggers a new search or changes tags mid-loop, `requestId != _loadRequestId` must exit immediately without updating state.
- Deduplication by `cacheKey` must prevent the same post from being added twice across loop iterations.

---

### Task 1: Create Unit Test for Feed Page Filling

**Files:**
- Create: `test/features/feed_page_fill_test.dart`

**Interfaces:**
- Consumes: `FeedController`, `feedControllerProvider`, `feedServiceProvider`, `Post`, `Result`
- Produces: Test verifying that `FeedController` executes multiple page loads to accumulate target posts when each page yields a small number of filtered posts.

- [ ] **Step 1: Write the failing unit test**

Create `test/features/feed_page_fill_test.dart` with a mock/fake `FeedService` returning 3 posts per page. Verify that `loadInitial()` or `loadNextPage()` accumulates 30 posts (or multiple pages).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/feed_page_fill_test.dart`
Expected: FAIL (because current implementation only returns the first 3 posts and exits).

---

### Task 2: Implement `_loadBatch()` in `FeedController`

**Files:**
- Modify: `lib/features/feed/presentation/feed_controller.dart`

**Interfaces:**
- Consumes: `_load(refresh: bool, current: FeedState)`, `_loadRequestId`, `FeedState`
- Produces: `_loadBatch({required bool refresh, required FeedState current, required int requestId, Set<String>? existingKeys})`

- [ ] **Step 1: Add constants and `_loadBatch()` method**

In `lib/features/feed/presentation/feed_controller.dart`:
- Add `static const int _targetPageSize = 30;`
- Add `static const int _maxLoadAttempts = 5;`
- Implement `_loadBatch(...)` to loop while `accumulated.length < _targetPageSize && attempts < _maxLoadAttempts && consecutiveEmptyBatches < 3`.

- [ ] **Step 2: Update `loadInitial()`, `refresh()`, and `loadNextPage()` to use `_loadBatch()`**

- `loadInitial()`: `final posts = await _loadBatch(refresh: true, current: current, requestId: requestId);`
- `refresh()`: `final posts = await _loadBatch(refresh: true, current: current, requestId: requestId);`
- `loadNextPage()`: `final newPosts = await _loadBatch(refresh: false, current: current, requestId: requestId, existingKeys: existingKeys);`

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/features/feed_page_fill_test.dart`
Expected: PASS.

---

### Task 3: Regression Testing and Analysis

**Files:**
- Verify: entire test suite and static analysis

- [ ] **Step 1: Run static analysis**

Run: `dart analyze`
Expected: No issues found!

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Commit the changes**

Run: `git add . && git commit -m "feat(feed): fill display pages by accumulating posts up to target page size"`
