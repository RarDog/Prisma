# Design: Multi-Provider Content Deduplication, Card Branding & Feed Stability

## 1. Intent & Context
Prisma allows users to search across multiple booru providers concurrently (e.g., Danbooru, Gelbooru, Rule34, e621). However, several issues degrade the multi-provider browsing experience:
1. **Duplicate Artworks**: Popular artworks are uploaded to multiple boorus simultaneously. Currently, deduplication only evaluates `post.cacheKey` (`'$providerId:$id'`). Consequently, the exact same illustration appears multiple times in the feed with different provider IDs.
2. **Homogeneous Provider Badges**: The `ProviderBadge` on post cards is a generic monochromatic black box with white text. It provides no quick visual distinction between sources, making it hard to identify where an image originates at a glance.
3. **Scroll Jitter on Soft Retry**: When a slow or transiently failing provider completes a soft search retry in the background, `FeedController._applySoftRetryResult` re-shuffles the *entire* feed (`_sortMixed(combined)`). This rearranges cards that the user has already seen or is currently viewing.

The goal of this change is to eliminate cross-provider duplicate posts via MD5 content signatures, visually distinguish provider origins with tasteful brand accent badges, and keep the feed scroll position stable when background retries arrive.

---

## 2. Goals & Non-Goals

### Goals
* **Cross-Provider Deduplication**: Deduplicate posts by their MD5 image hash (found in `tagGroups['md5']` or extracted as 32-character hex from the media URL filename) in `FeedController._loadBatch`. Fall back to `post.cacheKey` when no hash is present.
* **Branded Provider Badges**: Enhance `ProviderBadge` to include a subtle colored indicator dot and border tint matching each provider's recognizable palette (Danbooru orange, Gelbooru blue, Rule34 green, e621 indigo, Pixiv blue, etc.).
* **Stable Soft Retry Integration**: When `ProviderSoftRetryResult` delivers delayed posts, deduplicate and append them to the existing list without re-sorting the user's active viewport.

### Non-Goals
* Deep perceptual image hashing or computer vision matching for re-cropped or resized images.
* Overriding user-configured badge visibility (`AppSettings.showPostBadges`).

---

## 3. Approaches Considered

1. **Approach A: Full Multi-Provider UX (Selected)**
   * *Description*: Implement `Post.contentDedupeKey` (MD5/URL signature fallback), enhance `ProviderBadge` with brand accents, and make soft retry appends stable.
   * *Trade-off*: Delivers a cohesive, high-quality multi-source browsing experience without altering database schemas or network contracts.
2. **Approach B: Deduplication Only**
   * *Description*: Add MD5 deduplication without touching `ProviderBadge` styling or retry ordering.
   * *Trade-off*: Leaves UI badges generic and leaves the jarring list-reshuffle bug on soft retries.

---

## 4. Implementation Details

### 1. `lib/core/models/post.dart`
Add helper getters on `Post`:
* `String? get md5Hash`: Checks `tagGroups['md5']?.firstOrNull`, or extracts a 32-character hex substring from `fileUrl` / `sampleUrl`.
* `String get contentDedupeKey`: Returns `'md5:$md5Hash'` if present, else `cacheKey`.

### 2. `lib/features/feed/presentation/feed_controller.dart`
* In `_loadBatch`:
  * Initialize `seen` with `existingKeys` mapped via `contentDedupeKey`.
  * Deduplicate incoming items using `post.contentDedupeKey`.
* In `_applySoftRetryResult`:
  * Deduplicate `result.posts` against existing posts' `contentDedupeKey`.
  * Append new posts stably (`[...current.posts, ...newPosts]`) rather than calling `_sortMixed` on the entire combined list.

### 3. `lib/shared/widgets/post_card/post_card_badges.dart` & `post_card.dart`
* Update `ProviderBadge`:
  * Add `providerId` parameter.
  * Define `_providerColor(String providerId, ColorScheme scheme)` mapping provider IDs to brand colors (Danbooru: `#E45F34`, Gelbooru: `#006FFA`, Rule34: `#AAE5A4`, e621: `#223C68`, Pixiv: `#0096FA`, etc.).
  * Display a small 6px glowing accent dot alongside the provider name.
* Update `PostCard` to pass `post.providerId` to `ProviderBadge`.

---

## 5. Verification Plan
* **Unit Tests**:
  * Verify `Post.contentDedupeKey` correctly extracts MD5 from `tagGroups` and from file URLs.
  * Verify `FeedController` deduplicates two posts from different providers that share the same MD5 hash.
  * Verify `ProviderBadge` renders the correct brand colors.
  * Verify `_applySoftRetryResult` appends posts stably without reordering existing items.
* **Static Analysis**: Clean `dart analyze`.
* **Automated Tests**: Clean `flutter test`.
