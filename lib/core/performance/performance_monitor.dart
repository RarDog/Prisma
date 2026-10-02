import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PerformanceMetrics {
  final int rssBytes;
  final int maxRssBytes;
  final int imageCacheBytes;
  final int imageCacheCount;
  final double cpuPercent;
  final double downloadSpeedBytesPerSec;
  final double uploadSpeedBytesPerSec;
  final int totalDownloadedBytes;
  final int totalUploadedBytes;
  final int fps;

  const PerformanceMetrics({
    this.rssBytes = 0,
    this.maxRssBytes = 0,
    this.imageCacheBytes = 0,
    this.imageCacheCount = 0,
    this.cpuPercent = 0.0,
    this.downloadSpeedBytesPerSec = 0.0,
    this.uploadSpeedBytesPerSec = 0.0,
    this.totalDownloadedBytes = 0,
    this.totalUploadedBytes = 0,
    this.fps = 60,
  });

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
}

class PerformanceNetworkTracker {
  static int totalDownloaded = 0;
  static int totalUploaded = 0;
  static int _bytesInWindow = 0;
  static int _uploadBytesInWindow = 0;
  static double currentDownloadSpeed = 0.0;
  static double currentUploadSpeed = 0.0;
  static DateTime _lastWindowTime = DateTime.now();

  static void recordDownload(int bytes) {
    totalDownloaded += bytes;
    _bytesInWindow += bytes;
  }

  static void recordUpload(int bytes) {
    totalUploaded += bytes;
    _uploadBytesInWindow += bytes;
  }

  static void tick() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastWindowTime).inMilliseconds;
    if (elapsedMs > 200) {
      currentDownloadSpeed = _bytesInWindow / (elapsedMs / 1000.0);
      currentUploadSpeed = _uploadBytesInWindow / (elapsedMs / 1000.0);
      _bytesInWindow = 0;
      _uploadBytesInWindow = 0;
      _lastWindowTime = now;
    }
  }
}

class PerformanceHttpOverrides extends HttpOverrides {
  PerformanceHttpOverrides({this.fallback});
  final HttpOverrides? fallback;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = fallback?.createHttpClient(context) ?? super.createHttpClient(context);
    return _TrackingHttpClient(client);
  }
}

class _TrackingHttpClient implements HttpClient {
  final HttpClient _inner;
  _TrackingHttpClient(this._inner);

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(Future<bool> Function(Uri url, String realm, String? account)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String realm, String? account)? f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final req = await _inner.open(method, host, port, path);
    return _TrackingHttpRequest(req);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final req = await _inner.openUrl(method, url);
    return _TrackingHttpRequest(req);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => open('GET', host, port, path);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => open('POST', host, port, path);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => open('PUT', host, port, path);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => open('DELETE', host, port, path);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => open('PATCH', host, port, path);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => open('HEAD', host, port, path);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
}

class _TrackingHttpRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  _TrackingHttpRequest(this._inner);

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  HttpHeaders get headers => _inner.headers;
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;
  @override
  List<Cookie> get cookies => _inner.cookies;
  @override
  Future<HttpClientResponse> get done => _inner.done.then((res) => _TrackingHttpResponse(res));
  @override
  String get method => _inner.method;
  @override
  Uri get uri => _inner.uri;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) => _inner.abort(exception, stackTrace);

  @override
  void add(List<int> data) {
    PerformanceNetworkTracker.recordUpload(data.length);
    _inner.add(data);
  }

  @override
  Future flush() => _inner.flush();

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) {
    return _inner.addStream(stream.map((data) {
      PerformanceNetworkTracker.recordUpload(data.length);
      return data;
    }));
  }

  @override
  Future<HttpClientResponse> close() async {
    final res = await _inner.close();
    return _TrackingHttpResponse(res);
  }

  @override
  void write(Object? object) {
    final str = object.toString();
    PerformanceNetworkTracker.recordUpload(str.length);
    _inner.write(str);
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    _inner.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    PerformanceNetworkTracker.recordUpload(1);
    _inner.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    final str = '$object\n';
    PerformanceNetworkTracker.recordUpload(str.length);
    _inner.writeln(object);
  }
}

