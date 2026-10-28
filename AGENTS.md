# Prisma — Agent & AI Model Context Guide

> Dense, high-signal architectural context and implementation rules for AI models and autonomous coding agents working on the Prisma codebase. Read this first to eliminate exploratory token overhead.
>
> Everything below reflects the code as it exists today. When you change structure, update this file in the same commit — stale paths here cost agents more than no document at all.

---

## 1. High-Level Overview

* **Application**: Prisma (`gel_rule_app`) — cross-platform multimedia client for booru imageboards, creator archives (Pixiv, Pawchive, Fapello), video tubes (XVideos), wallpaper boards (Wallhaven, Are.na) and manga / light-novel catalogs (MangaDex, MangaLib, RanobeLib).
* **Tech Stack**:
  * **Flutter** (`environment.flutter >= 3.19.0`, `sdk >= 3.3.0 < 4.0.0` in `pubspec.yaml`)
  * **State Management**: `flutter_riverpod` ^2.5.1 — `StateNotifier`, `AsyncNotifier`, functional providers
  * **Local Persistence**: `isar` ^3.1.0+1, with a vendored binary package in `third_party/isar_flutter_libs` wired through `dependency_overrides`
  * **Network**: `dio` ^5.4.3+1 with a retry interceptor and per-source headers
  * **Video Engine**: `media_kit` + `media_kit_video` (libmpv) on Linux, Android, Windows, macOS
  * **Navigation**: `go_router` ^14.2.0 (`StatefulShellRoute`, 9 branches)
  * **Media & formats**: `archive` (Pixiv Ugoira ZIP unpacking), `cached_network_image`, `shimmer`, `flutter_secure_storage`, `dynamic_color`, `flutter_markdown_plus`
* **Platforms present in the repo**: `android/`, `linux/`, `windows/`, `macos/`. There is **no** `ios/` or `web/` target — do not add web-only APIs.

---

## 2. Directory Structure & Responsibilities

