<p align="center">
  <a href="https://github.com/RarDog/Prisma">
    <img src="assets/icon/app_icon_rounded.png" width="128" height="128" alt="Prisma Logo" />
  </a>
</p>

<h1 align="center">Prisma</h1>

<p align="center">
  <strong>Cross-platform client for booru imageboards, manga, and creator archives.</strong>
</p>

<p align="center">
  <strong>English</strong> • <a href="README_RU.md">Русский</a>
</p>

<p align="center">
  <a href="https://github.com/RarDog/Prisma/releases/latest"><img src="https://img.shields.io/github/v/release/RarDog/Prisma?style=flat-square&color=8A2BE2&label=Latest%20Release" alt="Latest Release" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-00C853?style=flat-square" alt="Platforms" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" /></a>
  <a href="https://github.com/RarDog/Prisma/issues"><img src="https://img.shields.io/github/issues/RarDog/Prisma?style=flat-square&color=orange" alt="Issues" /></a>
  <a href="https://github.com/RarDog/Prisma/discussions"><img src="https://img.shields.io/github/discussions/RarDog/Prisma?style=flat-square&color=blueviolet" alt="Discussions" /></a>
</p>

---

## Features

* **15+ sources in one app**: Imageboards, creator platforms (Pixiv, Pawchive), manga & novel catalogs (MangaDex, MangaLib, RanobeLib), and wallpapers (Wallhaven).
* **Media player & high-resolution viewer**: Hardware-accelerated video (WebM / MP4 via MPV), Pixiv Ugoira playback, GIFs, multi-touch zoom, and Danbooru-style translation notes.
* **Manga & novel reader**: Continuous Webtoon scroll, traditional Right-to-Left (RTL) / Left-to-Right (LTR) page layouts, custom margins, and customizable typography for light novels.
* **Search & filters**: Tag autocomplete, query operators (`-tag`, `and`), rating filters (Safe / NSFW), and custom blacklist rules.
* **Offline & collections**: Download manager, local user collections (Boards), viewing history, and synchronized favorites.
* **Adaptive Material 3 UI**: Responsive navigation (bottom bar on mobile, pinnable sidebar/rail on desktop), AMOLED black theme, and desktop keyboard shortcuts.

---

## Supported Sources

| Source | Category | Integration Type | Video | Tags & Autocomplete | Comments | Period Filters |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **Danbooru** | Booru | Native REST JSON | ✅ | ✅ | ✅ | ✅ |
| **Gelbooru** | Booru | DAPI JSON | ✅ | ✅ | ❌ | ✅ |
| **The Big ImageBoard (TBIB)** | Booru | DAPI JSON | ✅ | ✅ | ❌ | ✅ |
| **Konachan** | Booru | Moebooru API | ❌ | ✅ | ✅ | ✅ |
| **Yande.re** | Booru | Moebooru API | ❌ | ✅ | ✅ | ✅ |
| **e621 / e926** | Furry / Booru | Native REST JSON | ✅ | ✅ | ✅ | ✅ |
| **Pixiv** | Art & Sets | Session Auth / REST | ❌ | ✅ | ✅ | ✅ |
| **Wallhaven** | 4K/8K Wallpapers | REST API | ❌ | ✅ | ❌ | ✅ |
| **Rule34 (.xxx)** | Booru | Gelbooru API | ✅ | ✅ | ❌ | ✅ |
| **Rule34.us** | Booru | HTML Scraper | ✅ | ✅ | ❌ | ✅ |
| **Rule34 Paheal** | Booru | HTML Scraper | ✅ | ✅ | ❌ | ❌ |
| **Realbooru** | Booru | HTML Scraper | ✅ | ✅ | ❌ | ❌ |
| **Safebooru** | Booru (SFW) | Gelbooru API | ❌ | ✅ | ❌ | ✅ |
| **XVideos** | Video Tube | HTML Scraper | ✅ | ✅ | ❌ | ✅ |
| **Pawchive** | Creator Archives | Direct Sync / REST | ✅ | ✅ | ❌ | ❌ |
| **MangaDex** | Manga | REST API | — | ✅ | ❌ | Multi-Lang |
| **MangaLib** | Manga | Web API | — | ✅ | ❌ | Volumes |
| **RanobeLib** | Light Novels | Web API | — | ✅ | ❌ | Chapters |

---

## Download

Pre-compiled binaries are available on the **[Releases](https://github.com/RarDog/Prisma/releases)** page.

### Stable Channel (`v4.2.2`)

#### Android
| Package | Architecture | Target Devices |
| :--- | :--- | :--- |
| **[Prisma-4.2.2-arm64-v8a.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-4.2.2-arm64-v8a.apk)** | 64-bit ARM (`arm64-v8a`) | Modern smartphones and tablets (Android 7.0+, Recommended) |
| **[Prisma-4.2.2-armeabi-v7a.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-4.2.2-armeabi-v7a.apk)** | 32-bit ARM (`armeabi-v7a`) | Legacy or budget 32-bit devices |
| **[Prisma-4.2.2-x86_64.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-4.2.2-x86_64.apk)** | 64-bit x86 (`x86_64`) | Android emulators, ChromeOS, and x86 devices |

#### Desktop (Linux, Windows, macOS)
| Platform | Package | Architecture / Format |
| :--- | :--- | :--- |
| **Linux** | **[Prisma-v4.2.2-linux-x86_64.AppImage](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-v4.2.2-linux-x86_64.AppImage)** | Standalone AppImage (requires `libmpv`) |
| **Linux** | **[Prisma-v4.2.2-linux-x64.tar.gz](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-v4.2.2-linux-x64.tar.gz)** | Portable Tarball Archive |
| **Windows** | **[Prisma-v4.2.2-windows-x64.zip](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-v4.2.2-windows-x64.zip)** | Portable 64-bit ZIP Archive |
| **macOS** | **[Prisma-v4.2.2-macos.zip](https://github.com/RarDog/Prisma/releases/download/v4.2.2/Prisma-v4.2.2-macos.zip)** | Standalone macOS App Bundle (`Prisma.app`) |

---

## Tech Stack

* **Framework**: [Flutter](https://flutter.dev) (Dart 3.3+)
* **State Management**: [Riverpod 2.6](https://riverpod.dev)
* **Local Database**: [Isar](https://isar.dev)
* **Video Engine**: [media_kit](https://github.com/media-kit/media-kit) (libmpv)
* **Networking**: [Dio](https://pub.dev/packages/dio)

---

## Building from Source

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
* [Dart SDK](https://dart.dev/get-dart)
* JDK 17 & Android Command Line Tools (for Android)
* Linux dependencies:
  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev liblzma-dev
  ```

### Build Commands
```bash
# 1. Clone repository
git clone https://github.com/RarDog/Prisma.git
cd Prisma

# 2. Get packages
flutter pub get

# 3. Run in debug mode
flutter run

# 4. Build Android split APKs
flutter build apk --release --split-per-abi

# 5. Build Linux release
flutter build linux --release
```

---

## License

Prisma is licensed under the [MIT License](LICENSE).
