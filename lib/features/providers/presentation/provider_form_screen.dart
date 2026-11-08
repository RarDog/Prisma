import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'providers_controller.dart';
import 'widgets/form/provider_auth_section.dart';
import 'widgets/form/provider_form_controls.dart';
import 'widgets/form/provider_form_presets.dart';

class ProviderFormScreen extends ConsumerStatefulWidget {
  const ProviderFormScreen({this.initialConfig, super.key});

  final ContentProviderConfig? initialConfig;

  @override
  ConsumerState<ProviderFormScreen> createState() => _ProviderFormScreenState();
}

class _ProviderFormScreenState extends ConsumerState<ProviderFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _priority;
  late final TextEditingController _timeout;
  late final TextEditingController _headers;
  late final TextEditingController _apiKey;
  late final TextEditingController _userId;
  late final TextEditingController _login;
  late final TextEditingController _phpsessid;
  late String _apiType;
  late bool _enabled;
  bool _obscureApiKey = true;
  bool _obscurePhpsessid = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _name = TextEditingController(text: config?.name);
    _baseUrl = TextEditingController(text: config?.baseUrl);
    _priority =
        TextEditingController(text: (config?.priority ?? 10).toString());
    _timeout =
        TextEditingController(text: (config?.timeoutSeconds ?? 20).toString());
    _headers = TextEditingController(
      text: jsonEncode(_visibleHeaders(config?.customHeaders ?? const {})),
    );
    _apiKey =
        TextEditingController(text: config?.customHeaders['query.api_key']);
    _userId =
        TextEditingController(text: config?.customHeaders['query.user_id']);
    _login = TextEditingController(text: config?.customHeaders['query.login']);
    _phpsessid = TextEditingController(
      text: config?.customHeaders['phpsessid'] ??
          config?.customHeaders['PHPSESSID'],
    );
    _apiType = config?.apiType ?? 'gelbooru';
    _enabled = config?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _priority.dispose();
    _timeout.dispose();
    _headers.dispose();
    _apiKey.dispose();
    _userId.dispose();
    _login.dispose();
    _phpsessid.dispose();
    super.dispose();
  }

  void _applyPreset({
    required String name,
    required String baseUrl,
    required String apiType,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _name.text = name;
      _baseUrl.text = baseUrl;
      _apiType = apiType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final isEdit = widget.initialConfig != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
              backgroundColor: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/providers');
                  }
                },
                tooltip: isRu ? 'Назад' : 'Back',
              ),
              title: Text(
                isEdit
                    ? (isRu ? 'Редактирование источника' : 'Edit Provider')
                    : (isRu ? 'Новый источник' : 'New Provider'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 68,
              16,
              140 + bottomInset,
            ),
            children: [
              // Presets bar if creating a new provider
              if (!isEdit)
                ProviderPresetsBar(
                  onPresetSelected: (preset) => _applyPreset(
                    name: preset.name,
                    baseUrl: preset.baseUrl,
                    apiType: preset.apiType,
                  ),
                ),

              // Section 1: General Parameters
              FormLiquidCard(
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFF6366F1),
                title: isRu ? 'Основные параметры' : 'General Configuration',
                subtitle: isRu
                    ? 'Имя, адрес сервера и тип API движка'
                    : 'Name, server endpoint and API engine',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassTextField(
                      controller: _name,
                      label: isRu ? 'Название источника' : 'Provider Name',
                      hint: 'e.g. Gelbooru, Rule34',
                      icon: Icons.label_rounded,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: _baseUrl,
                      label: isRu ? 'Базовый URL (Base URL)' : 'Base URL',
                      hint: 'https://example.com',
                      icon: Icons.link_rounded,
                    ),
                    const SizedBox(height: 14),
                    // Dropdown API Type
                    GlassDropdown(
                      label: isRu ? 'Тип API движка' : 'API Engine Type',
                      value: _apiType,
                      onChanged: (val) {
                        if (val != null) setState(() => _apiType = val);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'mangadex',
                          child: Text('MangaDex (Official Manga API)'),
                        ),
                        DropdownMenuItem(
                          value: 'nhentai',
                          child: Text('nHentai (Manga/Comics API)'),
                        ),
                        DropdownMenuItem(
                          value: 'pixiv',
                          child: Text('Pixiv (Web AJAX)'),
                        ),
                        DropdownMenuItem(
                          value: 'gelbooru',
                          child: Text('Gelbooru (compatible)'),
                        ),
                        DropdownMenuItem(
                          value: 'rule34',
                          child: Text('Rule34 (compatible)'),
                        ),
                        DropdownMenuItem(
                          value: 'safebooru',
                          child: Text('Safebooru (compatible)'),
                        ),
                        DropdownMenuItem(
                          value: 'danbooru',
                          child: Text('Danbooru (compatible)'),
                        ),
                        DropdownMenuItem(
                          value: 'e621',
                          child: Text('e621 / e926'),
                        ),
                        DropdownMenuItem(
                          value: 'moebooru',
                          child: Text('Moebooru (Yande.re, Konachan)'),
                        ),
                        DropdownMenuItem(
                          value: 'paheal',
                          child: Text('Rule34 Paheal HTML'),
                        ),
                        DropdownMenuItem(
                          value: 'realbooru_html',
                          child: Text('Realbooru HTML'),
                        ),
                        DropdownMenuItem(
                          value: 'rule34_us',
                          child: Text('Rule34.us HTML'),
                        ),
                        DropdownMenuItem(
                          value: 'tbib',
                          child: Text('TBIB (The Big ImageBoard)'),
                        ),
                        DropdownMenuItem(
                          value: 'wallhaven',
                          child: Text('Wallhaven API (Wallpapers & Art)'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom REST API'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Enabled Switch Tile
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.power_settings_new_rounded,
                            size: 20,
                            color: _enabled
                                ? const Color(0xFF10B981)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isRu
                                  ? 'Включить этот источник'
                                  : 'Enable provider',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _enabled,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _enabled = val);
                            },
                            activeThumbColor: const Color(0xFF10B981),
                            activeTrackColor:
                                const Color(0xFF10B981).withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Section 2: Priority & Timeout
              FormLiquidCard(
                icon: Icons.speed_rounded,
                accentColor: const Color(0xFF10B981),
                title: isRu
                    ? 'Приоритет и производительность'
                    : 'Priority & Performance',
                subtitle: isRu
                    ? 'Порядок выдачи постов и максимальное время ответа'
                    : 'Dispatch priority and maximum network wait time',
                child: Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        controller: _priority,
                        label: isRu ? 'Приоритет (Priority)' : 'Priority',
                        hint: '10',
                        icon: Icons.trending_up_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassTextField(
                        controller: _timeout,
                        label: isRu ? 'Таймаут (сек)' : 'Timeout (s)',
                        hint: '20',
                        icon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Section 3: Credentials & API Keys
              ProviderAuthSection(
                apiKeyController: _apiKey,
                userIdController: _userId,
                loginController: _login,
                phpsessidController: _phpsessid,
                apiType: _apiType,
                obscureApiKey: _obscureApiKey,
                onToggleObscureApiKey: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                obscurePhpsessid: _obscurePhpsessid,
                onToggleObscurePhpsessid: () =>
                    setState(() => _obscurePhpsessid = !_obscurePhpsessid),
              ),

              const SizedBox(height: 18),

              // Section 4: Custom Headers JSON
              FormLiquidCard(
                icon: Icons.terminal_rounded,
                accentColor: const Color(0xFF06B6D4),
                title: isRu ? 'Заголовки JSON' : 'Custom Headers (JSON)',
                subtitle: isRu
                    ? 'Дополнительные HTTP заголовки в формате JSON'
                    : 'Optional custom request headers in JSON map format',
                child: GlassTextField(
                  controller: _headers,
                  label: isRu ? 'Пользовательские заголовки' : 'Headers JSON',
                  hint: '{"User-Agent": "Prisma/3.0"}',
                  icon: Icons.code_rounded,
                  minLines: 2,
                  maxLines: 5,
                  isMonospace: true,
                ),
              ),

              const SizedBox(height: 24),

              // Save Action Button
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.38),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _isSaving ? null : _save,
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isRu
                                      ? 'Сохранить провайдер'
                                      : 'Save Provider',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel Button
              Center(
                child: TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/providers');
                    }
                  },
                  child: Text(
                    isRu ? 'Отмена' : 'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final nameText = _name.text.trim();
    if (nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Укажите название провайдера' : 'Enter provider name',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    unawaited(HapticFeedback.lightImpact());

    try {
      final now = DateTime.now();

      Map<String, dynamic> headersJson = {};
      if (_headers.text.trim().isNotEmpty) {
        try {
          headersJson =
              jsonDecode(_headers.text.trim()) as Map<String, dynamic>;
        } catch (_) {
          // A silent fallback to {} would drop the user's credentials and
          // save a broken provider; surface it instead.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isRu
                      ? 'Заголовки: некорректный JSON — исправьте поле'
                      : 'Headers: invalid JSON — fix the field',
                ),
              ),
            );
          }
          return;
        }
      }
      final customHeaders = Map<String, String>.from(
        headersJson.map((k, v) => MapEntry(k.toString(), v.toString())),
      );

      void putQuery(String key, String value) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) customHeaders['query.$key'] = trimmed;
      }

      putQuery('api_key', _apiKey.text);
      putQuery('user_id', _userId.text);
      putQuery('login', _login.text);
      // Save PHPSESSID for Pixiv
      final phpsessidVal = _phpsessid.text.trim();
      if (phpsessidVal.isNotEmpty) {
        customHeaders['phpsessid'] = phpsessidVal;
      } else {
        customHeaders.remove('phpsessid');
        customHeaders.remove('PHPSESSID');
      }

      // Providers are stored keyed by id: deriving the id from the name
      // without a collision check would let a new "Danbooru" card silently
      // overwrite the seeded danbooru provider.
      final baseId =
          nameText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      var id = widget.initialConfig?.id ?? baseId;
      var renamed = false;
      if (widget.initialConfig == null) {
        final existing =
            ref.read(providersControllerProvider).value ?? const [];
        final taken = existing.map((c) => c.id).toSet();
        if (taken.contains(id)) {
          var suffix = 2;
          while (taken.contains('${baseId}_$suffix')) {
            suffix++;
          }
          id = '${baseId}_$suffix';
          renamed = true;
        }
      }

      final config = ContentProviderConfig(
        id: id,
        name: nameText,
        baseUrl: _baseUrl.text.trim(),
        apiType: _apiType,
        enabled: _enabled,
        priority: int.tryParse(_priority.text) ?? 10,
        timeoutSeconds: int.tryParse(_timeout.text) ?? 20,
        customHeaders: customHeaders,
        createdAt: widget.initialConfig?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(providersControllerProvider.notifier).save(config);
      if (mounted) {
        if (renamed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isRu
                    ? 'ID занят — провайдер сохранён как "$id"'
                    : 'ID taken — provider saved as "$id"',
              ),
            ),
          );
        }
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/providers');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Не удалось сохранить провайдера: $error'
                  : 'Failed to save provider: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, String> _visibleHeaders(Map<String, String> headers) {
    return Map<String, String>.from(headers)
      ..removeWhere((key, _) =>
          key.startsWith('query.') || key.toLowerCase() == 'phpsessid');
  }
}
