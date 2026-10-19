import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'e621_auth_dialog.dart';

class ProviderCard extends StatefulWidget {
  const ProviderCard({
    required this.config,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onSaveConfig,
    super.key,
  });

  final ContentProviderConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ContentProviderConfig>? onSaveConfig;

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
            scheme.surface == const Color(0xFF000000));
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final config = widget.config;
    final (engineColor, engineIcon, engineTitle) = _engineInfo(config.apiType);

    final cleanHost = () {
      try {
        final uri = Uri.parse(config.baseUrl);
        return uri.host.isNotEmpty ? uri.host : config.baseUrl;
      } catch (_) {
        return config.baseUrl;
      }
    }();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAmoled
                ? [
                    const Color(0xFF141414)
                        .withValues(alpha: config.enabled ? 0.88 : 0.45),
                    const Color(0xFF070707)
                        .withValues(alpha: config.enabled ? 0.94 : 0.55),
                  ]
                : isDark
                    ? [
                        scheme.surfaceContainerHigh
                            .withValues(alpha: config.enabled ? 0.65 : 0.32),
                        scheme.surfaceContainerLow
                            .withValues(alpha: config.enabled ? 0.45 : 0.18),
                      ]
                    : [
                        Colors.white
                            .withValues(alpha: config.enabled ? 0.92 : 0.65),
                        Colors.white
                            .withValues(alpha: config.enabled ? 0.78 : 0.45),
                      ],
          ),
          border: Border.all(
            color: isAmoled
                ? (config.enabled
                    ? (_isHovered
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.16))
                    : Colors.white.withValues(alpha: 0.08))
                : isDark
                    ? (config.enabled
                        ? (_isHovered
                            ? Colors.white.withValues(alpha: 0.24)
                            : Colors.white.withValues(alpha: 0.12))
                        : Colors.white.withValues(alpha: 0.06))
                    : (config.enabled
                        ? (_isHovered
                            ? scheme.primary.withValues(alpha: 0.30)
                            : Colors.white.withValues(alpha: 0.90))
                        : Colors.white.withValues(alpha: 0.50)),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? (config.enabled ? (_isHovered ? 0.28 : 0.18) : 0.07)
                    : (_isHovered ? 0.08 : 0.04),
              ),
              blurRadius: _isHovered ? 16 : 10,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Icon squircle + Name & Host + Switch
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Service Icon Tile
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: config.enabled
                            ? engineColor.withValues(
                                alpha: isDark ? 0.18 : 0.12)
                            : (isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: config.enabled
                              ? engineColor.withValues(
                                  alpha: isDark ? 0.35 : 0.24)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          engineIcon,
                          size: 20,
                          color: config.enabled
                              ? engineColor
                              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name & Host
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  config.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: config.enabled
                                        ? scheme.onSurface
                                        : scheme.onSurface
                                            .withValues(alpha: 0.55),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (config.enabled) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF10B981),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 12,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  cleanHost,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Switch
                    Transform.scale(
                      scale: 0.85,
                      child: Switch.adaptive(
                        value: config.enabled,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          widget.onToggle(val);
                        },
                        activeThumbColor: scheme.primary,
                        activeTrackColor:
                            scheme.primary.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Row 2: Badges (Engine, Priority, Auth)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _GlassPill(
                      label: engineTitle,
                      color: config.enabled
                          ? engineColor
                          : scheme.onSurfaceVariant,
                      isDark: isDark,
                    ),
                    _GlassPill(
                      label:
                          '${isRu ? 'Приоритет' : 'Priority'} ${config.priority}',
                      color: scheme.onSurfaceVariant,
                      isDark: isDark,
                    ),
                    if (config.apiType.toLowerCase() == 'e621')
                      _GlassPill(
                        label:
                            (config.customHeaders['query.login']?.isNotEmpty ??
                                    false)
                                ? 'e621: ${config.customHeaders['query.login']}'
                                : (isRu
                                    ? 'e621: Гость (2 тега)'
                                    : 'e621: Guest (2 tags)'),
                        color:
                            (config.customHeaders['query.login']?.isNotEmpty ??
                                    false)
                                ? const Color(0xFF10B981)
                                : Colors.amber,
                        isDark: isDark,
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Row 3: Action Buttons (Right-aligned, sleek glass pills)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (config.apiType.toLowerCase() == 'e621' &&
                        widget.onSaveConfig != null) ...[
                      _GlassActionButton(
                        icon: Icons.vpn_key_rounded,
                        label:
                            (config.customHeaders['query.login']?.isNotEmpty ??
                                    false)
                                ? (isRu ? 'Аккаунт' : 'Account')
                                : (isRu ? 'API Ключ' : 'API Key'),
                        color: const Color(0xFF3B82F6),
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          E621AuthDialog.show(
                            context,
                            config: config,
                            onSaved: widget.onSaveConfig!,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    _GlassActionButton(
                      icon: Icons.edit_rounded,
                      label: isRu ? 'Изменить' : 'Edit',
                      color: scheme.onSurfaceVariant,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onEdit();
                      },
                    ),
                    const SizedBox(width: 6),
                    _GlassActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: isRu ? 'Удалить' : 'Delete',
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (Color, IconData, String) _engineInfo(String apiType) {
    return switch (apiType.toLowerCase()) {
      'nhentai' => (
          const Color(0xFFE11D48),
          Icons.menu_book_rounded,
          'nHentai (Manga)',
        ),
      'pixiv' => (
          const Color(0xFF0284C7),
          Icons.palette_rounded,
          'Pixiv',
        ),
      'gelbooru' => (
          const Color(0xFF10B981),
          Icons.image_search_rounded,
          'Gelbooru',
        ),
      'rule34' => (
          const Color(0xFF0D9488),
          Icons.photo_library_rounded,
          'Rule34',
        ),
      'safebooru' => (
          const Color(0xFF0284C7),
          Icons.shield_rounded,
          'Safebooru',
        ),
      'paheal' => (
          const Color(0xFFEA580C),
          Icons.filter_hdr_rounded,
          'Paheal HTML',
        ),
      'realbooru_html' => (
          const Color(0xFFCA8A04),
          Icons.camera_alt_rounded,
          'Realbooru HTML',
        ),
      'danbooru' => (
          const Color(0xFF3B82F6),
          Icons.auto_awesome_rounded,
          'Danbooru',
        ),
      'moebooru' => (
          const Color(0xFF8B5CF6),
          Icons.face_retouching_natural_rounded,
          'Moebooru',
        ),
      'e621' => (
          const Color(0xFFD97706),
          Icons.pets_rounded,
          'e621 / e926',
        ),
      'fapello' => (
          const Color(0xFFE8467C),
          Icons.person_search_rounded,
          'Fapello HTML',
        ),
      'wallhaven' => (
          const Color(0xFF059669),
          Icons.wallpaper_rounded,
          'Wallhaven API',
        ),
      'arena' || 'are_na' => (
          const Color(0xFF6366F1),
          Icons.dashboard_customize_rounded,
          'Are.na API',
        ),
      _ => (
          const Color(0xFF6366F1),
          Icons.hub_rounded,
          apiType.isEmpty ? 'Custom' : apiType,
        ),
    };
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.16),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: widget.isDark ? 0.22 : 0.14)
                  : widget.color.withValues(alpha: widget.isDark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovered
                    ? widget.color
                        .withValues(alpha: widget.isDark ? 0.45 : 0.30)
                    : widget.color
                        .withValues(alpha: widget.isDark ? 0.20 : 0.12),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 13, color: widget.color),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
