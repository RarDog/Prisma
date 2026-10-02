import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/utils/logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Global Flutter error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError: ${details.exceptionAsString()}', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // Global platform/isolate error handling
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('PlatformDispatcher: $error', error, stack);
    return true; // Mark as handled to avoid uncaught crashes where possible
  };

  // Optimize image cache to prevent memory bloat and OOM crashes
  PaintingBinding.instance.imageCache.maximumSizeBytes = 180 * 1024 * 1024; // 180 MB
  PaintingBinding.instance.imageCache.maximumSize = 120; // 120 images
  runApp(const ProviderScope(child: GelRuleApp()));
}
