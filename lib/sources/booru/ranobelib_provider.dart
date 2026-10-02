import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/core/utils/logger.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class RanobeLibProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider,
        NovelChapterProvider {
  RanobeLibProvider({
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
  String get _apiBase {
    if (baseUrl.contains('cdnlibs.org')) {
      return baseUrl.endsWith('/api') ? baseUrl : '$baseUrl/api';
    }
    return 'https://api.cdnlibs.org/api';
  }

  Map<String, String> get _headers => AppHeaders.browserHeaders(
        siteId: '3',
        referer: 'https://ranobelib.me/',
        origin: 'https://ranobelib.me',
      );

  @override
  String postPageUrl(Post post) {
    return 'https://ranobelib.me/ru/${post.id}';
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    return AppHeaders.mediaHeaders(
      referer: 'https://ranobelib.me/',
      userAgent: AppHeaders.desktopChromeUserAgent,
      accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    );
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 24,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final targetPage = page + 1;
    final queryText = tags
        .where((t) => !t.startsWith('rating:') && !t.startsWith('lang:'))
        .join(' ')
        .trim();

    try {
      final queryParams = <String, dynamic>{
        'page': targetPage,
        'site_id[]': 3, // 3 = ranobelib
      };

      if (queryText.isNotEmpty) {
        queryParams['q'] = queryText;
      }

      if (topPeriod == TopPeriodFilter.day || topPeriod == TopPeriodFilter.week) {
        queryParams['sort_by'] = 'views';
        queryParams['sort_type'] = 'desc';
      } else {
        queryParams['sort_by'] = 'views';
        queryParams['sort_type'] = 'desc';
      }

      final uri = '$_apiBase/manga';
      final response = await _dio.get(
        uri,
        queryParameters: queryParams,
        options: Options(
          headers: _headers,
        ),
      );

      final data = response.data;
      if (data == null) return [];

      final items = data is Map ? (data['data'] as List<dynamic>? ?? []) : (data is List ? data : []);
      final posts = <Post>[];

      for (final raw in items) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final slug = map['slug']?.toString() ?? map['id']?.toString() ?? '';
        final slugUrl = map['slug_url']?.toString() ?? slug;
        if (slugUrl.isEmpty) continue;

        final rusName = map['rus_name']?.toString() ?? '';
        final engName = map['eng_name']?.toString() ?? map['name']?.toString() ?? '';
        final title = rusName.isNotEmpty ? rusName : engName;

        final coverMap = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
        final coverUrl = coverMap?['default']?.toString() ??
            coverMap?['thumbnail']?.toString() ??
            'https://cover.cdnlibs.org/uploads/cover/$slug/cover/cover.jpg';

        final genres = <String>['ranobe', 'novel'];
        if (map['genres'] is List) {
          for (final g in map['genres'] as List) {
            if (g is Map && g['name'] != null) {
              genres.add(g['name'].toString().toLowerCase().replaceAll(' ', '_'));
            }
          }
        }

        posts.add(
          Post(
            id: slugUrl,
            providerId: id,
            providerName: name,
            fileType: 'txt',
            previewUrl: coverUrl,
            sampleUrl: coverUrl,
            fileUrl: coverUrl,
            width: 400,
            height: 600,
            tags: [
              ...genres,
              if (rusName.isNotEmpty) rusName.toLowerCase().replaceAll(' ', '_'),
              if (engName.isNotEmpty) engName.toLowerCase().replaceAll(' ', '_'),
            ],
            rating: 's',
            score: (double.tryParse(map['rating']?['average']?.toString() ?? '0') ?? 0).round(),
            source: 'https://ranobelib.me/ru/$slugUrl',
            createdAt: DateTime.now(),
            tagGroups: {
              'general': genres,
              'title': [title],
              'type': ['novel'],
              if (rusName.isNotEmpty) 'rus_title': [rusName],
              if (engName.isNotEmpty) 'eng_title': [engName],
              if (map['summary'] != null) 'description': [map['summary'].toString()],
            },
          ),
        );
      }

      return posts;
    } on DioException catch (e) {
      throw BadResponseException(e.message ?? 'RanobeLib API error', details: e.toString());
    }
  }

  @override
  Future<Post?> getPost(String postId) async {
    try {
      final response = await _dio.get(
        '$_apiBase/manga/$postId',
        queryParameters: {
          'fields[]': ['summary', 'genres', 'authors'],
        },
        options: Options(
          headers: _headers,
        ),
      );
      final data = response.data;
      if (data == null || data is! Map) return null;
      final map = Map<String, dynamic>.from(data['data'] is Map ? data['data'] as Map : data);

      final slug = map['slug']?.toString() ?? postId;
      final slugUrl = map['slug_url']?.toString() ?? slug;
      final rusName = map['rus_name']?.toString() ?? '';
      final engName = map['eng_name']?.toString() ?? map['name']?.toString() ?? '';
      final title = rusName.isNotEmpty ? rusName : engName;

      final coverMap = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
      final coverUrl = coverMap?['default']?.toString() ??
          coverMap?['thumbnail']?.toString() ??
          'https://cover.cdnlibs.org/uploads/cover/$slug/cover/cover.jpg';

      final genres = <String>['ranobe', 'novel'];
      if (map['genres'] is List) {
        for (final g in map['genres'] as List) {
          if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString().toLowerCase().replaceAll(' ', '_'));
          }
        }
      }

      final summary = map['summary']?.toString() ?? '';

      return Post(
        id: slugUrl,
        providerId: id,
        providerName: name,
        fileType: 'txt',
        previewUrl: coverUrl,
        sampleUrl: coverUrl,
        fileUrl: coverUrl,
        width: 400,
        height: 600,
        tags: genres,
        rating: 's',
        score: (double.tryParse(map['rating']?['average']?.toString() ?? '0') ?? 0).round(),
        source: 'https://ranobelib.me/ru/$slugUrl',
        createdAt: DateTime.now(),
        tagGroups: {
          'general': genres,
          'title': [title],
          'type': ['novel'],
          if (rusName.isNotEmpty) 'rus_title': [rusName],
          if (engName.isNotEmpty) 'eng_title': [engName],
          if (summary.isNotEmpty) 'description': [summary],
        },
      );
    } catch (e, st) {
      AppLogger.log('RanobeLibProvider._parseNovelItem error', e, st);
      return null;
    }
  }

  @override
  Future<List<MangaDexChapter>> fetchChapters(String novelId) async {
    try {
      final response = await _dio.get(
        '$_apiBase/manga/$novelId/chapters',
        options: Options(
          headers: _headers,
        ),
      );

      final data = response.data;
      if (data == null) return [];
      final list = data is Map ? (data['data'] as List<dynamic>? ?? []) : (data is List ? data : []);

      final chapters = <MangaDexChapter>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final chNumber = map['number']?.toString() ?? '1';
        final volume = map['volume']?.toString() ?? '1';
        final rawTitle = map['name']?.toString() ?? '';
        final title = rawTitle.isNotEmpty ? rawTitle : 'Глава $chNumber';

        // Check if there is a branch_id
        String? branchId;
        if (map['branches'] is List && (map['branches'] as List).isNotEmpty) {
          final firstBranch = (map['branches'] as List).first;
          if (firstBranch is Map && firstBranch['branch_id'] != null) {
            branchId = firstBranch['branch_id'].toString();
          }
        }

        final chId = branchId != null
            ? '$novelId:$volume:$chNumber:$branchId'
            : '$novelId:$volume:$chNumber';

        chapters.add(
          MangaDexChapter(
            id: chId,
            chapterNumber: chNumber,
            title: title,
            language: 'ru',
            pageCount: 0,
            volumeNumber: volume,
            textContent: '', // to be loaded by fetchChapterContent
          ),
        );
      }

      return chapters;
    } catch (e, st) {
      AppLogger.log('RanobeLibProvider.fetchChapters error for $novelId', e, st);
      return [];
    }
  }

  @override
  Future<String> fetchChapterContent(String chapterId) async {
    try {
      final parts = chapterId.split(':');
      final novelSlug = parts[0];
      final volume = parts.length > 1 ? parts[1] : '1';
      final number = parts.length > 2 ? parts[2] : '1';
      final branchId = parts.length > 3 ? parts[3] : null;

      final queryParams = <String, dynamic>{
        'volume': volume,
        'number': number,
      };
      if (branchId != null && branchId.isNotEmpty) {
        queryParams['branch_id'] = branchId;
      }

      Response response;
      try {
        response = await _dio.get(
          '$_apiBase/manga/$novelSlug/chapter',
          queryParameters: queryParams,
          options: Options(
            headers: _headers,
          ),
        );
      } on DioException {
        // If query with branch_id failed, retry without branch_id
        if (queryParams.containsKey('branch_id')) {
          final fallbackParams = Map<String, dynamic>.from(queryParams)..remove('branch_id');
          response = await _dio.get(
            '$_apiBase/manga/$novelSlug/chapter',
            queryParameters: fallbackParams,
            options: Options(
              headers: _headers,
            ),
          );
        } else {
          rethrow;
        }
      }

      final data = response.data;
      if (data == null || data is! Map) return '';
      final chapterData = data['data'] is Map ? data['data'] as Map : data;
      final rawContent = chapterData['content'] ?? chapterData['text'];

      String parsed = '';
      if (rawContent is Map || rawContent is List) {
        parsed = _parseProseMirror(rawContent);
      } else if (rawContent is String) {
        parsed = _cleanHtml(rawContent);
      }

      // Check if there are attachments (e.g. illustrations)
      final attachments = chapterData['attachments'] as List<dynamic>? ?? [];
      final imageAttachmentUrls = <String>[];
      for (final att in attachments) {
        if (att is Map && att['url'] != null) {
          final rawUrl = att['url'].toString();
          final fullUrl = rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
              ? rawUrl
              : (rawUrl.startsWith('/') ? 'https://ranobelib.me$rawUrl' : 'https://ranobelib.me/$rawUrl');
          imageAttachmentUrls.add(fullUrl);
        }
      }

      // If text is empty (e.g. initial illustrations chapter) or has attachments:
      if (parsed.isEmpty && imageAttachmentUrls.isNotEmpty) {
        parsed = imageAttachmentUrls.map((u) => '![illustration]($u)').join('\n\n');
      }

      return parsed.trim();
    } catch (e, st) {
      AppLogger.log('RanobeLib fetchChapterContent error for $chapterId', e, st);
      return '';
    }
  }

  String _parseProseMirror(dynamic doc) {
    if (doc == null) return '';
    final buffer = StringBuffer();

    void traverse(dynamic node) {
      if (node == null) return;
      if (node is String) {
        buffer.write(node);
        return;
      }
      if (node is List) {
        for (final item in node) {
          traverse(item);
        }
        return;
      }
      if (node is! Map) return;

      final type = node['type']?.toString();
      final content = node['content'];
      final text = node['text']?.toString();
      final attrs = node['attrs'] is Map ? (node['attrs'] as Map) : null;

      if (text != null && text.isNotEmpty) {
        buffer.write(text);
      } else if (type == 'image') {
        final src = attrs?['src']?.toString() ?? attrs?['url']?.toString();
        if (src != null && src.isNotEmpty) {
          final fullSrc = src.startsWith('http://') || src.startsWith('https://')
              ? src
              : (src.startsWith('/') ? 'https://ranobelib.me$src' : 'https://ranobelib.me/$src');
          buffer.write('\n\n![illustration]($fullSrc)\n\n');
        }
      } else if (type == 'hardBreak') {
        buffer.write('\n');
      }

      if (content != null) {
        traverse(content);
      }

      if (type == 'paragraph' ||
          type == 'heading' ||
          type == 'blockquote' ||
          type == 'listItem') {
        buffer.write('\n\n');
      }
    }

    traverse(doc);
    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAllMapped(
          RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''', caseSensitive: false),
          (match) {
            final src = match.group(1) ?? '';
            return '\n\n![illustration]($src)\n\n';
          },
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '');
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '', radix: 16);
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final posts = await searchPosts(tags: [query], page: 0, limit: limit);
      return posts.map((p) {
        final title = p.tagGroups['title']?.firstOrNull ?? p.id;
        return TagSuggestion(
          name: title,
          category: TagCategory.copyright,
          postCount: p.score,
          providerId: id,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      final res = await _dio.get<dynamic>(
        '$baseUrl/api/manga?site_id[]=3&page=1&limit=1',
        options: Options(
          headers: AppHeaders.browserHeaders(
            referer: 'https://ranobelib.me/',
          ),
        ),
      );
      final ok = res.statusCode == 200;
      return ProviderHealth(
        providerId: id,
        status: ok ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
      );
    } catch (e) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }
}
