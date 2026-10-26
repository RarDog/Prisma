import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:prisma_app/core/http/app_headers.dart';

import 'package:prisma_app/core/errors/app_exception.dart';
import 'package:prisma_app/core/http/dio_client.dart';
import 'package:prisma_app/sources/mappers/gelbooru_mapper.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/models/post_comment.dart';
import 'package:prisma_app/core/models/provider_health.dart';
import 'package:prisma_app/core/models/tag_suggestion.dart';
import 'package:prisma_app/core/models/top_period_filter.dart';
import 'package:prisma_app/sources/interfaces/content_provider.dart';

class GelbooruProvider
    implements
        ContentProvider,
        CommentProvider,
        TagSuggestionProvider,
        TagMetadataProvider,
        PostPageProvider,
        MediaHeadersProvider {
  GelbooruProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
  })  : _queryParameters = queryParameters,
        _dio = dioClient.dio;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;
  final Map<String, String> _queryParameters;
  Dio get dio => _dio;
  Map<String, String> get queryParameters => _queryParameters;

  @override
  String postPageUrl(Post post) =>
      '$baseUrl/index.php?page=post&s=view&id=${post.id}';

  /// Builds a Gelbooru-DAPI query against `/index.php`.
  ///
  /// Provider-specific `queryParameters` are merged last so they can
  /// override the DAPI defaults.
  Map<String, Object?> dapiQuery(
    String s, {
    Map<String, Object?> params = const {},
  }) {
    return {
      'page': 'dapi',
      's': s,
      'q': 'index',
      'json': '1',
      ...params,
      ..._queryParameters,
    };
  }

  /// Extra tags appended to search queries for the given top-period filter.
  List<String> topTagsFor(TopPeriodFilter period) {
    return switch (period) {
      TopPeriodFilter.allTime => const ['sort:score:desc'],
      _ => const [],
    };
  }

  /// Parses `autocomplete.php` responses shared by Gelbooru-family endpoints.
  ///
  /// Items look like `{"label": "tag (1234)", "value": "tag"}`: the label
  /// carries the display name with an optional post count, the value the raw
  /// tag. The raw tag is preferred; the label is used when it is missing.
  List<TagSuggestion> suggestionsFromAutocomplete(
    dynamic data, {
    required int limit,
  }) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('[')) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {}
      }
    }
    if (data is! List) return const [];
    final labelRegExp = RegExp(r'^(.*?)\s*\((\d+)\)$');
    final suggestions = <TagSuggestion>[];
    for (final item in data) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final label = (json['label'] ?? '').toString();
      final value = (json['value'] ?? '').toString();
      final match = labelRegExp.firstMatch(label);
      final name = (value.isNotEmpty ? value : (match?.group(1) ?? '')).trim();
      if (name.isEmpty) continue;
      suggestions.add(
        TagSuggestion(
          name: name,
          postCount: int.tryParse(match?.group(2) ?? '') ?? 0,
          category: TagCategory.general,
          providerId: id,
        ),
      );
      if (suggestions.length >= limit) break;
    }
    return suggestions;
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    final host = Uri.tryParse(baseUrl)?.host;
    return AppHeaders.mediaHeaders(
      referer: (host != null && host.isNotEmpty) ? '$baseUrl/' : null,
    );
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    final queryTags = [
      ...tags,
      if (rating != null && rating.isNotEmpty) 'rating:$rating',
      ...topTagsFor(topPeriod),
    ];
    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('post', params: {
          'pid': page,
          'limit': limit,
          'tags': queryTags.join(' '),
        }),
        cancelToken: cancelToken,
      );
      _checkResponse(response);
      return GelbooruMapper.postsFromResponse(
        response.data,
        providerId: id,
        providerName: name,
        baseUrl: baseUrl,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('post', params: {'id': id}),
      );
      _checkResponse(response);
      final posts = GelbooruMapper.postsFromResponse(
        response.data,
        providerId: this.id,
        providerName: name,
        baseUrl: baseUrl,
      );
      return posts.isEmpty ? null : posts.first;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      await _dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('post', params: {'limit': 1}),
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.online,
        pingMs: sw.elapsedMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'gelbooru-compatible',
      );
    } on DioException catch (dioErr) {
      sw.stop();
      if (dioErr.response?.statusCode == 401) {
        try {
          final ping = await _dio.get<dynamic>(
            '/index.php',
            queryParameters: {'page': 'post', 's': 'list'},
            options: Options(
              responseType: ResponseType.plain,
              receiveTimeout: const Duration(seconds: 6),
              sendTimeout: const Duration(seconds: 5),
            ),
          );
          if ((ping.statusCode ?? 500) < 400) {
            final hasKey = _queryParameters.containsKey('api_key') ||
                _queryParameters.containsKey('user_id');
            return ProviderHealth(
              providerId: id,
              status: hasKey ? ProviderStatus.offline : ProviderStatus.online,
              pingMs: hasKey ? 0 : sw.elapsedMilliseconds,
              lastCheckedAt: DateTime.now(),
              errorMessage: hasKey
                  ? 'Неверный API-ключ или User ID'
                  : 'Требуется API-ключ в настройках',
              apiVersion: 'gelbooru-auth-required',
            );
          }
        } catch (_) {}
      }
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: dioErr.message ?? dioErr.toString(),
        apiVersion: 'gelbooru-compatible',
      );
    } catch (error) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'gelbooru-compatible',
      );
    }
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('comment', params: {'post_id': postId}),
      );
      return _commentsFromResponse(response.data, postId);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('tag', params: {
          'name_pattern': '$trimmed%',
          'orderby': 'count',
          'order': 'DESC',
          'limit': limit.clamp(1, 100),
        }),
      );
      return _tagItems(response.data)
          .whereType<Map>()
          .map((item) {
            final json = Map<String, dynamic>.from(item);
            return TagSuggestion(
              name: (json['name'] ?? '').toString(),
              category: tagCategoryFromString(
                (json['type'] ?? json['tag_type'] ?? json['category'])
                    .toString(),
              ),
              postCount: _int(json['count'] ?? json['post_count']),
              providerId: id,
            );
          })
          .where((tag) => tag.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Map<String, List<String>>> categorizeTags(List<String> tags) async {
    final cleaned = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(80)
        .toList(growable: false);
    if (cleaned.isEmpty) return const {};

    final groups = <String, List<String>>{};
    final tagToCategory = <String, TagCategory>{};

    // Batch query tag metadata using Gelbooru DAPI "names" parameter
    try {
      for (var i = 0; i < cleaned.length; i += 50) {
        final chunk = cleaned.sublist(
          i,
          (i + 50 > cleaned.length) ? cleaned.length : i + 50,
        );
        final response = await _dio.get<dynamic>(
          '/index.php',
          queryParameters: dapiQuery('tag', params: {
            'names': chunk.join(' '),
            'limit': chunk.length.clamp(1, 100),
          }),
        );
        for (final item in _tagItems(response.data).whereType<Map>()) {
          final json = Map<String, dynamic>.from(item);
          final name = (json['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            tagToCategory[name] = tagCategoryFromString(
              (json['type'] ?? json['tag_type'] ?? json['category']).toString(),
            );
          }
        }
      }
    } catch (_) {
      // Gracefully continue to fallback categorization
    }

    for (final tag in cleaned) {
      final category = tagToCategory[tag] ?? TagCategory.general;
      final key = switch (category) {
        TagCategory.artist => 'artist',
        TagCategory.copyright => 'copyright',
        TagCategory.character => 'character',
        TagCategory.meta => 'meta',
        TagCategory.species => 'species',
        TagCategory.general || TagCategory.unknown => 'general',
      };
      groups.putIfAbsent(key, () => <String>[]).add(tag);
    }
    return groups;
  }

  void _checkResponse(Response<dynamic> response) {
    if (response.data is String) {
      final text = (response.data as String).toLowerCase();
      if (text.contains('throttled') ||
          text.contains('authentication required') ||
          text.contains('requires authentication')) {
        unavailable(
          '$name requires authentication or is throttled. '
          'Please configure API Key & User ID in Settings -> Providers.',
        );
      }
    }
  }

  Never _handleDioError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403 || status == 429) {
      unavailable(
        '$name requires authentication or rate limit exceeded ($status). '
        'Please enter your API Key and User ID in Settings -> Providers.',
      );
    }
    throw error;
  }

  Never unavailable(String message) =>
      throw ProviderUnavailableException(message);

  @override
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      };

  List<PostComment> _commentsFromResponse(dynamic data, String postId) {
    final raw = _commentItems(data);
    return raw
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          return PostComment(
            id: (json['id'] ?? json['comment_id'] ?? '').toString(),
            postId: (json['post_id'] ?? postId).toString(),
            providerId: id,
            authorName: (json['creator'] ??
                    json['creator_name'] ??
                    json['creator_id'] ??
                    json['user'] ??
                    json['username'] ??
                    json['author'] ??
                    '')
                .toString(),
            body: (json['body'] ??
                    json['comment'] ??
                    json['content'] ??
                    json['text'] ??
                    '')
                .toString(),
            createdAt: DateTime.tryParse(
                  (json['created_at'] ?? json['created'] ?? '').toString(),
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .where((comment) => comment.body.trim().isNotEmpty)
        .toList();
  }

  List<dynamic> _commentItems(dynamic data) {
    if (data is List) return data;
    if (data is String) return _commentItemsFromText(data);
    if (data is! Map) return const [];
    final json = Map<String, dynamic>.from(data);
    final comments = json['comments'];
    if (comments is List) return comments;
    if (comments is Map) return _commentItems(comments);
    final comment = json['comment'];
    if (comment is List) return comment;
    if (comment is Map) return [comment];
    return const [];
  }

  List<dynamic> _tagItems(dynamic data) {
    if (data is List) return data;
    if (data is String) return _tagItemsFromText(data);
    if (data is! Map) return const [];
    final json = Map<String, dynamic>.from(data);
    final tags = json['tag'] ?? json['tags'];
    if (tags is List) return tags;
    if (tags is Map && tags['tag'] is List) return tags['tag'] as List;
    if (tags is Map) return [tags];
    return const [];
  }

  List<Map<String, dynamic>> _tagItemsFromText(String text) {
    final items = <Map<String, dynamic>>[];
    for (final match
        in RegExp(r'<tag\b([^>]*)/?>', caseSensitive: false, dotAll: true)
            .allMatches(text)) {
      final attrs = _attributes(match.group(1) ?? '');
      if (attrs.isNotEmpty) items.add(attrs);
    }
    return items;
  }

  List<Map<String, dynamic>> _commentItemsFromText(String text) {
    final items = <Map<String, dynamic>>[];
    for (final match in RegExp(r'<comment\b([^>]*)>(.*?)</comment>',
            caseSensitive: false, dotAll: true)
        .allMatches(text)) {
      final attrs = _attributes(match.group(1) ?? '');
      final body = _tagValue(match.group(2) ?? '', 'body') ??
          _tagValue(match.group(2) ?? '', 'comment') ??
          match.group(2) ??
          '';
      items.add({...attrs, 'body': body});
    }
    for (final match
        in RegExp(r'<comment\b([^>]*)/?>', caseSensitive: false, dotAll: true)
            .allMatches(text)) {
      final attrs = _attributes(match.group(1) ?? '');
      if (attrs.isNotEmpty) items.add(attrs);
    }
    return items;
  }

  Map<String, dynamic> _attributes(String source) {
    final result = <String, dynamic>{};
    for (final match in RegExp(r'''([A-Za-z0-9_:-]+)\s*=\s*["']([^"']*)["']''')
        .allMatches(source)) {
      result[match.group(1)!] = _decodeEntities(match.group(2) ?? '');
    }
    return result;
  }

  String? _tagValue(String source, String tag) {
    final match =
        RegExp('<$tag[^>]*>(.*?)</$tag>', caseSensitive: false, dotAll: true)
            .firstMatch(source);
    final value = match?.group(1);
    return value == null ? null : _decodeEntities(value.trim());
  }

  String _decodeEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
