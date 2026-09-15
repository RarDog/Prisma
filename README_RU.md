<p align="center">
  <a href="README.md">English</a> • <strong>Русский</strong>
</p>

<p align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" height="96" alt="Prisma Logo" />
</p>

# Prisma

Быстрый, удобный и современный клиент для Booru-имиджборд и архивов авторов (Pawchive).

<p align="center">
  <a href="https://github.com/RarDog/Prisma/releases"><img src="https://img.shields.io/github/v/release/RarDog/Prisma?style=flat-square&color=8A2BE2" alt="Релизы" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.47+-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Платформы-Android%20%7C%20Linux%20%7C%20Windows-00C853?style=flat-square" alt="Платформы" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="Лицензия" />
</p>

---

## ✨ Возможности

- **📱 Удобная лента**: Masonry-сетка в стиле Pinterest, плитка 1:1 или компактный список.
- **🎬 Умный медиаплеер**: Автоповорот на весь экран, жесты управления и плавное воспроизведение видео.
- **🔍 Быстрый поиск**: Моментальные подсказки тегов (0 мс), оператор `and` и фильтры по рейтингу.
- **🐾 Синхронизация с Pawchive**: Двусторонний обмен избранным с авторами Patreon, Fanbox, Fantia, Boosty и др.
- **💾 Офлайн и загрузки**: Сохранение медиа с гибкими шаблонами папок (`{Artist}/{ID}`).
- **🛡️ Фильтрация контента**: Черный и белый списки по тегам, Safe Mode.
- **🌑 AMOLED-тема**: Настоящий глубокий черный цвет для экономии батареи на OLED-экранах.
- **🔄 Автообновление**: Встроенный апдейтер, который скачивает сборку точно под процессор вашего устройства.

---

## 🌐 Поддерживаемые источники

| Источник | Контент |
|---|---|
| **Gelbooru** | Аниме-арты, теги, авторы |
| **Rule34** | Booru-контент, видео WebM / MP4, GIF |
| **e621 / e926** | Фурри- и антро-арт с богатой системой тегов |
| **Realbooru** | Фотосессии, косплей и реалистичный арт |
| **Pawchive** | Архивы авторов (Patreon, Fanbox, Fantia, Boosty, Gumroad, Discord) |

---

## 📥 Скачать

Готовые сборки доступны на странице **[Releases](https://github.com/RarDog/Prisma/releases)**:

- **Android**:
  - `app-arm64-v8a-release.apk` — для большинства современных смартфонов (64-bit).
  - `app-armeabi-v7a-release.apk` — для старых 32-bit устройств.
  - `app-x86_64-release.apk` — для эмуляторов и хромбуков.
- **Десктоп**:
  - Портативные сборки для Linux (`.tar.gz`) и Windows (`.zip`).

---

## 🛠️ Сборка из исходников

```bash
git clone https://github.com/RarDog/Prisma.git
cd Prisma
flutter pub get
flutter run
```

Собрать релизные APK:
```bash
flutter build apk --release --split-per-abi
```

---

## ⚠️ Vibe Coding

> [!NOTE]
> Этот проект — чистый **vibe coding** в связке с AI-ассистентом ([Antigravity / Gemini](https://deepmind.google/technologies/gemini/)). Создаётся для души и личного удобства. Пулл-реквесты и предложения всегда приветствуются!