```text
lib/
├── app/                        # Startup, routing, theme, localization, versioning
│   ├── app.dart                # GelRuleApp, appSettingsProvider, appStringsProvider, update check
│   ├── router.dart             # GoRouter: 9 shell branches + /post/:providerId/:postId
│   ├── app_strings.dart        # Bilingual (RU/EN) string table, no ARB
│   ├── app_version.dart        # appDisplayVersion / appBuildNumber / appReleaseChannel
│   ├── changelog.dart          # prismaChangelog: PrismaChange entries (RU + EN)
│   ├── theme.dart              # Material 3, AMOLED, seed color, dynamic color
│   ├── motion.dart             # Motion/refresh-rate helpers
│   ├── responsive.dart         # Breakpoints
│   └── app_navigator.dart
├── backend/                    # DI wiring only — there are NO repositories here
│   ├── backend.dart            # Barrel: re-exports DI + every domain layer used by UI
│   └── di/backend_providers.dart  # All Riverpod providers (DB → repos → services)
├── core/
│   ├── cache/cache_service.dart        # Post cache + eviction, pins favorites/collections/viewed
│   ├── database/app_database.dart      # Isar schema (13 collections) + app_database.g.dart (committed)
│   ├── database/database_service.dart  # Thin Isar wrapper used by repositories
│   ├── errors/app_exception.dart       # Sealed AppException family
│   ├── errors/failure.dart             # Failure (code/message/details) for Result
│   ├── http/dio_client.dart            # DioClient + _RetryInterceptor (Retry-After, 429/5xx)
│   ├── http/app_headers.dart           # AppHeaders: per-source UA / referer / basic auth
│   ├── models/                         # Post, PostComment, PostNote, TagSuggestion,
│   │                                   # ProviderHealth, ProviderDiagnostics, CloudMediaLink, TopPeriodFilter
│   ├── motion/                         # Desktop smooth scrolling binding
│   ├── performance/performance_monitor.dart  # Debug HUD metrics (FPS/RAM/network)
│   ├── security/credential_store.dart  # API keys / cookies in OS keychain, never in Isar
│   └── utils/                          # result.dart, smart_blacklist.dart, media_quality.dart,
│                                       # cloud_link_extractor.dart, logger.dart
├── features/                   # Vertical slices: <feature>/{data,domain,models,presentation}
│   ├── feed/                   # Feed controller/state/screen, PostRepository, FeedService
│   ├── post/                   # Post details, variants strip, notes, Ugoira, MPV dock, similar posts
│   ├── search/                 # Tag chips, history, autocomplete, TagCacheService
│   ├── favorites/              # Favorites + favorite artists
│   ├── collections/            # User collections ("Boards")
│   ├── viewed/                 # Viewing history (was documented as "history" — it is `viewed`)
│   ├── downloads/              # Download queue, downloaded media index, Dynamic Island UI
│   ├── artists/                # Artist hubs, Pawchive accounts/sync, e621 pools
│   ├── manga/                  # Catalog, reader (webtoon/RTL/LTR), novel reader, offline library
│   ├── providers/              # Provider CRUD, health/ping batch checks
│   ├── settings/               # Hub + 7 screens, AppSettings, backup, update service
│   └── onboarding/             # First-run wizard
├── sources/                    # Data-source abstraction layer
│   ├── interfaces/content_provider.dart  # All provider contracts (see §3A)
│   ├── booru/                  # danbooru, gelbooru, moebooru, e621, rule34, rule34_us,
│   │                           # rule34_paheal, realbooru_html, safebooru, tbib, wallhaven,
│   │                           # arena, fapello, custom_provider
│   ├── artist/                 # pixiv, pawchive
│   ├── manga/                  # mangadex, mangalib, ranobelib
│   ├── video/                  # xvideos
│   ├── mappers/                # Per-source JSON → Post mappers
│   ├── models/                 # ugoira_metadata.dart
│   ├── provider_factory.dart   # apiType → provider instance (+ memoized clients/providers)
│   └── provider_manager.dart   # Registry, fan-out search, retries, health, suggestions
└── shared/widgets/             # Reusable UI: app_shell, liquid_glass_bottom_bar, post_card(.dart),
                                # post_masonry_grid, adaptive_scaffold, tag_chip, error_view, …
    ├── post_card/              # previews, badges, inline video preview
    ├── search/                 # tag_input_search_bar, tag_suggestion_dropdown
    └── shell/                  # desktop_shell, mobile_shell, desktop_rail_widgets,
                                # shell_bottom_bar_controller, shell_shortcuts
```

**Other top-level directories**

* `test/backend/` — data layer, providers, repositories, services. `test/features/` — widgets/controllers. `test/shared/` — shared widgets. `test/sources/` — factory memoization.
* `docs/superpowers/plans/` and `docs/superpowers/specs/` — design docs written before larger features (e.g. download Dynamic Island, Pixiv Ugoira player). Add a spec + plan here for multi-step work.
* `installer/` — packaging: `build_linux_appimage.sh` (Linux AppImage) and `Prisma.iss` (Windows Inno Setup).
* `third_party/isar_flutter_libs/` — pinned Isar binaries; do not remove the `dependency_overrides` entry.

---

## 3. Key Architectural Patterns & Contracts

### A. Provider capability model (`lib/sources/`)

`ContentProvider` is intentionally small: `id`, `name`, `baseUrl`, `supportedTopPeriods`, `searchPosts(...)`, `getPost(id)`, `checkHealth()`.

Optional capabilities are **separate interfaces** that providers mix in — never widen `ContentProvider`:

| Interface | Purpose |
| :--- | :--- |
| `PostPageProvider` | `postPageUrl(post)` — canonical web page |
| `MediaHeadersProvider` | headers required to fetch media (referer, UA) |
| `CommentProvider` / `NoteProvider` | comments / Danbooru-style translation notes |
| `TagSuggestionProvider` | autocomplete (`suggestTags`) |
| `TagMetadataProvider` | `categorizeTags` → `tagGroups` |
| `ArtistProvider` | artist list/search/works/tags/links/announcements |
| `MangaChapterProvider` / `NovelChapterProvider` | chapters + page URLs / chapter text |
| `MultiPageProvider` | post sets / multi-page artworks |

Consumers must feature-test (`if (provider is! CommentProvider) return const Success([]);`) and degrade gracefully — a missing capability is never an error.

