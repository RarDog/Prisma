import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'package:gel_rule_app/core/http/app_headers.dart';

class DioClient {
  DioClient({
    String? baseUrl,
    Duration timeout = const Duration(seconds: 14),
    Map<String, String>? headers,
    Dio? dio,
  }) : dio = dio ?? Dio(_options(baseUrl, timeout, headers)) {
    if (dio == null && !kIsWeb) {
      this.dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = io.HttpClient();
          client.idleTimeout = const Duration(seconds: 120);
          client.maxConnectionsPerHost = 15;
          return client;
        },
      );
    }
    this.dio.interceptors.add(_RetryInterceptor(this.dio));
    if (kDebugMode) {
      this.dio.interceptors.add(
            LogInterceptor(
              requestBody: false,
              responseBody: false,
              requestHeader: false,
              responseHeader: false,
            ),
          );
    }
  }

  final Dio dio;

  static BaseOptions _options(
    String? baseUrl,
    Duration timeout,
    Map<String, String>? headers,
  ) {
    return BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      headers: {
        'User-Agent': AppHeaders.defaultUserAgent,
        'Accept': 'application/json, text/xml;q=0.9, */*;q=0.8',
        ...?headers,
      },
    );
  }

  void close({bool force = false}) => dio.close(force: force);
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxAttempts = 3;
  static const _maxRetryAfter = Duration(seconds: 15);

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final attempt = (options.extra['retryAttempt'] as int?) ?? 0;
    if (!_shouldRetry(err) ||
        attempt >= _maxAttempts ||
        // Retrying a streamed download from the interceptor re-issues the
        // request, but the original response body was already being piped
        // into the target file — the retry's stream is never consumed and
        // the transfer silently stalls. Download callers own their retry.
        options.responseType == ResponseType.stream) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_retryDelay(err, attempt));
    try {
      options.extra['retryAttempt'] = attempt + 1;
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: error,
        ),
      );
    }
  }

  Duration _retryDelay(DioException err, int attempt) {
    final retryAfter = _parseRetryAfter(err.response?.headers);
    if (retryAfter != null) return retryAfter;
    // Exponential backoff: if 429 Too Many Requests, wait longer (800ms, 1600ms, 3200ms)
    final isRateLimited = err.response?.statusCode == 429;
    final baseDelay = isRateLimited ? 800 : 350;
    return Duration(milliseconds: baseDelay * pow(2, attempt).toInt());
  }

  /// Honors the server's Retry-After hint (delay-seconds or HTTP-date) so
  /// rate-limited endpoints aren't hammered sooner than they ask for.
  /// Capped so a hostile or buggy header can't stall the pipeline for minutes.
  static Duration? _parseRetryAfter(Headers? headers) {
    final raw = headers?.value(io.HttpHeaders.retryAfterHeader);
    if (raw == null || raw.isEmpty) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds != null) {
      return Duration(seconds: seconds.clamp(0, _maxRetryAfter.inSeconds));
    }
    try {
      final retryAt = io.HttpDate.parse(raw.trim());
      final delta = retryAt.difference(DateTime.now());
      if (delta.isNegative) return Duration.zero;
      return delta < _maxRetryAfter ? delta : _maxRetryAfter;
    } on FormatException {
      return null;
    }
  }

  bool _shouldRetry(DioException error) {
    final status = error.response?.statusCode;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout ||
        status == 429 ||
        (status != null && status >= 500 && status != 501);
  }
}