class _TrackingHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  final HttpClientResponse _inner;
  _TrackingHttpResponse(this._inner);

  @override
  X509Certificate? get certificate => _inner.certificate;
  @override
  HttpClientResponseCompressionState get compressionState => _inner.compressionState;
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;
  @override
  int get contentLength => _inner.contentLength;
  @override
  List<Cookie> get cookies => _inner.cookies;
  @override
  Future<Socket> detachSocket() => _inner.detachSocket();
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  bool get isRedirect => _inner.isRedirect;
  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  String get reasonPhrase => _inner.reasonPhrase;
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) =>
      _inner.redirect(method, url, followLoops).then((r) => _TrackingHttpResponse(r));
  @override
  List<RedirectInfo> get redirects => _inner.redirects;
  @override
  int get statusCode => _inner.statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _inner.listen(
      (data) {
        PerformanceNetworkTracker.recordDownload(data.length);
        if (onData != null) onData(data);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class SmartMemoryManager with WidgetsBindingObserver {
  static final SmartMemoryManager instance = SmartMemoryManager._();
  SmartMemoryManager._();

  bool _initialized = false;
  DateTime _lastTrimTime = DateTime.now();

  void init() {
    if (_initialized) return;
    _initialized = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  @override
  void didHaveMemoryPressure() {
    trimMemory(force: true, reason: 'OS low memory pressure');
  }

  void checkAndTrim({required int currentRssBytes, required int imageCacheBytes}) {
    final now = DateTime.now();
    if (now.difference(_lastTrimTime).inSeconds < 5) return;

    // Thresholds: Process RAM > 450 MB or imageCache > 120 MB
    const int rssThreshold = 450 * 1024 * 1024;
    const int imageCacheThreshold = 120 * 1024 * 1024;

    if (currentRssBytes > rssThreshold || imageCacheBytes > imageCacheThreshold) {
      trimMemory(force: false, reason: 'RAM/Cache watchdog limit exceeded');
      _lastTrimTime = now;
    }
  }

  void trimMemory({bool force = false, String? reason}) {
    try {
      final cache = PaintingBinding.instance.imageCache;
      cache.clearLiveImages();
      if (force) {
        cache.clear();
      }
    } catch (_) {}
  }

  static void evictImageUrl(String url) {
    if (url.trim().isEmpty) return;
    try {
      CachedNetworkImageProvider(url).evict();
      NetworkImage(url).evict();
    } catch (_) {}
  }
}

class PerformanceMonitorService {
  PerformanceMonitorService() {
    _initFpsMonitoring();
  }

  static void init() {
    try {
      final existing = HttpOverrides.current;
      HttpOverrides.global = PerformanceHttpOverrides(fallback: existing);
      SmartMemoryManager.instance.init();
    } catch (_) {}
  }

  int _prevCpuTicks = 0;
  DateTime _prevCpuTime = DateTime.now();
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();
  int _currentFps = 60;

  void _initFpsMonitoring() {
    try {
      WidgetsBinding.instance.addTimingsCallback((timings) {
        _frameCount += timings.length;
        final now = DateTime.now();
        final elapsed = now.difference(_lastFpsTime).inMilliseconds;
        if (elapsed >= 1000) {
          _currentFps = (_frameCount * 1000 ~/ elapsed);
          _frameCount = 0;
          _lastFpsTime = now;
        }
      });
    } catch (_) {}
  }

  double _sampleCpu() {
    if (!Platform.isAndroid && !Platform.isLinux) return 0.0;
    try {
      final statContent = File('/proc/self/stat').readAsStringSync();
      final closeParenIndex = statContent.lastIndexOf(')');
      if (closeParenIndex == -1) return 0.0;

      final rest = statContent.substring(closeParenIndex + 2).trim().split(' ');
      if (rest.length < 13) return 0.0;

      final utime = int.parse(rest[11]);
      final stime = int.parse(rest[12]);
      final totalTicks = utime + stime;
      final now = DateTime.now();

      if (_prevCpuTicks == 0) {
        _prevCpuTicks = totalTicks;
        _prevCpuTime = now;
        return 0.0;
      }

      final elapsedMs = now.difference(_prevCpuTime).inMilliseconds;
      if (elapsedMs <= 0) return 0.0;

      final deltaTicks = totalTicks - _prevCpuTicks;
      _prevCpuTicks = totalTicks;
      _prevCpuTime = now;

      final percent = (deltaTicks / (elapsedMs / 1000.0 * 100.0)) * 100.0;
      return percent.clamp(0.0, (Platform.numberOfProcessors * 100).toDouble());
    } catch (_) {
      return 0.0;
    }
  }

  PerformanceMetrics collectMetrics() {
    PerformanceNetworkTracker.tick();

    int rss = 0;
    int maxRss = 0;
    try {
      rss = ProcessInfo.currentRss;
      maxRss = ProcessInfo.maxRss;
    } catch (_) {}

    int imageCacheBytes = 0;
    int imageCacheCount = 0;
    try {
      imageCacheBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
      imageCacheCount = PaintingBinding.instance.imageCache.currentSize;
    } catch (_) {}

    SmartMemoryManager.instance.checkAndTrim(
      currentRssBytes: rss,
      imageCacheBytes: imageCacheBytes,
    );

    final cpu = _sampleCpu();

    return PerformanceMetrics(
      rssBytes: rss,
      maxRssBytes: maxRss,
      imageCacheBytes: imageCacheBytes,
      imageCacheCount: imageCacheCount,
      cpuPercent: cpu,
      downloadSpeedBytesPerSec: PerformanceNetworkTracker.currentDownloadSpeed,
      uploadSpeedBytesPerSec: PerformanceNetworkTracker.currentUploadSpeed,
      totalDownloadedBytes: PerformanceNetworkTracker.totalDownloaded,
      totalUploadedBytes: PerformanceNetworkTracker.totalUploaded,
      fps: _currentFps,
    );
  }
}

final performanceMonitorServiceProvider = Provider<PerformanceMonitorService>((ref) {
  return PerformanceMonitorService();
});

final performanceMetricsStreamProvider = StreamProvider.autoDispose<PerformanceMetrics>((ref) {
  final service = ref.watch(performanceMonitorServiceProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => service.collectMetrics());
});
