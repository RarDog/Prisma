import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Formats raw system or library errors into user-friendly localized messages.
String formatUserFriendlyError(Object? error, {bool isRu = true}) {
  if (error == null) return isRu ? 'Неизвестная ошибка' : 'Unknown error';

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return isRu
            ? 'Время ожидания ответа истекло. Проверьте интернет-соединение.'
            : 'Connection timed out. Check your internet connection.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 403) {
          return isRu
              ? 'Доступ ограничен (403). Источник заблокирован или требует защиты Cloudflare.'
              : 'Access restricted (403). Provider is protected or blocking requests.';
        }
        if (status == 404) {
          return isRu
              ? 'Запрашиваемый ресурс не найден (404).'
              : 'Requested resource not found (404).';
        }
        if (status == 429) {
          return isRu
              ? 'Слишком много запросов (429). Подождите несколько секунд.'
              : 'Too many requests (429). Please wait a few seconds.';
        }
        if (status != null && status >= 500) {
          return isRu
              ? 'Сервер источника временно недоступен ($status).'
              : 'Provider server is temporarily down ($status).';
        }
        return isRu
            ? 'Ошибка сервера: код $status'
            : 'Server error: code $status';
      case DioExceptionType.cancel:
        return isRu ? 'Запрос был отменен' : 'Request was cancelled';
      case DioExceptionType.connectionError:
        return isRu
            ? 'Нет соединения с сервером. Проверьте сеть или VPN.'
            : 'No connection to server. Check your network or VPN.';
      case DioExceptionType.badCertificate:
        return isRu
            ? 'Ошибка безопасности SSL сертификата.'
            : 'SSL certificate error.';
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return isRu
              ? 'Не удалось подключиться к сети. Проверьте интернет.'
              : 'Could not connect to network. Check connection.';
        }
        break;
    }
  }

  final msg = error.toString().toLowerCase();
  if (msg.contains('socketexception') ||
      msg.contains('failed host lookup') ||
      msg.contains('network is unreachable')) {
    return isRu
        ? 'Нет подключения к сети. Проверьте интернет или включите VPN.'
        : 'Network unreachable. Check connection or try VPN.';
  }
  if (msg.contains('handshakeexception') || msg.contains('certificate')) {
    return isRu
        ? 'Ошибка безопасного соединения с источником.'
        : 'Secure connection error with provider.';
  }
  if (msg.contains('cloudflare') || msg.contains('challenge')) {
    return isRu
        ? 'Источник защищен проверкой Cloudflare и временно заблокировал доступ.'
        : 'Source is protected by Cloudflare and restricted access.';
  }
  if (msg.contains('429') || msg.contains('too many requests')) {
    return isRu
        ? 'Слишком много запросов. Подождите немного перед повтором.'
        : 'Too many requests. Please wait before retrying.';
  }
  if (msg.contains('timeoutexception') || msg.contains('timed out')) {
    return isRu
        ? 'Сервер слишком долго отвечает. Попробуйте еще раз.'
        : 'Server took too long to respond. Try again.';
  }

  return error.toString();
}

/// A centralized ErrorBoundary widget for wrapping views or subtrees,
/// catching render exceptions or cleanly presenting async error states.
class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({
    super.key,
    required this.child,
    this.fallbackBuilder,
    this.onRetry,
  });

  final Widget child;
  final Widget Function(BuildContext context, Object error, VoidCallback? onRetry)?
      fallbackBuilder;
  final VoidCallback? onRetry;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  void _reset() {
    setState(() => _error = null);
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(context, _error!, _reset);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Builder(builder: (ctx) {
                final isRu =
                    Localizations.maybeLocaleOf(ctx)?.languageCode == 'ru';
                return Text(
                  formatUserFriendlyError(_error, isRu: isRu),
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                );
              }),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Builder(builder: (ctx) {
                  final isRu =
                      Localizations.maybeLocaleOf(ctx)?.languageCode == 'ru';
                  return Text(isRu ? 'Повторить' : 'Retry');
                }),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
