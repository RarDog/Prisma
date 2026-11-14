<p align="center">
  <a href="https://github.com/RarDog/Prisma">
    <img src="assets/icon/app_icon_rounded.png" width="128" height="128" alt="Логотип Prisma" />
  </a>
</p>

<h1 align="center">Prisma</h1>

<p align="center">
  <strong>Кроссплатформенный клиент для booru-имиджбордов, манги и архивов авторов.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> • <strong>Русский</strong>
</p>

<p align="center">
  <a href="https://github.com/RarDog/Prisma/releases/latest"><img src="https://img.shields.io/github/v/release/RarDog/Prisma?style=flat-square&color=8A2BE2&label=Последний%20релиз" alt="Последний релиз" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Платформы-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-00C853?style=flat-square" alt="Платформы" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="Лицензия" /></a>
  <a href="https://github.com/RarDog/Prisma/issues"><img src="https://img.shields.io/github/issues/RarDog/Prisma?style=flat-square&color=orange" alt="Issues" /></a>
  <a href="https://github.com/RarDog/Prisma/discussions"><img src="https://img.shields.io/github/discussions/RarDog/Prisma?style=flat-square&color=blueviolet" alt="Обсуждения" /></a>
</p>

---

## Возможности

* **15+ источников в одном месте**: Booru-борды, архивы авторов (Pixiv, Pawchive), каталоги манги и новелл (MangaDex, MangaLib, RanobeLib), обои (Wallhaven).
* **Медиаплеер и просмотрщик**: Аппаратное воспроизведение видео (WebM / MP4 через MPV), Pixiv Ugoira, GIF-анимации, глубокий зум и отображение заметок с переводом (Danbooru notes).
* **Читалка манги и новелл**: Режимы Webtoon (вертикальный свиток), постраничный (справа налево / слева направо), настройка полей и типографики для текста ранобэ.
* **Поиск и фильтрация**: Автодополнение тегов, операторы поиска (`-tag`, `and`), фильтры рейтинга (Safe / NSFW) и настраиваемый чёрный список.
* **Офлайн и коллекции**: Менеджер загрузок, локальные коллекции (Boards), история просмотров и избранное.
* **Адаптивный UI Material 3**: Удобный интерфейс для телефонов, планшетов и ПК (нижняя панель на мобильных, закрепляемый сайдбар на десктопе, AMOLED-тема, горячие клавиши).

---

## Поддерживаемые источники

| Источник | Категория | Тип интеграции | Видео | Теги и автокомплит | Комментарии | Фильтры периодов |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **Danbooru** | Booru | Native REST JSON | ✅ | ✅ | ✅ | ✅ |
| **Gelbooru** | Booru | DAPI JSON | ✅ | ✅ | ❌ | ✅ |
| **The Big ImageBoard (TBIB)** | Booru | DAPI JSON | ✅ | ✅ | ❌ | ✅ |
| **Konachan** | Booru | Moebooru API | ❌ | ✅ | ✅ | ✅ |
| **Yande.re** | Booru | Moebooru API | ❌ | ✅ | ✅ | ✅ |
| **e621 / e926** | Furry / Booru | Native REST JSON | ✅ | ✅ | ✅ | ✅ |
| **Pixiv** | Арт и сеты | Session Auth / REST | ❌ | ✅ | ✅ | ✅ |
| **Wallhaven** | Обои 4K/8K | REST API | ❌ | ✅ | ❌ | ✅ |
| **Rule34 (.xxx)** | Booru | Gelbooru API | ✅ | ✅ | ❌ | ✅ |
| **Rule34.us** | Booru | HTML Скрапер | ✅ | ✅ | ❌ | ✅ |
| **Rule34 Paheal** | Booru | HTML Скрапер | ✅ | ✅ | ❌ | ❌ |
| **Realbooru** | Booru | HTML Скрапер | ✅ | ✅ | ❌ | ❌ |
| **Safebooru** | Booru (SFW) | Gelbooru API | ❌ | ✅ | ❌ | ✅ |
| **XVideos** | Видео-туб | HTML Скрапер | ✅ | ✅ | ❌ | ✅ |
| **Pawchive** | Архивы авторов | Прямая синхронизация / REST | ✅ | ✅ | ❌ | ❌ |
| **MangaDex** | Манга | REST API | — | ✅ | ❌ | Мультиязычный |
| **MangaLib** | Манга | Web API | — | ✅ | ❌ | Тома / Главы |
| **RanobeLib** | Ранобэ | Web API | — | ✅ | ❌ | Главы |

---

## Загрузка

Готовые сборки размещены на странице **[Releases](https://github.com/RarDog/Prisma/releases)**.

### Стабильный канал (`v4.2.3`)

#### Android
| Пакет | Архитектура | Целевые устройства |
| :--- | :--- | :--- |
| **[Prisma-4.2.3-arm64-v8a.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-4.2.3-arm64-v8a.apk)** | 64-битный ARM (`arm64-v8a`) | Большинство современных смартфонов и планшетов (Android 7.0+, Рекомендуется) |
| **[Prisma-4.2.3-armeabi-v7a.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-4.2.3-armeabi-v7a.apk)** | 32-битный ARM (`armeabi-v7a`) | Старые или ультрабюджетные устройства |
| **[Prisma-4.2.3-x86_64.apk](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-4.2.3-x86_64.apk)** | 64-битный x86 (`x86_64`) | Эмуляторы Android, ChromeOS и x86-планшеты |

#### Десктоп (Linux, Windows, macOS)
| Платформа | Пакет | Архитектура / Формат |
| :--- | :--- | :--- |
| **Linux** | **[Prisma-v4.2.3-linux-x86_64.AppImage](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-v4.2.3-linux-x86_64.AppImage)** | Портативный AppImage (требуется `libmpv`) |
| **Linux** | **[Prisma-v4.2.3-linux-x64.tar.gz](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-v4.2.3-linux-x64.tar.gz)** | Архив с бинарными файлами |
| **Windows** | **[Prisma-v4.2.3-windows-x64.zip](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-v4.2.3-windows-x64.zip)** | Портативный 64-битный ZIP-архив |
| **macOS** | **[Prisma-v4.2.3-macos.zip](https://github.com/RarDog/Prisma/releases/download/v4.2.3/Prisma-v4.2.3-macos.zip)** | Автономное приложение macOS (`Prisma.app`) |

---

## Стек технологий

* **Фреймворк**: [Flutter](https://flutter.dev) (Dart 3.3+)
* **Управление состоянием**: [Riverpod 2.6](https://riverpod.dev)
* **Локальная база данных**: [Isar](https://isar.dev)
* **Видеоплеер**: [media_kit](https://github.com/media-kit/media-kit) (libmpv)
* **Сетевой стек**: [Dio](https://pub.dev/packages/dio)

---

## Сборка из исходников

### Требования
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
* [Dart SDK](https://dart.dev/get-dart)
* JDK 17 и Android Command Line Tools (для сборки под Android)
* Зависимости для Linux:
  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev liblzma-dev
  ```

### Команды сборки
```bash
# 1. Клонирование репозитория
git clone https://github.com/RarDog/Prisma.git
cd Prisma

# 2. Установка зависимостей
flutter pub get

# 3. Запуск в режиме отладки
flutter run

# 4. Сборка Android split APKs
flutter build apk --release --split-per-abi

# 5. Сборка релиза под Linux
flutter build linux --release
```

---

## Лицензия

Prisma распространяется под лицензией [MIT](LICENSE).
