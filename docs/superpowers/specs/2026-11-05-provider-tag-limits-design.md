# Design: Provider Search Tag Limits & 422 Graceful Degradation

## 1. Intent & Context
Booru APIs have diverse search capabilities and constraints. In particular, Danbooru restricts unauthenticated and basic tier accounts to a maximum of **2 tags** per search query (`{"success":false,"message":"You cannot search for more than 2 tags at a time."}`). In Danbooru's search syntax, directives such as `rating:general` and `order:rank` count against this 2-tag quota.

Currently, if a user queries Danbooru with 3 or more tags (or 2 tags plus a rating filter):
1. Danbooru rejects the request with HTTP 422 (Unprocessable Entity).
2. `ProviderManager` interprets HTTP 422 as a fatal server failure and marks Danbooru as `ProviderStatus.offline`, surfacing an alarming offline banner to the user.
3. Zero posts are returned from Danbooru, breaking multi-tag searches on this provider.

The goal of this change is to enable providers to declare their maximum search tag limits via a dedicated capability interface, safely trim queries to the upstream limit, rely on client-side tag filtering (`postMatchesRequestedTags`) to guarantee accuracy, and ensure HTTP 422 responses never mark an otherwise healthy provider as offline.

---

## 2. Goals & Non-Goals

### Goals
* **Capability Interface**: Add `TagLimitProvider` capability in `lib/sources/interfaces/content_provider.dart` without widening `ContentProvider` (per AGENTS.md guidelines).
* **Danbooru Tag Trimming**: Implement `TagLimitProvider` on `DanbooruProvider` (`maxSearchTags = 2`), intelligently prioritizing rating/period directives and taking user tags up to the quota.
* **Client-Side Filtering Synergy**: Rely on `FeedService.postMatchesRequestedTags` and `FeedController._loadBatch` (from Step 1) to filter raw posts for all requested tags and accumulate a full display page.
* **422 Error Handling**: Treat HTTP 422 (Unprocessable Entity) as a query validation failure rather than server downtime, preventing false `offline` health flips.
* **Graceful Fallback**: If an upstream server responds with 422 despite trimming, handle it gracefully by returning empty posts rather than crashing or interrupting sibling providers.

### Non-Goals
* Paid account tier negotiation or server-side Danbooru gold/platinum credential checks.
* Altering providers without search tag constraints (Gelbooru, Moebooru, Safebooru, etc.).

---

## 3. Approaches Considered

1. **Approach A: Local catch inside DanbooruProvider only**
   * *Description*: Ad-hoc truncation and try/catch strictly within `DanbooruProvider.dart`.
   * *Trade-off*: Leaves `ProviderManager` still vulnerable to false offline markings if other providers (or custom providers) return 422 on query issues.
2. **Approach B: `TagLimitProvider` Capability + `ProviderManager` 422 Safety (Selected)**
   * *Description*: Declare `TagLimitProvider` interface. Implement on `DanbooruProvider`. Update `ProviderManager` to avoid marking providers offline on 422 HTTP responses.
   * *Trade-off*: Clean, reusable architecture aligned with Prisma's capability pattern. Solves both root causes (excess tags sent & false offline health state).

---

## 4. Implementation Details

### 1. `lib/sources/interfaces/content_provider.dart`
Define the capability:
```dart
abstract class TagLimitProvider {
  int get maxSearchTags;
}
```

### 2. `lib/sources/booru/danbooru_provider.dart`
* Mix in `TagLimitProvider` and implement `int get maxSearchTags => 2;`.
* In `searchPosts`:
  * Construct query tags respecting `maxSearchTags`.
  * If directives (`rating:` or top tags) consume slots, reserve them and truncate user tags accordingly.
  * Wrap request in a try-catch for `DioException`: if `statusCode == 422`, log diagnostics and return `const <Post>[]` gracefully.

### 3. `lib/sources/provider_manager.dart`
* In `_searchForTagGroup`:
  * Before querying, if `provider is TagLimitProvider && cleanTags.length > provider.maxSearchTags`, truncate `cleanTags` to `provider.maxSearchTags`.
  * If an error occurs, inspect `statusCode`: if `statusCode == 422`, do NOT record `ProviderHealth(status: ProviderStatus.offline)`.

---

## 5. Verification Plan
* **Unit Tests**:
  * Verify `DanbooruProvider` sends at most 2 tags when given $\ge 3$ tags.
  * Verify `DanbooruProvider` returns empty list on HTTP 422 without throwing.
  * Verify `ProviderManager` does not mark a provider offline on HTTP 422.
* **Static Analysis**: `dart analyze` with zero issues.
* **Deterministic Tests**: `flutter test` passing cleanly.
