import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/danbooru_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

ContentProviderConfig config({
  String baseUrl = 'https://danbooru.donmai.us',
  int timeout = 15,
  Map<String, String> headers = const {},
}) {
  return ContentProviderConfig(
    id: 'danbooru',
    name: 'Danbooru',
    baseUrl: baseUrl,
    apiType: 'danbooru',
    enabled: true,
    priority: 1,
    timeoutSeconds: timeout,
    customHeaders: headers,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  test('create() memoizes instances for identical configs', () {
    final factory = ProviderFactory();
    final c = config();
    final a = factory.create(c);
    final b = factory.create(c);
    expect(identical(a, b), isTrue,
        reason: 'instance-level caches must survive manager round-trips');
    expect(a, isA<DanbooruProvider>());
    factory.dispose();
  });

  test('a changed config yields a fresh instance', () {
    final factory = ProviderFactory();
    final a = factory.create(config());
    final b = factory.create(config(timeout: 30));
    expect(identical(a, b), isFalse);
    factory.dispose();
  });

  test('clearCache() drops memoized instances', () {
    final factory = ProviderFactory();
    final a = factory.create(config());
    factory.clearCache();
    final b = factory.create(config());
    expect(identical(a, b), isFalse);
    factory.dispose();
  });
}
