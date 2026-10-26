# Редизайн вкладки «Артисты» — герои-карточки + разбор god-файла Pawchive

## Что меняется визуально

**1. Герои-карточки авторов** (`artist_card.dart` — переработка)
- Аватар крупнее: 72px, радиус 20, с кольцом-градиентом в цвете сервиса и свечением (вместо текущих 54px).
- Имя крупнее и жирнее (w800), под ним бейджи: сервис с цветной точкой, число постов, «в избранном» — текущие `LiquidMiniBadge` сохраняются.
- «Обновлено: 12.05.2025 14:20» → относительное время («2 нед. назад» / «2w ago»), свежая дата подсвечивается акцентом.
- Звезда избранного уходит в правый верхний угол карточки (позиционируется стеком), шеврон справа остаётся как аффорданс навигации.
- Фон карточки получает лёгкую градиентную заливку в цвете сервиса поверх текущего `ArtistsLiquidCard` (он остаётся основой).
- Высота ряда сетки: 116/124 → ~140/148.
- `ArtistCard` и `FavoriteArtistCard` дублируют ~70% разметки — выделяется общий приватный виджет-строку с параметром режима (обычный/избранный). Скелетон тоже обновляется под новую геометрию.

**2. Хедер** (`artists_header.dart`, 571 строка) — разбор на 3 виджета без смены поведения:
- `artists_tab_toggle.dart` — переключатель Каталог/Любимые (визуально чуть выше, 42px).
- `artists_search_field.dart` — стеклянная строка поиска.
- `artists_filter_bar.dart` — чипы провайдеров/платформ; три почти одинаковых AnimatedContainer-чипа дедуплицируются в один `_GlassChip`.
- `ArtistsHeader` остаётся тонким компоновщиком из трёх виджетов.

**3. Экран-оркестратор** (`artists_screen.dart`, 609 строк → ~300)
- Сетки каталога и избранного (два почти одинаковых блока LayoutBuilder+GridView) выносятся в `widgets/artists_catalog_view.dart` и `widgets/artists_favorites_view.dart` — по образцу свежих декомпозиций favorites/manga (view = один виджет на таб, состояние через параметры/колбэки).
- Пустое состояние избранного (80 строк инлайном) → `widgets/artists_favorites_empty.dart`.
- Фикс поведения: ошибка пагинации при уже загруженном контенте больше не заменяет всю сетку на ErrorView — показывается SnackBar, контент остаётся.
- Скролл-скрытие хедера работает и на избранном (контроллер передаётся в обе сетки).

**4. Pawchive-шит** (`pawchive_accounts_sheet.dart`, 1092 строки → 4 файла в `widgets/pawchive/`)
- `pawchive_accounts_sheet.dart` — оркестратор с состоянием и логикой входа/синхронизации; публичный API `PawchiveAccountsSheet.show()` не меняется (экспорт из artists_screen сохраняется).
- `pawchive_account_card.dart` — карточка аккаунта (~170 строк).
- `pawchive_bidirectional_sync_panel.dart` — панель двусторонней синхронизации.
- `pawchive_add_account_card.dart` — таб-форма входа; два login-обработчика (~90% дубликата) дедуплицируются в один общий путь.

Локализация — в стиле фичи (isRu-тернарники), RU/EN для всего нового текста.

## Что НЕ меняется
- Экран автора (`artist_posts_screen.dart`), провайдеры, модели, хранение избранного, навигация и роуты — не трогаем.
- Состояние остаётся в setState-оркестраторе (как в favorites/manga — Riverpod-нотифаер не вводим).

## Файлы
Изменяемые: `artists_screen.dart`, `artist_card.dart`, `artists_header.dart`
Новые: `widgets/artists_tab_toggle.dart`, `widgets/artists_search_field.dart`, `widgets/artists_filter_bar.dart`, `widgets/artists_catalog_view.dart`, `widgets/artists_favorites_view.dart`, `widgets/artists_favorites_empty.dart`, `widgets/pawchive/pawchive_accounts_sheet.dart` (переехал), `widgets/pawchive/pawchive_account_card.dart`, `widgets/pawchive/pawchive_bidirectional_sync_panel.dart`, `widgets/pawchive/pawchive_add_account_card.dart`
Старый `pawchive_accounts_sheet.dart` удаляется (контент переносится в `widgets/pawchive/`).

## Проверка
`dart analyze` (ноль замечаний) → `flutter test` → сплит-APK как в прошлых батчах. Коммит после успеха (по образцу предыдущих, отдельным коммитом `refactor(artists): ...`).