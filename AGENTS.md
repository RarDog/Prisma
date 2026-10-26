# Prisma — Agent & AI Model Context Guide

> This document provides dense, high-signal architectural context and implementation rules for AI models and autonomous coding agents working on the Prisma codebase. Read this first to eliminate exploratory token overhead.

---

## 1. High-Level Overview

* **Application**: Prisma (`gel_rule_app`) — high-performance cross-platform multimedia client for booru imageboards, creator networks (Pixiv, Pawchive), adult video tubes (XVideos), and manga/light novel catalogs (MangaDex, MangaLib, RanobeLib).
* **Tech Stack**:
  * **Flutter** 3.24+ / **Dart** 3.3+
  * **State Management**: `flutter_riverpod` (v2.5+, `StateNotifier`, `AsyncNotifier`, functional providers)
  * **Local Persistence**: `isar` 3.1.0+ (NoSQL embedded database with custom binaries in `third_party/isar_flutter_libs`)
  * **Network**: `dio` 5.4.3+ with custom interceptors and desktop/mobile headers
  * **Video Engine**: `media_kit` + `media_kit_video` (libmpv backend across Linux, Android, Windows)
  * **Navigation**: `go_router` 14.2+
  * **Animation & Formats**: `archive` (Pixiv Ugoira zip unpacking in background isolates), `shimmer`, `cached_network_image`

---

## 2. Directory Structure & Responsibilities

```text
lib/
├── app/                  # App startup, global routes, versioning, localization, changelog
│   ├── app_version.dart  # Single source of truth for display version, build number, release channel
│   ├── app_strings.dart  # Bilingual localized strings (RU / EN)
│   └── changelog.dart    # Structured changelog history rendered in PrismaChangelogDialog
├── backend/              # Database schema & persistence repositories
│   ├── db/               # Isar database initialization, schema models (Collection, Post, Config)
│   └── repositories/     # ProviderRepository, PostRepository, FavoriteRepository, HistoryRepository
├── core/                 # Shared foundational services and network abstractions
│   ├── http/             # DioClient, AppHeaders (per-source User-Agents, referers, API basic auth)
│   ├── models/           # Domain entities: Post, TagSuggestion, ProviderHealth, TopPeriodFilter
│   └── result/           # Result<T> pattern (Success / Error) used across all data layers
├── features/             # Modular feature slices (Presentation, Domain/State, Widgets)
│   ├── feed/             # Infinite masonry/grid feed, proactive prefetching, resolution switcher
│   ├── post/             # Deep zoom/pan viewer, notes overlay, variants strip, Ugoira player, MPV dock
│   ├── search/           # Tag autocomplete, chip search bar, plain query toggle (XVideos)
│   ├── favorites/        # Offline saved posts, collections, e621 server favorites sync
│   ├── history/          # Viewed history with auto-prune
│   ├── manga/            # Reader modes (Webtoon vertical strip, RTL/LTR pages, typography engine)
│   ├── artists/          # Artist hubs, Pawchive sync, Pixiv integration
│   ├── providers/        # Provider management UI, health/ping batch tester, provider editor
│   ├── settings/         # 7 modular settings screens (General, Appearance, Feed, Filters, Storage, Accounts, About)
│   └── onboarding/       # Multi-step first-run wizard
├── sources/              # Data source abstraction layer
│   ├── interfaces/       # Base contracts: ContentProvider, PostPageProvider, MediaHeadersProvider, etc.
│   ├── booru/            # Danbooru, Gelbooru, Moebooru, e621/e926, TBIB, Rule34, Realbooru, Safebooru, XVideos
│   ├── manga/            # MangaDex, MangaLib, RanobeLib
│   ├── artist/           # Pixiv, Pawchive
│   ├── provider_manager.dart # Central provider registry, active provider caching, lifecycle
│   └── provider_factory.dart # Config-to-Provider instantiator
└── shared/               # Reusable UI widgets: TagChip, ErrorView, ConfirmDialog, Glass containers
```

---

## 3. Key Architectural Patterns & Contracts

### A. The Provider Pattern (`lib/sources/`)
* Every content source implements `ContentProvider` (`id`, `name`, `baseUrl`).
* Feature mixins define capabilities:
  * `PostPageProvider`: paginated post queries (`fetchPosts(page, tags, ...)`) returning `Result<List<Post>>`.
  * `MediaHeadersProvider`: HTTP headers required for streaming/downloading media (e.g. Pixiv referer, e621 User-Agent).
  * `TagSuggestionProvider`: autocomplete tags (`suggestTags(query)`).
  * `ArtistProvider`: artist profile indexing and author feeds.
