import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/models/post_card_badge_config.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';

class CardBadgesCustomizerSheet extends ConsumerStatefulWidget {
  const CardBadgesCustomizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const CardBadgesCustomizerSheet(),
    );
  }

  @override
  ConsumerState<CardBadgesCustomizerSheet> createState() =>
      _CardBadgesCustomizerSheetState();
}

class _CardBadgesCustomizerSheetState
    extends ConsumerState<CardBadgesCustomizerSheet> {
  late PostCardBadgeConfig _config;
  bool _isSampleFavorite = true;
  bool _initialized = false;

  final Post _samplePost = Post(
    id: 'sample_preview_card',
    providerId: 'safebooru',
    providerName: 'Safebooru',
    previewUrl: 'https://safebooru.org/samples/4000/sample_4000000.jpg',
    sampleUrl: 'https://safebooru.org/samples/4000/sample_4000000.jpg',
    fileUrl: 'https://safebooru.org/images/4000/4000000.jpg',
    tags: const ['sample', 'preview', 'customization'],
    rating: 'general',
    width: 600,
    height: 800,
    source: '',
    createdAt: DateTime.now(),
    fileType: 'video',
    score: 342,
    tagGroups: const {
      'duration_text': ['0:45'],
      'page_count': ['1'],
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      try {
        final settings =
            ref.read(appSettingsProvider).value ?? AppSettings.defaults;
        _config = settings.cardBadgeConfig;
      } catch (_) {
        _config = const PostCardBadgeConfig();
      }
      _initialized = true;
    }
  }

  void _updateConfig(PostCardBadgeConfig newConfig) {
    setState(() => _config = newConfig);
    try {
      final settings =
          ref.read(appSettingsProvider).value ?? AppSettings.defaults;
      ref.read(settingsControllerProvider.notifier).saveSettings(
            settings.copyWith(cardBadgeConfig: newConfig),
          );
    } catch (_) {}
  }

  void _resetToDefault() {
    _updateConfig(const PostCardBadgeConfig());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.dashboard_customize_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRu
                                  ? 'Подписи и бейджи карточек'
                                  : 'Card Badges & Layout',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              isRu
                                  ? 'Настройте элементы и их углы'
                                  : 'Toggle badges and corner placement',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _resetToDefault,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: Text(isRu ? 'Сбросить' : 'Reset'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 12),

            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // LIVE PREVIEW CARD
                  Center(
                    child: Container(
                      width: 200,
                      height: 270,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isDark ? 0.45 : 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PostCard(
                          post: _samplePost,
                          blurExplicit: false,
                          showBadges: true,
                          badgeConfig: _config,
                          isFavorite: _isSampleFavorite,
                          isViewed: true,
                          isDownloaded: true,
                          mediaQualityMode: MediaQualityMode.auto,
                          onOpen: () {},
                          onFavorite: () {
                            setState(
                                () => _isSampleFavorite = !_isSampleFavorite);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      isRu
                          ? 'Интерактивный предпросмотр (нажмите на сердечко)'
                          : 'Interactive live preview (try tapping the heart)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // BADGES CONFIGURATION TILES
                  _BadgeConfigTile(
                    title: isRu ? 'Источник (провайдер)' : 'Provider Source',
                    subtitle: 'Safebooru, Danbooru, Gelbooru...',
                    icon: Icons.dns_rounded,
                    accentColor: const Color(0xFF64B5F6),
                    enabled: _config.showProvider,
                    position: _config.providerPosition,
                    isRu: isRu,
                    onToggle: (val) =>
                        _updateConfig(_config.copyWith(showProvider: val)),
                    onPositionChanged: (pos) => _updateConfig(
                        _config.copyWith(providerPosition: pos)),
                  ),
                  const SizedBox(height: 10),

                  _BadgeConfigTile(
                    title: isRu
                        ? 'Тип медиа и длительность'
                        : 'Media Type & Duration',
                    subtitle: isRu
                        ? 'GIF, Видео, Длительность, Слайды'
                        : 'GIF, Video, Duration, Multi-page',
                    icon: Icons.video_library_rounded,
                    accentColor: const Color(0xFFFBBF24),
                    enabled: _config.showMediaType,
                    position: _config.mediaTypePosition,
                    isRu: isRu,
                    onToggle: (val) =>
                        _updateConfig(_config.copyWith(showMediaType: val)),
                    onPositionChanged: (pos) => _updateConfig(
                        _config.copyWith(mediaTypePosition: pos)),
                  ),
                  const SizedBox(height: 10),

                  _BadgeConfigTile(
                    title: isRu ? 'Рейтинг контента' : 'Content Rating',
                    subtitle: 'General, Sensitive, Questionable, Explicit',
                    icon: Icons.verified_user_rounded,
                    accentColor: const Color(0xFF34D399),
                    enabled: _config.showRating,
                    position: _config.ratingPosition,
                    isRu: isRu,
                    onToggle: (val) =>
                        _updateConfig(_config.copyWith(showRating: val)),
                    onPositionChanged: (pos) =>
                        _updateConfig(_config.copyWith(ratingPosition: pos)),
                  ),
                  const SizedBox(height: 10),

                  _BadgeConfigTile(
                    title: isRu
                        ? 'Статусы (просмотр и скачано)'
                        : 'View & Download Status',
                    subtitle: isRu
                        ? 'Метки «seen» и загруженных файлов'
                        : '«seen» and downloaded file badges',
                    icon: Icons.visibility_rounded,
                    accentColor: const Color(0xFFA78BFA),
                    enabled: _config.showStatus,
                    position: _config.statusPosition,
                    isRu: isRu,
                    onToggle: (val) =>
                        _updateConfig(_config.copyWith(showStatus: val)),
                    onPositionChanged: (pos) =>
                        _updateConfig(_config.copyWith(statusPosition: pos)),
                  ),
                  const SizedBox(height: 10),

                  _BadgeConfigTile(
                    title: isRu
                        ? 'Кнопка «В избранное»'
                        : 'Favorite Heart Button',
                    subtitle: isRu
                        ? 'Сердечко для быстрого добавления на карточке'
                        : 'Heart icon for quick favoriting on mobile cards',
                    icon: Icons.favorite_rounded,
                    accentColor: Colors.redAccent,
                    enabled: _config.showFavorite,
                    position: _config.favoritePosition,
                    isRu: isRu,
                    onToggle: (val) =>
                        _updateConfig(_config.copyWith(showFavorite: val)),
                    onPositionChanged: (pos) => _updateConfig(
                        _config.copyWith(favoritePosition: pos)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BadgeConfigTile extends StatelessWidget {
  const _BadgeConfigTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    required this.position,
    required this.isRu,
    required this.onToggle,
    required this.onPositionChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final String position;
  final bool isRu;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onPositionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? accentColor.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: accentColor,
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  isRu ? 'Позиция:' : 'Corner:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'topLeft',
                        icon: const Icon(Icons.north_west_rounded, size: 15),
                        label: Text(
                          isRu ? 'Вверху Сл' : 'Top L',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        tooltip:
                            isRu ? 'Вверху слева' : 'Top Left corner',
                      ),
                      ButtonSegment<String>(
                        value: 'topRight',
                        icon: const Icon(Icons.north_east_rounded, size: 15),
                        label: Text(
                          isRu ? 'Вверху Спр' : 'Top R',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        tooltip:
                            isRu ? 'Вверху справа' : 'Top Right corner',
                      ),
                      ButtonSegment<String>(
                        value: 'bottomLeft',
                        icon: const Icon(Icons.south_west_rounded, size: 15),
                        label: Text(
                          isRu ? 'Внизу Сл' : 'Bottom L',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        tooltip:
                            isRu ? 'Внизу слева' : 'Bottom Left corner',
                      ),
                      ButtonSegment<String>(
                        value: 'bottomRight',
                        icon: const Icon(Icons.south_east_rounded, size: 15),
                        label: Text(
                          isRu ? 'Внизу Спр' : 'Bottom R',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        tooltip:
                            isRu ? 'Внизу справа' : 'Bottom Right corner',
                      ),
                    ],
                    selected: {position},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        onPositionChanged(set.first);
                      }
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