* **Error handling**: data layers return `Result<T>` (`lib/core/utils/result.dart`: `sealed class Result` with `Success` / `Error`, plus `fold`). Do not let exceptions escape a repository or provider method unless the contract says so (`searchPosts` may throw `AppException`; `ProviderManager` catches and classifies).
* **`AppException` family** (`core/errors/app_exception.dart`): `NetworkException`, `RequestTimeoutException`, `ProviderUnavailableException`, `BadResponseException`, `DatabaseException`. `ProviderManager._isRetryableError` treats timeouts / connection errors / 429 / 5xx as transient; deterministic answers (4xx, bad body, Cloudflare block) are not retried.

### B. `ProviderManager` (`lib/sources/provider_manager.dart`)

The single orchestration point. Know these behaviours before touching feeds:

* **Config cache** — 10 s TTL over `ProviderRepository.getProviders`, invalidated by CRUD; also refreshes per-provider `timeoutSeconds`.
* **Splitting** — `loadFeedConfigs` / `loadArtistConfigs` / `loadMangaConfigs` partition by `apiType`:
  * artist: `pawchive`, `fapello`
  * manga: `mangadex`, `mangalib`, `ranobelib`
  * feed: everything else
  * legacy configs (`cosbooru`, `kemono`, `coomer`) are filtered out.
* **Fan-out search** — `searchAcrossProviders` queries every enabled feed provider concurrently, each with its own `CancelToken` child and per-provider timeout (default 14 s). Results are de-duplicated by `Post.cacheKey` and interleaved with a deterministic FNV-1a hash (`_mixKey`) so paginated refreshes stay stable and no single source forms a block.
* **Tag groups** — `splitTagGroups` turns `a and b` into independent branches and propagates trailing modifiers; results are interleaved round-robin.
* **Soft retry** — transient failures schedule one retry after ~900 ms, emit `ProviderSoftRetryResult` on `softRetryResults`, and flip health back to online; the first hiccup never marks a provider offline.
* **Suggestions** — 45 s query cache, 60 s provider list cache, 1.5 s per-provider timeout, merged by highest `postCount`.

### C. `ProviderFactory` (`lib/sources/provider_factory.dart`)

* Maps `ContentProviderConfig.apiType` → concrete provider; converts `query.*` custom headers into query parameters and derives e621 Basic auth / Pixiv referer.
* **Memoizes both `DioClient` and provider instances** keyed by the same `clientKey` (cap 32 clients). Without this, instance-level caches (Pawchive artist lists, MangaDex author ids, media headers) die on every `create()` call. If you add a cache to a provider, it will survive only because of this memoization.

### D. Dependency injection (`lib/backend/di/backend_providers.dart`)

* `appDatabaseProvider` (FutureProvider) opens Isar, seeds providers, runs auto-restore and the onboarding check.
* Repositories live in `<feature>/data/`, services in `<feature>/domain/`; both are constructed here. Repositories that mutate user data take `onDataChanged: _backupScheduler(ref)` to trigger a debounced backup.
* UI imports `package:gel_rule_app/backend/backend.dart` (barrel), not individual files.
* `downloadedMediaByKeysProvider` / `_downloadedMediaChangeProvider` propagate download-state changes into the widget tree — reuse them instead of polling.

### E. Feed filtering pipeline (`lib/features/feed/domain/feed_service.dart`)

`FeedService.loadNextPage` → provider fan-out → top-period sort/filter → exact tag match (`postMatchesRequestedTags`, bypassed for `pawchive`/`fapello`/`xvideos`) → blacklist/whitelist + `SmartBlacklistMatcher` → hide-viewed → cache write. Keep the order: later stages assume earlier ones already normalized the list.

* `SmartBlacklistMatcher` supports `tag:value` rules (`rating:explicit`, `score:>100`, group lookups). It reads both `post.tags` and every `post.tagGroups` value.

### F. `Post` model and the `tagGroups` convention (`lib/core/models/post.dart`)

`Post` is deliberately flat and serializable; rich metadata lives in `Map<String, List<String>> tagGroups`. Known keys: `description`, `parent_id`, `children`, `page_count`, `pools`, `media_type`, `has_notes`, `fav_count`, `copyright`, `artist`, `title`, `type`, `rus_title`, `eng_title`, `cloud_links`, `is_detailed`, `duration`, plus source-specific extras.

