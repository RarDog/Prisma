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

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['retryAttempt'] as int?) ?? 0;
    if (!_shouldRetry(err) || attempt >= _maxAttempts) {
      handler.next(err);
      return;
    }

    // Exponential backoff: if 429 Too Many Requests, wait longer (800ms, 1600ms, 3200ms)
    final isRateLimited = err.response?.statusCode == 429;
    final baseDelay = isRateLimited ? 800 : 350;
    final delayMs = baseDelay * pow(2, attempt).toInt();
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    try {
      final options = err.requestOptions;
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

  bool _shouldRetry(DioException error) {
    final status = error.response?.statusCode;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout ||
        status == 429 ||
        (status != null && status >= 500 && status != 501);
  }
}
