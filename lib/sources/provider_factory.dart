import 'dart:convert';

import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/booru/custom_provider.dart';
import 'package:gel_rule_app/sources/booru/danbooru_provider.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'package:gel_rule_app/sources/booru/gelbooru_provider.dart';
import 'package:gel_rule_app/sources/booru/moebooru_provider.dart';
import 'package:gel_rule_app/sources/booru/pawchive_provider.dart';
import 'package:gel_rule_app/sources/booru/realbooru_html_provider.dart';
import 'package:gel_rule_app/sources/booru/rule34_provider.dart';
import 'package:gel_rule_app/sources/booru/rule34_paheal_provider.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:gel_rule_app/sources/booru/mangalib_provider.dart';
import 'package:gel_rule_app/sources/booru/ranobelib_provider.dart';
import 'package:gel_rule_app/sources/booru/pixiv_provider.dart';
import 'package:gel_rule_app/sources/booru/safebooru_provider.dart';

class ProviderFactory {
  final Map<String, DioClient> _clientCache = {};

  void clearCache() {
    _clientCache.clear();
  }

  ContentProvider create(ContentProviderConfig config) {
    final headers = Map<String, String>.from(config.customHeaders)
      ..removeWhere((key, _) => key.startsWith('query.'));
    final queryParameters = {
      for (final entry in config.customHeaders.entries)
        if (entry.key.startsWith('query.') && entry.value.trim().isNotEmpty)
          entry.key.substring('query.'.length): entry.value.trim(),
    };

    if (config.apiType.toLowerCase() == 'e621') {
      final login = queryParameters['login'] ?? headers['login'];
      final apiKey = queryParameters['api_key'] ?? headers['api_key'];
      if (login != null && apiKey != null && login.isNotEmpty && apiKey.isNotEmpty) {
        final basicAuth = base64Encode(utf8.encode('$login:$apiKey'));
        headers['Authorization'] = 'Basic $basicAuth';
        headers['User-Agent'] = 'Prisma/3.6.6 (by $login on e621)';
      }
    } else if (config.apiType.toLowerCase() == 'pixiv') {
      headers.putIfAbsent('Referer', () => 'https://www.pixiv.net/');
      headers.putIfAbsent(
        'User-Agent',
        () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      );
    } else if (config.apiType.toLowerCase() == 'mangadex') {
      headers.putIfAbsent('Referer', () => 'https://mangadex.org/');
      headers.putIfAbsent(
        'User-Agent',
        () => 'Prisma/3.6.6 Flutter MangaDex Client',
      );
    }

    final clientKey =
        '${config.id}_${config.baseUrl}_${config.timeoutSeconds}_${headers.entries.map((e) => '${e.key}:${e.value}').join(';')}';
    final client = _clientCache.putIfAbsent(
      clientKey,
      () => DioClient(
        baseUrl: config.baseUrl,
        timeout: Duration(seconds: config.timeoutSeconds),
        headers: headers,
      ),
    );
    switch (config.apiType.toLowerCase()) {
      case 'mangadex':
        return MangaDexProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'mangalib':
        return MangaLibProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'ranobelib':
        return RanobeLibProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'pixiv':
        // Read PHPSESSID from customHeaders (key 'phpsessid' or 'PHPSESSID')
        final phpsessid = config.customHeaders['phpsessid'] ??
            config.customHeaders['PHPSESSID'];
        return PixivProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
          phpsessid: phpsessid?.isNotEmpty == true ? phpsessid : null,
        );
      case 'gelbooru':
        return GelbooruProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'rule34':
        return Rule34Provider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'safebooru':
        return SafebooruProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'paheal':
      case 'rule34_paheal':
        return Rule34PahealProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
        );
      case 'realbooru':
      case 'realbooru_html':
        return RealbooruHtmlProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
        );
      case 'danbooru':
        return DanbooruProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'moebooru':
        return MoebooruProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'e621':
        return E621Provider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      case 'pawchive':
        return PawchiveProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          dioClient: client,
          queryParameters: queryParameters,
        );
      default:
        return UnsupportedCustomProvider(
          id: config.id,
          name: config.name,
          baseUrl: config.baseUrl,
          apiType: config.apiType,
        );
    }
  }
}
