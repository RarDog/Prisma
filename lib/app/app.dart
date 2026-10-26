import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/features/settings/presentation/widgets/app_update_dialog.dart';
import 'package:prisma_app/core/motion/desktop_smooth_scroll_binding.dart';
import 'package:prisma_app/features/downloads/presentation/widgets/download_dynamic_island.dart';
import 'app_strings.dart';
import 'motion.dart';
import 'router.dart';
import 'theme.dart';

class GelRuleApp extends ConsumerWidget {
  const GelRuleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(appDatabaseProvider);

    return database.when(
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupLoadingScreen(),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: _StartupErrorScreen(error: error),
      ),
      data: (_) {
        final settings = ref.watch(appSettingsProvider);
        final router = ref.watch(appRouterProvider);
        final appSettings = settings.value ?? AppSettings.defaults;
        final amoled = appSettings.amoledMode;
        final useDynamic = appSettings.useDynamicColor;
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            return MaterialApp.router(
              title: 'Prisma',
              debugShowCheckedModeBanner: false,
              locale: Locale(appSettings.languageCode),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: buildTheme(
                Brightness.light,
                seedColor: appSettings.appSeedColor,
                dynamicColorScheme: useDynamic ? lightDynamic : null,
              ),
              darkTheme: buildTheme(
                Brightness.dark,
                seedColor: appSettings.appSeedColor,
                amoled: amoled,
                dynamicColorScheme: useDynamic ? darkDynamic : null,
              ),
              themeMode: parseThemeMode(appSettings.themeMode),
              scrollBehavior: const DesktopSmoothScrollBehavior(),
              routerConfig: router,
              builder: (context, child) => _AppOverlay(child: child),
            );
          },
        );
      },
    );
  }
}

class _AppOverlay extends ConsumerStatefulWidget {
  const _AppOverlay({required this.child});

  final Widget? child;

  @override
  ConsumerState<_AppOverlay> createState() => _AppOverlayState();
}

class _AppOverlayState extends ConsumerState<_AppOverlay>
    with WidgetsBindingObserver {
  bool _checkedUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      try {
        ref.read(backupServiceProvider).saveAutoBackupToPersistentStorage();
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedUpdates) return;
    _checkedUpdates = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdates());
  }

  Future<void> _checkUpdates() async {
    final result = await ref.read(updateServiceProvider).checkForUpdates();
    if (!mounted || result is! Success<AppUpdateInfo?> || result.data == null) {
      return;
    }
    await _showUpdateDialog(result.data!);
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    final navContext = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentContext ??
        context;
    if (Navigator.maybeOf(navContext) == null) return;
    await showAppUpdateDialog(
      context: navContext,
      ref: ref,
      info: info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(appSettingsProvider).value;
    final isAndroid = Platform.isAndroid;
    final deviceInfo =
        isAndroid ? ref.watch(motionDeviceInfoProvider).value : null;
    final view = isAndroid ? View.maybeOf(context) : null;
    final detectedHz = isAndroid ? view?.display.refreshRate ?? 60.0 : 60.0;
    final motion = resolveMotionSettings(
      settings: appSettings ?? AppSettings.defaults,
      detectedHz: detectedHz,
      device: deviceInfo,
    );
    if (isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(deviceMotionServiceProvider)
            .setPreferredRefreshRate(motion.effectiveHz);
      });
    }
    return AppMotionScope(
      settings: motion,
      child: DownloadDynamicIslandOverlay(child: widget.child),
    );
  }
}

final appSettingsProvider = FutureProvider<AppSettings>((ref) {
  return ref.watch(settingsServiceProvider).getSettings().then(
        (result) => result.fold(
          onSuccess: (settings) => settings,
          onError: (_) => AppSettings.defaults,
        ),
      );
});

final appStringsProvider = Provider<AppStrings>((ref) {
  final settings = ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return AppStrings(settings.languageCode);
});

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101114),
      body: Center(
        child: CircularProgressIndicator(
          color: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE84D8A),
            brightness: Brightness.dark,
          ).primary,
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends ConsumerWidget {
  const _StartupErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  strings.ru
                      ? '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0442\u043a\u0440\u044b\u0442\u044c \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u0443\u044e \u0431\u0430\u0437\u0443'
                      : 'Could not start local database',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(appDatabaseProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
