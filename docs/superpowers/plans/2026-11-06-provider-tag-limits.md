# Provider Search Tag Limits & 422 Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow providers to specify their maximum search tag limits via `TagLimitProvider`, cap query tags to that limit (specifically 2 tags for Danbooru), and ensure HTTP 422 responses do not falsely mark providers as offline.

**Architecture:** Introduce `TagLimitProvider` in `content_provider.dart`. Implement it in `DanbooruProvider` with query tag truncation and 422 catch. Update `ProviderManager._searchForTagGroup` to clamp tags for `TagLimitProvider` instances and prevent `ProviderStatus.offline` health records on 422 validation errors.

**Tech Stack:** Dart 3, Dio, Flutter Riverpod.

**Spec:** [`docs/superpowers/specs/2026-11-05-provider-tag-limits-design.md`](file:///home/rardog/Документы/Project/Prizma/docs/superpowers/specs/2026-11-05-provider-tag-limits-design.md)

## Global Constraints

- Do not widen `ContentProvider`: `TagLimitProvider` must remain a separate capability interface.
- Maintain documentation integrity and keep existing comments intact.
- Zero warnings/errors on `dart analyze`.
- All deterministic tests must pass in `flutter test`.

## Review Focus

- When `DanbooruProvider.searchPosts` receives 3+ tags and a rating, it truncates to 2 tags rather than throwing 422.
- When an upstream provider returns HTTP 422, `ProviderManager` records diagnostics but does NOT mark the provider offline.
- When `DanbooruProvider` receives HTTP 422 from upstream, it handles it gracefully and returns an empty list without bubbling an unhandled exception.
- Client-side tag filtering (`postMatchesRequestedTags`) in `FeedService` continues to evaluate the full requested tag list against the returned posts.

---

### Task 1: Add Unit Tests for Tag Limit and 422 Handling

**Files:**
- Create: `test/sources/provider_tag_limits_test.dart`

- [ ] **Step 1: Write the tests for `DanbooruProvider` tag truncation and 422 fallback**
- [ ] **Step 2: Write test for `ProviderManager` 422 offline avoidance**
- [ ] **Step 3: Run tests to verify they fail**

---

### Task 2: Implement `TagLimitProvider` Capability

**Files:**
- Modify: `lib/sources/interfaces/content_provider.dart`

- [ ] **Step 1: Add `TagLimitProvider` interface**

```dart
abstract class TagLimitProvider {
  int get maxSearchTags;
}
```

---

### Task 3: Implement `TagLimitProvider` in `DanbooruProvider`

**Files:**
- Modify: `lib/sources/booru/danbooru_provider.dart`

- [ ] **Step 1: Implement `TagLimitProvider` with `maxSearchTags => 2`**
- [ ] **Step 2: Clamp `queryTags` to `maxSearchTags`**
- [ ] **Step 3: Catch 422 `DioException` and return empty post list**

---

### Task 4: Update `ProviderManager` Tag Clamping and 422 Offline Safety

**Files:**
- Modify: `lib/sources/provider_manager.dart`

- [ ] **Step 1: In `_searchForTagGroup`, clamp `cleanTags` if provider is `TagLimitProvider`**
- [ ] **Step 2: Skip saving `ProviderStatus.offline` when error is 422**

---

### Task 5: Verification and Commit

**Files:**
- Entire test suite & static analysis

- [ ] **Step 1: Run `test/sources/provider_tag_limits_test.dart` to verify it passes**
- [ ] **Step 2: Run `dart analyze` to verify zero issues**
- [ ] **Step 3: Run full `flutter test`**
- [ ] **Step 4: Commit changes**
