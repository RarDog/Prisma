# Design: Feed Display Page Filling (Virtual Page Accumulator)

## 1. Intent & Context
When users search with multiple tags or have active filters (Smart Blacklist, rating filters, hide viewed posts), a single raw provider request of 50 posts may yield only 2–3 posts after client-side filtering (`postMatchesRequestedTags`, `SmartBlacklistMatcher`, `hideViewedPosts`).

Currently, `FeedController` executes `_load()` only once during `loadInitial()` / `refresh()`, and stops immediately in `loadNextPage()` as soon as `posts.isNotEmpty`. Consequently, the feed displays a sparse 2–3 posts on the screen, requiring repeated manual scrolling and creating a broken, jittery user experience.

The goal of this change is to implement buffered page filling in `FeedController`, fetching consecutive raw pages until a target display page size (30 posts) is reached or upstream sources are exhausted.

---

## 2. Goals & Non-Goals

### Goals
* **Full Display Pages**: Ensure initial loads, refreshes, and paginations accumulate posts until reaching at least `_targetPageSize` (30 posts) or until providers run out of posts.
* **Safety & Infinite Loop Prevention**: Cap the consecutive raw page fetch attempts at `_maxLoadAttempts = 5` per user load action, preventing runaway network requests if few or no matching posts exist upstream.
* **Fast Cancellation**: Retain full responsiveness to user cancellation (`CancelToken` and `_loadRequestId`), cleanly terminating the fetch loop if the user edits search tags or navigates away mid-load.
* **Stable Deduplication**: Deduplicate incoming posts by `cacheKey` (`$providerId:$id`) during batch accumulation before adding them to state.
* **Exhaustion State**: Properly flag `hasMore = false` when providers return zero new posts over consecutive attempts.

### Non-Goals
* Adjusting provider-specific tag limits (e.g. Danbooru 2-tag constraint) — this will be addressed in a subsequent step.
* Changing post card layout, provider badges, or UI components.
* Altering the low-level `FeedService` or `ContentProvider` contracts.

---

## 3. Approaches Considered

1. **Approach A: Controller-level Buffering & Loop (Selected)**
   * *Description*: `FeedController` orchestrates repeated calls to `_load()` until `accumulatedPosts.length >= _targetPageSize` or `attempts >= _maxLoadAttempts`.
   * *Trade-offs*: Keeps `FeedService` as an atomic, single-page data fetcher. Accurately coordinates `CancelToken` and `_loadRequestId`. Follows the proven pattern from `ArtistsScreen`.
2. **Approach B: Service-level Accumulation inside `FeedService.loadNextPage()`**
   * *Description*: Move the loop into `FeedService`, making `loadNextPage` return 30 filtered posts directly.
   * *Trade-offs*: Makes `FeedService` non-atomic and complicates cancellation management when multiple concurrent requests occur.
3. **Approach C: Raising raw request limit (e.g. `limit = 100`)**
   * *Description*: Request 100 items per call instead of 50.
   * *Trade-offs*: Fails when filters discard 95%+ of items, and booru engines often cap page limits at 50–100.

---

## 4. Implementation Details

### Changes to `lib/features/feed/presentation/feed_controller.dart`:
* Define constants:
  * `static const int _targetPageSize = 30;`
  * `static const int _maxLoadAttempts = 5;`
* Refactor `_loadBatch({required bool refresh, required FeedState current})`:
  * A helper method that loops calling `_load(refresh: refresh, current: current)` (with subsequent iterations using `refresh: false`).
  * Deduplicates items against an active `Set<String> seenKeys`.
  * Stops when `posts.length >= _targetPageSize`, or `attempts >= _maxLoadAttempts`, or when consecutive empty responses indicate provider exhaustion, or when `_loadRequestId` changes.
* Update `loadInitial()`, `refresh()`, and `loadNextPage()` to use `_loadBatch`.
* Update `hasMore` and `emptyPageStreak` state transitions based on the accumulated results.

---

## 5. Verification Plan
* **Unit/Widget tests**:
  * Verify `FeedController` fetches multiple raw batches when each raw batch yields fewer than `_targetPageSize` posts.
  * Verify `FeedController` halts when `_maxLoadAttempts` is reached or upstream returns empty.
  * Verify that cancellation aborts in-flight batches cleanly.
* **Static Analysis**: `dart analyze` must report 0 issues.
* **Automated Tests**: `flutter test` must pass.