* Add a new capability as a `tagGroups` key + a getter on `Post`; do **not** add fields to the Isar `CachedPostEntity` schema unless you also bump/migrate it.
* `cacheKey` = `'$providerId:$id'` — the universal identity across cache, favorites, history, downloads.

### G. Persistence (`lib/core/database/app_database.dart`)

13 Isar collections: `ProviderConfigEntity`, `ProviderHealthEntity`, `CachedPostEntity`, `FavoriteEntity`, `CollectionEntity`, `CollectionPostEntity`, `SearchHistoryEntity`, `AppSettingEntity`, `ViewedPostEntity`, `ProviderDiagnosticsEntity`, `DownloadedMediaEntity`, `MangaLibraryEntryEntity`, `MangaReadingProgressEntity`.

* `app_database.g.dart` **is committed**. After editing any `@collection`, run `dart run build_runner build --delete-conflicting-outputs`.
* `AppDatabase.open` deletes and recreates a corrupt/incompatible DB file rather than crash-looping — cached content is disposable, user data is backed up separately.
* Cache eviction (`CacheService._evictOverflow`) never deletes rows pinned by favorites, collections or viewed history.

### H. Secrets

`CredentialStore` keeps API keys, `phpsessid`, Basic-auth pairs and cookies in the OS keychain (keys listed in `CredentialStore.secretHeaderKeys`) and strips them before persisting provider configs. Never write secrets into `AppSettingEntity` or backup JSON; add new secret header names to `secretHeaderKeys`.

### I. Downloads

`DownloadManagerService` runs at most 3 concurrent transfers, exposes `Stream<List<DownloadTask>>`, supports pause/cancel/retry, and reports save errors instead of swallowing them. `DownloadedMediaService` owns the local file index and notifies through `changeNotifier`. The UI is `shared`-level `DownloadDynamicIslandOverlay` mounted in `app.dart`.

---

## 4. Navigation, Shell & Screens

* **Router** (`lib/app/router.dart`): one `StatefulShellRoute` with 9 branches in this exact order — `/` feed, `/search` tags, `/favorites`, `/viewed`, `/collections` (+`:collectionId`), `/artists` (+`:providerId/:service/:artistId`), `/manga`, `/providers` (+`new`, `check`), `/settings` (+`hidden`, `cache`). Detail routes live outside the shell: `/post/:providerId/:postId` and `/post/:providerId/:postId/similar`. `/onboarding` is chosen as `initialLocation` when onboarding has not been completed.
* **Branch order is load-bearing**: `AppShell.branchIndexForLocation`, `locationForBranchIndex`, `branchNavKeys` (9 `GlobalKey`s) and `AnimatedBranchContainer` all assume it. Adding a tab means touching router, `AppShell.destinations`, both index mappers, and `tab_visibility_editor`.
* **Post navigation** passes `PostNavigationContext` (current post + list + `fromFeed`) via `extra`; an empty list means "unknown", same as no context.
* **Shell** (`shared/widgets/app_shell.dart` + `shared/widgets/shell/`): adaptive — desktop rail (left/right, pinnable) vs mobile bottom bar (`liquid_glass_bottom_bar`). `AppSettings.hiddenTabs` hides destinations; `desktopNavPosition` / `desktopSidebarPinned` drive placement.
* **Settings** (`features/settings/presentation/`): hub (`settings_screen.dart`) + `screens/{general, appearance, feed, filters, storage, accounts, about}` + `hidden_posts_screen.dart`, `cache_manager_screen.dart`. Each screen constrains content to `BoxConstraints(maxWidth: 860)`.
* **Accounts vs Providers** — keep this division:
  * **Accounts & Sync** (`screens/accounts_settings_screen.dart`): credential-bound services — Pawchive multi-account author sync, e621/e926 username + API key, server blacklist and favorites sync.
  * **Providers** (`features/providers/`): generic booru/custom endpoints, priorities, timeouts, ping checks. e621/e926 are filtered out of this list because their controls live in Accounts.

---

## 5. Versioning & Release Channels

For any release, update all four in one commit:

