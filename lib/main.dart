import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/motion/desktop_smooth_scroll_binding.dart';
import 'core/performance/performance_monitor.dart';
import 'core/security/tls_security_policy.dart';
import 'core/utils/logger.dart';

class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = TlsSecurityPolicy.shouldAllowBadCertificate;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await windowManager.ensureInitialized();
    } catch (_) {}
  }
  HttpOverrides.global = _AppHttpOverrides();
  DesktopSmoothScrollBinding.ensureInitialized();
  PerformanceMonitorService.init();

  // `MediaKit.ensureInitialized()` is deliberately NOT called here. It boots
  // the whole mpv stack, and every place that actually plays media already
  // calls it lazily (`PostCard` previews, `PostMediaViewer`), so users who
  // never open a video pay neither the startup time nor the memory.

  // Global Flutter error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError: ${details.exceptionAsString}',
        details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // Global platform/isolate error handling
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('PlatformDispatcher: $error', error, stack);
    return true; // Mark as handled to avoid uncaught crashes where possible
  };

  // Optimize image cache to prevent memory bloat and OOM crashes
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      120 * 1024 * 1024; // 120 MB
  PaintingBinding.instance.imageCache.maximumSize = 80; // 80 images
  runApp(const ProviderScope(child: GelRuleApp()));
}
