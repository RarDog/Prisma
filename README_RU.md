<p align="center">
  <a href="https://github.com/RarDog/Prisma">
    <img src="assets/icon/app_icon_rounded.png" width="128" height="128" alt="Логотип Prisma" />
  </a>
</p>

<h1 align="center">Prisma</h1>

<p align="center">
  <strong>Высокопроизводительный кроссплатформенный клиент для Booru-имиджборд, архивов авторов, манги и ранобэ.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> • <strong>Русский</strong>
</p>

<p align="center">
  <a href="https://github.com/RarDog/Prisma/releases"><img src="https://img.shields.io/github/v/release/RarDog/Prisma?style=flat-square&color=8A2BE2" alt="Релизы" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Платформы-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-00C853?style=flat-square" alt="Платформы" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="Лицензия" />
</p>

<p align="center">
  <img src="assets/preview.png" width="900" alt="Превью Prisma" />
</p>

---

## О проекте

Prisma — оптимизированное мультимедийное приложение на Flutter, объединяющее популярные имиджборды, архивы авторов, каталоги манги и библиотеки ранобэ в едином интерфейсе Material 3. Поддерживает Android, Linux, Windows и macOS.

---

## Ключевые возможности

### Лента и просмотр медиа
- **Адаптивные сетки**: Masonry-раскладка (в стиле Pinterest), фиксированная квадратная плитка 1:1 и компактный список.
- **Аппаратный медиаплеер**: Воспроизведение видео высокой четкости на базе движка `media_kit` (mpv) с жестами перемотки, регулировкой звука и автозацикливанием.
- **Детализированный просмотр**: Поддержка pinch-to-zoom, наложения текстовых заметок с переводом и многостраничных каруселей.

### Раздел «Манга и Ранобэ»
- **Интегрированные каталоги**: Прямой доступ к произведениям с **MangaDex**, **MangaLib** и **RanobeLib**.
- **Гибкие режимы чтения**:
  - **Вебтун**: Плавная вертикальная лента с аппаратным ускорением рендеринга страниц.
  - **Постраничный режим манги**: Классическое чтение справа налево (RTL) или слева направо (LTR).
  - **Читалка ранобэ**: Текстовый движок с настройкой шрифтов, межстрочного интервала и цветовых тем оформления.
- **Управление личной библиотекой**: Категоризация тайтлов («Читаю», «В планах», «Прочитано», «Отложено», «Брошено»), автосохранение прогресса глав и загрузка для чтения без сети.

### Поиск и система тегов
- **Моментальный автокомплит тегов**: Подсказки из базы миллионов тегов с нулевой задержкой.
- **Сложный синтаксис запросов**: Поддержка нескольких тегов, исключение (`-tag`), оператор `and`, фильтрация по возрастному рейтингу и смена источника без сброса фильтров.
- **Каталог авторов**: Просмотр портфолио художников и синхронизация с платформами авторов.

### Архитектура оптимизации памяти
- **Скользящее окно в карусели**: В дереве виджетов удерживаются только текущая страница и соседние ($\pm 1$), а удаленные страницы принудительно выгружаются (`evict`), исключая утечки и раздувание ОЗУ.
- **Умный сборщик мусора (Smart Memory GC) и Watchdog**: Автоматическая реакция на системные уведомления о нехватке памяти и фоновый контроль безопасных порогов использования ОЗУ.
- **Мониторинг ресурсов и плавающий HUD**: Диагностический блок в реальном времени (RAM RSS, Peak, объем кэша картинок, загрузка ЦП, скорость сети и FPS движка).

### Офлайн и безопасность
- **Менеджер загрузок**: Сохранение медиа по настраиваемым шаблонам папок (например, `{Artist}/{ID}`).
- **Синхронизация закладок**: Локальные коллекции, избранные посты и двусторонний обмен с Pawchive.
- **Гибкая фильтрация контента**: Черные и белые списки тегов, Safe Mode и настраиваемое размытие деликатного контента.

---

## Поддерживаемые источники

### Booru-имиджборды и арт-платформы
| Источник | Протокол / API |
| :--- | :--- |
| **Gelbooru** | XML / JSON API |
| **Rule34** | Gelbooru-based API |
| **Safebooru** | Gelbooru-based API |
| **Realbooru** | HTML / Scraper |
| **e621 / e926** | Native REST API |
| **Pixiv** | Session Auth |
| **Pawchive** | Creator Sync |

### Манга и Ранобэ
| Источник | Тип контента | Особенности |
| :--- | :--- | :--- |
| **MangaDex** | Манга | Международные переводы, поддержка множества языков |
| **MangaLib** | Манга | Обширный каталог с томами и главами |
| **RanobeLib** | Ранобэ / Новеллы | Форматированный текст с адаптивной версткой |

---

## Загрузка

Готовые релизные сборки доступны на странице **[Releases](https://github.com/RarDog/Prisma/releases)**:

### Android
- **[Prisma-4.1.5-arm64-v8a.apk](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-4.1.5-arm64-v8a.apk)** — Для современных 64-битных смартфонов и планшетов.
- **[Prisma-4.1.5-armeabi-v7a.apk](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-4.1.5-armeabi-v7a.apk)** — Для старых 32-битных устройств.
- **[Prisma-4.1.5-x86_64.apk](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-4.1.5-x86_64.apk)** — Для эмуляторов, хромбуков и x86-планшетов.

### Linux
- **[Prisma-v4.1.5-linux-x86_64.AppImage](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-v4.1.5-linux-x86_64.AppImage)** — Портативный исполняемый файл AppImage.
- **[Prisma-v4.1.5-linux-x64.tar.gz](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-v4.1.5-linux-x64.tar.gz)** — Портативный архив с бинарными файлами.

### Windows и macOS
- **[Prisma-v4.1.5-windows-x64.zip](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-v4.1.5-windows-x64.zip)** — Портативный архив для Windows (x64).
- **[Prisma-v4.1.5-macos.zip](https://github.com/RarDog/Prisma/releases/download/v4.1.5/Prisma-v4.1.5-macos.zip)** — Автономное приложение macOS (`Prisma.app`).

---

## Сборка из исходников

### Требования
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24 или новее)
- [Dart SDK](https://dart.dev/get-dart)
- Системные зависимости:
  - **Android**: Android Studio / Command Line Tools, JDK 17
  - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `libmpv-dev`
  - **Windows**: Visual Studio 2022 с инструментами C++ Desktop
  - **macOS**: Xcode 15+

### Команды сборки
```bash
# Клонирование репозитория
git clone https://github.com/RarDog/Prisma.git
cd Prisma

# Загрузка зависимостей
flutter pub get

# Запуск в режиме отладки
flutter run

# Сборка релизных Split APK для Android
flutter build apk --release --split-per-abi

# Сборка релизной версии для Linux
flutter build linux --release
```

---

## Лицензия

Проект распространяется под лицензией [MIT License](LICENSE).