1. **`pubspec.yaml`** — `version: X.Y.Z[-channel.N]+buildNumber`.
2. **`lib/app/app_version.dart`** — `appDisplayVersion` (`'4.2.1-rc.3'`), `appBuildNumber` (`126`), `appReleaseChannel` (`'Stable' | 'Beta' | 'RC'`).
3. **`lib/app/changelog.dart`** — new `PrismaChange` at the **top** of `prismaChangelog`, with Russian `title`/`bullets` and English `titleEn`/`bulletsEn`.
4. **`README.md` and `README_RU.md`** — release headings and download links (RC section *and* stable section). Both files must stay in sync; the RC block is the first place that goes stale.

Channel ordering is SemVer (`alpha < beta < rc < stable`), implemented in `features/settings/domain/update_service.dart` (`_isNewerVersion` / `_compareVersions`). Update packages are SHA-256 verified against the release checksum list before install.

---

## 6. Development & Verification Commands

```bash
# 1. Static analysis (must be clean — zero warnings/errors)
dart analyze

# 2. Deterministic test suite (live API suites are skipped by dart_test.yaml)
flutter test

# 3. Targeted runs
flutter test test/backend/                      # data layer & providers
flutter test test/features/                     # widgets & controllers
flutter test test/backend/isar_integration_test.dart

# 4. Opt-in live upstream checks (needs network; tagged `network`)
flutter test --tags network --run-skipped

# 5. Isar codegen after touching @collection classes
dart run build_runner build --delete-conflicting-outputs

# 6. Packaging
flutter build linux --release && ./installer/build_linux_appimage.sh
flutter build apk --split-per-abi
```

**Test rules**

* `dart_test.yaml` skips the `network` tag by default. Never add a live-API assertion to an untagged test — upstream churn has already turned the suite red once (`RanobeLib` catalog edits).
* Mock HTTP with `Dio()` + `InterceptorsWrapper` (`handler.resolve(Response(...))`) or a `HttpClientAdapter` fake, then wrap with `DioClient(dio: dio)`. Prefer deterministic 4xx over 5xx when you want to bypass `_RetryInterceptor` backoff.
* Widget tests must not touch a live database: override `providersControllerProvider`, `settingsControllerProvider`, `appSettingsProvider` with fakes (see `test/features/accounts_settings_screen_test.dart`).

---

## 7. Coding Conventions for Agents

* **Preserve documentation & comments** — keep existing explanations and architectural docstrings intact.
* **Bilingual UI** — every user-facing string needs RU and EN. Two patterns coexist: `AppStrings` getters (`ref.watch(appStringsProvider)`, see `lib/app/app_strings.dart`) and inline `isRu ? '…' : '…'` from `settings.languageCode == 'ru'`. Match the file you are editing.
* **Liquid Glass / Material 3** — AMOLED black (`0xFF000000`), `BackdropFilter` frosted surfaces, adaptive constraints (`maxWidth: 860` for settings screens). Respect `AppSettings` theme, seed color, dynamic color and motion preferences.
* **Safe nullability** — guard provider lookups with `.firstOrNull`/`is!` checks and default `customHeaders` to `const {}`.
* **Heavy work off the UI thread** — Ugoira ZIP extraction and long text parsing use `Isolate.run`/`compute`; keep it that way.
* **Cancellation** — forward `CancelToken` through new network calls; user cancellation must never be reported as a provider failure.
* **Comments in English**, UI copy in both languages.

---

## 8. Known Pitfalls

* Paths from older documentation are wrong: there is no `lib/backend/repositories/`, no `lib/core/result/`, no `lib/features/history/`. Repositories live in `<feature>/data/`, `Result` in `lib/core/utils/result.dart`, history in `features/viewed/`.
* `features/downloads/` has **no** `presentation/*_screen.dart` — only `presentation/widgets/` (Dynamic Island + related).
* `provider_manager.dart` (1035 lines) and `app_settings.dart` (639 lines, most of it the hand-written `copyWith` + JSON mapping) are the largest files; add focused helpers instead of growing them further.
* Adding a branch to the router without updating the index mappers silently breaks tab restoration and `lastActiveLocation`.
* e621 and e926 share `apiType: 'e621'`; anything keyed by apiType treats them as one source.
