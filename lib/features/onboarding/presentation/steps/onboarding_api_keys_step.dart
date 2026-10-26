import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/http/app_headers.dart';
import 'package:prisma_app/features/onboarding/presentation/widgets/onboarding_shared_widgets.dart';
import 'package:prisma_app/features/providers/presentation/providers_controller.dart';

class OnboardingApiKeysStep extends ConsumerStatefulWidget {
  const OnboardingApiKeysStep({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  final void Function(int configuredCount) onNext;
  final VoidCallback onSkip;

  @override
  ConsumerState<OnboardingApiKeysStep> createState() =>
      _OnboardingApiKeysStepState();
}

class _OnboardingApiKeysStepState extends ConsumerState<OnboardingApiKeysStep> {
  final TextEditingController _gelbooruUserId = TextEditingController();
  final TextEditingController _gelbooruApiKey = TextEditingController();

  final TextEditingController _e621Login = TextEditingController();
  final TextEditingController _e621ApiKey = TextEditingController();

  final TextEditingController _danbooruLogin = TextEditingController();
  final TextEditingController _danbooruApiKey = TextEditingController();

  bool _isSavingKeys = false;
  bool _expandedGel = false;
  bool _expandedE6 = false;
  bool _expandedDan = false;

  bool _showGelKey = false;
  bool _showE6Key = false;
  bool _showDanKey = false;

  @override
  void initState() {
    super.initState();
    _gelbooruApiKey.addListener(_onFieldChanged);
    _e621ApiKey.addListener(_onFieldChanged);
    _danbooruApiKey.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gelbooruApiKey.removeListener(_onFieldChanged);
    _e621ApiKey.removeListener(_onFieldChanged);
    _danbooruApiKey.removeListener(_onFieldChanged);

    _gelbooruUserId.dispose();
    _gelbooruApiKey.dispose();
    _e621Login.dispose();
    _e621ApiKey.dispose();
    _danbooruLogin.dispose();
    _danbooruApiKey.dispose();
    super.dispose();
  }

  bool get _hasAnyKeyEntered =>
      _gelbooruApiKey.text.trim().isNotEmpty ||
      _e621ApiKey.text.trim().isNotEmpty ||
      _danbooruApiKey.text.trim().isNotEmpty;

  Future<void> _saveEnteredApiKeys() async {
    setState(() => _isSavingKeys = true);
    int count = 0;
    try {
      final providersAsync = ref.read(providersControllerProvider);
      final providers = providersAsync.value ?? [];

      // 1. Gelbooru
      final gelUserId = _gelbooruUserId.text.trim();
      final gelKey = _gelbooruApiKey.text.trim();
      if (gelKey.isNotEmpty) {
        ContentProviderConfig? gel = providers
            .where((p) => p.id == 'gelbooru' || p.apiType == 'gelbooru')
            .firstOrNull;
        gel ??= ContentProviderConfig(
          id: 'gelbooru',
          name: 'Gelbooru',
          baseUrl: 'https://gelbooru.com',
          apiType: 'gelbooru',
          enabled: true,
          priority: 0,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final headers = Map<String, String>.from(gel.customHeaders);
        headers['query.api_key'] = gelKey;
        if (gelUserId.isNotEmpty) headers['query.user_id'] = gelUserId;
        await ref.read(providersControllerProvider.notifier).save(
              gel.copyWith(customHeaders: headers),
            );
        count++;
      }

      // 2. e621
      final e6Login = _e621Login.text.trim();
      final e6Key = _e621ApiKey.text.trim();
      if (e6Key.isNotEmpty) {
        ContentProviderConfig? e6 = providers
            .where((p) => p.id == 'e621' || p.baseUrl.contains('e621.net'))
            .firstOrNull;
        e6 ??= ContentProviderConfig(
          id: 'e621',
          name: 'e621',
          baseUrl: 'https://e621.net',
          apiType: 'e621',
          enabled: true,
          priority: 3,
          timeoutSeconds: 20,
          customHeaders: {
            'User-Agent': AppHeaders.defaultUserAgent,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final headers = Map<String, String>.from(e6.customHeaders);
        headers['query.api_key'] = e6Key;
        if (e6Login.isNotEmpty) {
          headers['query.login'] = e6Login;
          headers['Authorization'] =
              'Basic ${base64Encode(utf8.encode('$e6Login:$e6Key'))}';
        }
        await ref.read(providersControllerProvider.notifier).save(
              e6.copyWith(customHeaders: headers),
            );
        count++;
      }

      // 3. Danbooru
      final danLogin = _danbooruLogin.text.trim();
      final danKey = _danbooruApiKey.text.trim();
      if (danKey.isNotEmpty) {
        ContentProviderConfig? dan = providers
            .where((p) => p.id == 'danbooru' || p.apiType == 'danbooru')
            .firstOrNull;
        dan ??= ContentProviderConfig(
          id: 'danbooru',
          name: 'Danbooru',
          baseUrl: 'https://danbooru.donmai.us',
          apiType: 'danbooru',
          enabled: true,
          priority: 6,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final headers = Map<String, String>.from(dan.customHeaders);
        headers['query.api_key'] = danKey;
        if (danLogin.isNotEmpty) {
          headers['query.login'] = danLogin;
          headers['Authorization'] =
              'Basic ${base64Encode(utf8.encode('$danLogin:$danKey'))}';
        }
        await ref.read(providersControllerProvider.notifier).save(
              dan.copyWith(customHeaders: headers),
            );
        count++;
      }
    } catch (e) {
      AppLogger.error('Error saving onboarding API keys', e);
    } finally {
      if (mounted) {
        setState(() => _isSavingKeys = false);
        widget.onNext(count);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';
    final hasKey = _hasAnyKeyEntered;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          const PulsingIconBadge(
            icon: Icons.vpn_key_rounded,
            gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            size: 46,
          ),
          const SizedBox(height: 18),
          Text(
            isRu ? 'Учетные данные и API' : 'Credentials & API Keys',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Необязательный шаг: поиск и просмотр артов работают сразу'
                : 'Optional step: browsing and searching work out of the box',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Friendly Info Callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRu
                        ? 'Вход не требуется для поиска и просмотра! Добавьте ключи только если хотите синхронизировать избранное со своим booru-аккаунтом или снять строгие лимиты.'
                        : 'No login required for browsing! Connect only if you want to sync favorites with your booru account or unlock higher rate limits.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Provider 1: Gelbooru
          ExpandableAccountCard(
            title: 'Gelbooru',
            tag: 'gelbooru.com',
            iconColor: const Color(0xFF10B981),
            icon: Icons.auto_awesome_rounded,
            isConfigured: _gelbooruApiKey.text.trim().isNotEmpty,
            isExpanded: _expandedGel,
            isRu: isRu,
            helpUrl: 'https://gelbooru.com/index.php?page=account&s=options',
            helpUrlLabel: isRu
                ? 'Открыть Gelbooru: My Account -> API'
                : 'Open Gelbooru: My Account -> API',
            onToggle: () => setState(() => _expandedGel = !_expandedGel),
            children: [
              TextField(
                controller: _gelbooruUserId,
                decoration: InputDecoration(
                  labelText: isRu ? 'User ID (ID пользователя)' : 'User ID',
                  hintText: 'e.g. 123456',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _gelbooruApiKey,
                obscureText: !_showGelKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: isRu ? 'Вставьте API ключ' : 'Paste API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showGelKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () => setState(() => _showGelKey = !_showGelKey),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),

          // Provider 2: e621
          ExpandableAccountCard(
            title: 'e621 / e926',
            tag: 'e621.net',
            iconColor: const Color(0xFFF59E0B),
            icon: Icons.pets_rounded,
            isConfigured: _e621ApiKey.text.trim().isNotEmpty,
            isExpanded: _expandedE6,
            isRu: isRu,
            helpUrl: 'https://e621.net/users/home',
            helpUrlLabel: isRu
                ? 'Открыть e621: Manage Account -> API'
                : 'Open e621: Manage Account -> API',
            onToggle: () => setState(() => _expandedE6 = !_expandedE6),
            children: [
              TextField(
                controller: _e621Login,
                decoration: InputDecoration(
                  labelText: isRu ? 'Логин (Username)' : 'Username',
                  hintText: 'e.g. your_username',
                  prefixIcon: const Icon(Icons.account_circle_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _e621ApiKey,
                obscureText: !_showE6Key,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText:
                      isRu ? 'Вставьте API ключ e621' : 'Paste e621 API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showE6Key
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () => setState(() => _showE6Key = !_showE6Key),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),

          // Provider 3: Danbooru
          ExpandableAccountCard(
            title: 'Danbooru',
            tag: 'danbooru.donmai.us',
            iconColor: const Color(0xFF3B82F6),
            icon: Icons.auto_awesome_rounded,
            isConfigured: _danbooruApiKey.text.trim().isNotEmpty,
            isExpanded: _expandedDan,
            isRu: isRu,
            helpUrl: 'https://danbooru.donmai.us/profile',
            helpUrlLabel: isRu
                ? 'Открыть Danbooru: Profile -> API Key'
                : 'Open Danbooru: Profile -> API Key',
            onToggle: () => setState(() => _expandedDan = !_expandedDan),
            children: [
              TextField(
                controller: _danbooruLogin,
                decoration: InputDecoration(
                  labelText: isRu ? 'Логин (Username)' : 'Username',
                  hintText: 'e.g. your_username',
                  prefixIcon: const Icon(Icons.account_circle_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _danbooruApiKey,
                obscureText: !_showDanKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: isRu ? 'Вставьте API ключ' : 'Paste API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showDanKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () => setState(() => _showDanKey = !_showDanKey),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isSavingKeys
                ? null
                : (hasKey ? _saveEnteredApiKeys : () => widget.onNext(0)),
            icon: _isSavingKeys
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    hasKey ? Icons.check_rounded : Icons.arrow_forward_rounded),
            label: Text(
              hasKey
                  ? (isRu ? 'Сохранить и продолжить' : 'Save & Continue')
                  : (isRu
                      ? 'Продолжить без аккаунтов'
                      : 'Continue without accounts'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: widget.onSkip,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isRu ? 'Пропустить ввод ключей' : 'Skip entering keys',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
