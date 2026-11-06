# Multi-Provider Content Deduplication, Card Branding & Feed Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deduplicate identical artworks across different providers by MD5 signature, brand `ProviderBadge` with source colors, and keep the feed view stable on background soft retries.

**Architecture:** Add `md5Hash` and `contentDedupeKey` on `Post`. Update `FeedController._loadBatch` and `_applySoftRetryResult` to deduplicate against `contentDedupeKey` and append new items without reshuffling existing posts. Enhance `ProviderBadge` in `post_card_badges.dart` to render a brand accent dot.

**Tech Stack:** Flutter, Dart 3, Riverpod.

**Spec:** [`docs/superpowers/specs/2026-11-06-multi-provider-feed-ux-design.md`](file:///home/rardog/Документы/Project/Prizma/docs/superpowers/specs/2026-11-06-multi-provider-feed-ux-design.md)

## Global Constraints

- Do not alter Isar schema (`CachedPostEntity` is unchanged; metadata relies on `tagGroups` and getters).
- Preserve all existing comments and documentation.
- Maintain zero issues on `dart analyze`.
- Pass all tests in `flutter test`.

## Review Focus

- Two posts from different providers (`danbooru:1` and `gelbooru:2`) with the same MD5 hash in `tagGroups` or file URL must deduplicate to one item in `FeedController`.
- When soft retry results arrive, existing post order in `current.posts` must remain unmodified.
- `ProviderBadge` must gracefully map unknown provider IDs to default styling without throwing.

---

### Task 1: Create Unit Tests for Cross-Provider Deduplication and Stable Soft Retry

**Files:**
- Create: `test/features/multi_provider_feed_ux_test.dart`

- [ ] **Step 1: Write unit tests verifying `Post.contentDedupeKey`, cross-provider deduplication in `FeedController`, and soft retry append order**
- [ ] **Step 2: Run test to verify it fails**

---

### Task 2: Implement `md5Hash` and `contentDedupeKey` in `Post`

**Files:**
- Modify: `lib/core/models/post.dart`

- [ ] **Step 1: Add `md5Hash` getter (checking `tagGroups['md5']` and regex matching on `fileUrl`/`sampleUrl`)**
- [ ] **Step 2: Add `contentDedupeKey` getter**

---

### Task 3: Update `FeedController` for Cross-Provider Deduplication and Stable Retry

**Files:**
- Modify: `lib/features/feed/presentation/feed_controller.dart`

- [ ] **Step 1: In `_loadBatch`, use `post.contentDedupeKey` for the `seen` set**
- [ ] **Step 2: In `_applySoftRetryResult`, deduplicate against `contentDedupeKey` and append `newPosts` without calling `_sortMixed` on existing items**

---

### Task 4: Enhance `ProviderBadge` with Source Brand Colors

**Files:**
- Modify: `lib/shared/widgets/post_card/post_card_badges.dart`
- Modify: `lib/shared/widgets/post_card.dart`

- [ ] **Step 1: Update `ProviderBadge` to accept `providerId` and render a source color accent dot**
- [ ] **Step 2: Update `PostCard` to pass `post.providerId` to `ProviderBadge`**

---

### Task 5: Verification and Commit

**Files:**
- Full test suite & static analysis

- [ ] **Step 1: Run `test/features/multi_provider_feed_ux_test.dart` to verify it passes**
- [ ] **Step 2: Run `dart analyze` to verify zero issues**
- [ ] **Step 3: Run full `flutter test`**
- [ ] **Step 4: Commit changes**
