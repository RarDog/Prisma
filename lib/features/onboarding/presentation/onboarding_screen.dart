import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../backend/backend.dart';
import '../../../core/utils/result.dart';
import '../../providers/presentation/providers_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Provider credentials controllers
  final TextEditingController _gelbooruUserId = TextEditingController();
  final TextEditingController _gelbooruApiKey = TextEditingController();

  final TextEditingController _e621Login = TextEditingController();
  final TextEditingController _e621ApiKey = TextEditingController();

  final TextEditingController _danbooruLogin = TextEditingController();
  final TextEditingController _danbooruApiKey = TextEditingController();

  bool _isSavingKeys = false;
  int _configuredProvidersCount = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _gelbooruUserId.dispose();
    _gelbooruApiKey.dispose();
    _e621Login.dispose();
    _e621ApiKey.dispose();
    _danbooruLogin.dispose();
    _danbooruApiKey.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _setLanguage(String langCode) async {
    HapticFeedback.selectionClick();
    final settingsService = ref.read(settingsServiceProvider);
    final result = await settingsService.getSettings();
    if (result is Success<AppSettings>) {
      final current = result.data;
      if (current.languageCode != langCode) {
        await settingsService.updateSettings(
          current.copyWith(languageCode: langCode),
        );
        ref.invalidate(appSettingsProvider);
      }
    }
  }

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
          customHeaders: const {
            'User-Agent': 'Prisma/3.8.3 Flutter local booru browser',
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
      debugPrint('Error saving onboarding API keys: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingKeys = false;
          _configuredProvidersCount = count;
        });
        _nextPage();
      }
    }
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    await ref.read(onboardingServiceProvider).markCompleted();
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: isRu ? 'Назад' : 'Back',
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  // Step Dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (_currentPage < 3)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _finishOnboarding();
                      },
                      child: Text(
                        isRu ? 'Пропустить всё' : 'Skip all',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildLanguageStep(theme, isRu, settings.languageCode),
                  _buildWelcomeStep(theme, isRu),
                  _buildApiKeysStep(theme, isRu),
                  _buildCompletionStep(theme, isRu),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 1: LANGUAGE SELECTION
  // -------------------------------------------------------------
  Widget _buildLanguageStep(ThemeData theme, bool isRu, String currentLang) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.language_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRu ? 'Добро пожаловать в Prisma!' : 'Welcome to Prisma!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isRu
                ? 'Выберите язык интерфейса приложения'
                : 'Select the app interface language',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Russian Option
          _LanguageCard(
            title: 'Русский',
            subtitle: 'Интерфейс на русском языке',
            flag: '🇷🇺',
            isSelected: currentLang == 'ru',
            onTap: () => _setLanguage('ru'),
          ),
          const SizedBox(height: 16),

          // English Option
          _LanguageCard(
            title: 'English',
            subtitle: 'Interface in English',
            flag: '🇬🇧',
            isSelected: currentLang == 'en',
            onTap: () => _setLanguage('en'),
          ),

          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isRu ? 'Продолжить' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: WELCOME & OVERVIEW
  // -------------------------------------------------------------
  Widget _buildWelcomeStep(ThemeData theme, bool isRu) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isRu ? 'Быстрый и современный Booru-клиент' : 'Fast & Modern Booru Client',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Prisma объединяет популярнейшие базы артов в едином удобном приложении'
                : 'Prisma combines the most popular booru imageboards in one powerful app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          _FeatureTile(
            icon: Icons.search_rounded,
            color: const Color(0xFF3B82F6),
            title: isRu ? 'Мощный поиск и теги' : 'Powerful Search & Tags',
            subtitle: isRu
                ? 'Мгновенное автодополнение, фильтры по рейтингу, черный список и сортировка.'
                : 'Instant autocomplete, rating filters, smart blacklist, and sorting.',
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.palette_rounded,
            color: const Color(0xFF8B5CF6),
            title: isRu ? 'Каталог авторов и пулы' : 'Artists & Pools',
            subtitle: isRu
                ? 'Просмотр профилей художников, подборки работ, серий и альбомов.'
                : 'Browse artist profiles, dedicated galleries, series, and pools.',
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.collections_bookmark_rounded,
            color: const Color(0xFF10B981),
            title: isRu ? 'Коллекции и Избранное' : 'Collections & Favorites',
            subtitle: isRu
                ? 'Локальные тематические коллекции, синхронизация закладок и загрузка медиа.'
                : 'Custom offline collections, synchronized bookmarks, and media downloader.',
          ),
          const SizedBox(height: 12),
          _FeatureTile(
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFFF59E0B),
            title: isRu ? 'Персистентное хранилище' : 'Persistent Storage',
            subtitle: isRu
                ? 'Все настройки, аккаунты и закладки автоматически сохраняются и выдерживают переустановку.'
                : 'All settings, accounts, and bookmarks survive app reinstallation automatically.',
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _nextPage,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isRu ? 'Настроить провайдеры' : 'Configure Providers',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 3: API KEYS & PROVIDERS
  // -------------------------------------------------------------
  Widget _buildApiKeysStep(ThemeData theme, bool isRu) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.vpn_key_rounded,
                size: 48,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              isRu ? 'Учетные данные и API' : 'Credentials & API Keys',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isRu
                  ? 'Вы можете ввести API-ключи сейчас для полного доступа (избранное, повышенные лимиты) или сделать это позже в настройках.'
                  : 'Add your API keys now for full features (favorites sync, higher limits) or configure them later in settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Provider 1: Gelbooru
          _ProviderSectionCard(
            title: 'Gelbooru',
            tag: 'gelbooru.com',
            iconColor: const Color(0xFF10B981),
            children: [
              TextField(
                controller: _gelbooruUserId,
                decoration: InputDecoration(
                  labelText: isRu ? 'User ID (ID пользователя)' : 'User ID',
                  hintText: 'e.g. 123456',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _gelbooruApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: isRu ? 'Вставьте API ключ' : 'Paste API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 6),
              Text(
                isRu
                    ? '💡 Находится в Gelbooru -> My Account -> API Access'
                    : '💡 Found in Gelbooru -> My Account -> API Access',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Provider 2: e621
          _ProviderSectionCard(
            title: 'e621 / e926',
            tag: 'e621.net',
            iconColor: const Color(0xFFF59E0B),
            children: [
              TextField(
                controller: _e621Login,
                decoration: InputDecoration(
                  labelText: isRu ? 'Логин (Username)' : 'Username',
                  hintText: 'e.g. your_username',
                  prefixIcon: const Icon(Icons.account_circle_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _e621ApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: isRu ? 'Вставьте API ключ e621' : 'Paste e621 API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 6),
              Text(
                isRu
                    ? '💡 Находится в e621 -> Manage Account -> API Access'
                    : '💡 Found in e621 -> Manage Account -> API Access',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Provider 3: Danbooru
          _ProviderSectionCard(
            title: 'Danbooru',
            tag: 'danbooru.donmai.us',
            iconColor: const Color(0xFF3B82F6),
            children: [
              TextField(
                controller: _danbooruLogin,
                decoration: InputDecoration(
                  labelText: isRu ? 'Логин (Username)' : 'Username',
                  hintText: 'e.g. your_username',
                  prefixIcon: const Icon(Icons.account_circle_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _danbooruApiKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: isRu ? 'Вставьте API ключ' : 'Paste API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 6),
              Text(
                isRu
                    ? '💡 Находится в Danbooru -> Profile -> API Key'
                    : '💡 Found in Danbooru -> Profile -> API Key',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isSavingKeys ? null : _saveEnteredApiKeys,
            icon: _isSavingKeys
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              isRu ? 'Сохранить и продолжить' : 'Save & Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _nextPage,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isRu ? 'Пропустить ввод ключей' : 'Skip entering keys',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 4: COMPLETION
  // -------------------------------------------------------------
  Widget _buildCompletionStep(ThemeData theme, bool isRu) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 64,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isRu ? 'Всё готово!' : 'All Set!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isRu
                ? 'Вы можете начать своё путешествие по миру артов. Все настройки сохранены и защищены.'
                : 'You are ready to begin your journey. All settings are safely preserved.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.language_rounded,
                  label: isRu ? 'Язык приложения' : 'Language',
                  value: isRu ? 'Русский 🇷🇺' : 'English 🇬🇧',
                ),
                const Divider(height: 24),
                _SummaryRow(
                  icon: Icons.shield_rounded,
                  label: isRu ? 'Персистентный автобэкап' : 'Persistent backup',
                  value: isRu ? 'Включен' : 'Active',
                  valueColor: const Color(0xFF10B981),
                ),
                if (_configuredProvidersCount > 0) ...[
                  const Divider(height: 24),
                  _SummaryRow(
                    icon: Icons.vpn_key_rounded,
                    label: isRu ? 'Настроено ключей' : 'Keys configured',
                    value: '$_configuredProvidersCount',
                    valueColor: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _finishOnboarding,
            icon: const Icon(Icons.explore_rounded),
            label: Text(
              isRu ? 'Начать путешествие' : 'Start Journey',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSectionCard extends StatelessWidget {
  const _ProviderSectionCard({
    required this.title,
    required this.tag,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final String tag;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                tag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