* **Error Handling**: Data layers MUST return `Result<T>` (`Success(data)` or `Error(failure)`) rather than throwing uncaught exceptions.

### B. State Management (`Riverpod`)
* Controllers live inside `features/<feature>/presentation/` or `domain/`.
* State is usually an `AsyncValue<T>` or immutable state object with `copyWith`.
* In widget tests, avoid accessing live databases; override `providersControllerProvider`, `settingsControllerProvider`, and `appSettingsProvider` using mock/fake controllers (see `test/features/accounts_settings_screen_test.dart`).

### C. Search Bar Modes (`TagInputSearchBar`)
* The top search bar supports two modes:
  1. **Booru Tag Mode** (default): Spaces tokenize tags into interactive chips. Autocomplete suggestions append chips.
  2. **Plain Search Mode** (used for XVideos and full-text engines): Treats spaces as literal query strings without creating tag chips. Toggled via the search mode icon or automatically when switching sources.

### D. Accounts vs. Providers Division
* **Accounts & Sync Screen** (`lib/features/settings/presentation/screens/accounts_settings_screen.dart`):
  * Dedicated to services that require user credentials, synchronization, or personal accounts:
    * **Pawchive**: Multi-account author subscription sync.
    * **e621 & e926**: Username + API Key authorization, server blacklist sync, favorites sync.
* **Providers Screen** (`lib/features/providers/presentation/providers_screen.dart`):
  * Dedicated to configuring generic Booru sources, custom endpoints, timeouts, priorities, and ping latency checks.
  * Note: `e621` and `e926` are filtered out of the general Booru list on this screen to avoid duplicate settings, as their account controls are centralized in *Accounts & Sync*.

### E. Memory Optimization & Sliding-Window
* Detail view carousels use aggressive sliding-window caching ($\pm 1$ adjacent page active). Distant image surfaces and video controllers are evicted to stay within OS memory limits.
* Background tasks (e.g. Ugoira ZIP decompressions) must execute in isolates (`compute` or `Isolate.run`) to prevent UI jank.

---

## 4. Versioning & Release Channels

When updating or preparing releases:
1. **`pubspec.yaml`**: Update `version: X.Y.Z[-channel.N]+buildNumber`.
2. **`lib/app/app_version.dart`**: Synchronize:
   * `appDisplayVersion`: e.g. `'4.2.1-rc.1'`
   * `appBuildNumber`: e.g. `124`
   * `appReleaseChannel`: `'Stable'`, `'Beta'`, or `'RC'`
3. **`lib/app/changelog.dart`**: Add a new `PrismaChange` entry at the top of `prismaChangelog` with both Russian (`title`, `bullets`) and English (`titleEn`, `bulletsEn`) descriptions.
4. **`README.md` & `README_RU.md`**: Update download links and channel headings.
5. **SemVer Channel Logic**: Handled by `lib/features/settings/domain/update_service.dart`. Channels follow standard SemVer order: `alpha < beta < rc < stable`.

---

## 5. Development & Verification Commands

```bash
# 1. Static Analysis (Enforces zero warnings/errors)
dart analyze

# 2. Automated Testing
flutter test

# 3. Running Specific Feature / Backend Tests
flutter test test/features/
flutter test test/backend/isar_integration_test.dart

# 4. Packaging Linux Binary & Portable AppImage
flutter build linux --release
./installer/build_linux_appimage.sh
# Produces: build/Prisma-v<version>-linux-x86_64.AppImage

# 5. Packaging Android Split APKs
flutter build apk --split-per-abi
# Produces:
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#   build/app/outputs/flutter-apk/app-x86_64-release.apk
```

---

## 6. Coding Conventions for Agents

* **Preserve Documentation & Comments**: Keep existing comments, explanations, and architectural docstrings intact.
* **Bilingual Support**: All user-facing text must support both Russian (`isRu`) and English. Check `appStringsProvider` or locale code.
* **Liquid Glass / Material 3 Styling**: Reusable UI elements should respect AMOLED black theme (`0xFF000000`), frosted glass backdrops (`BackdropFilter` with blur), and adaptive responsive layout constraints (`MaxWidth: 860` for settings, `1060` for grids).
* **Safe Nullability**: Always guard provider lookups with `.firstOrNull` and provide defaults when accessing `customHeaders`.
