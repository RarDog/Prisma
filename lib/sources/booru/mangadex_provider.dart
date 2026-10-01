import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/mappers/mangadex_mapper.dart';

class MangaDexChapter {
  const MangaDexChapter({
    required this.id,
    required this.chapterNumber,
    required this.title,
    required this.language,
    required this.pageCount,
    this.externalUrl,
  });

  final String id;
  final String chapterNumber;
  final String title;
  final String language;
  final int pageCount;
  final String? externalUrl;

  bool get isExternal => externalUrl != null && externalUrl!.isNotEmpty;
}

class MangaLanguageHelper {
  static String name(String code) {
    return switch (code.toLowerCase()) {
      'ru' => 'Русский',
      'en' => 'English',
      'ja' => '日本語',
      'es' || 'es-la' => 'Español',
      'pt' || 'pt-br' => 'Português',
      'fr' => 'Français',
      'de' => 'Deutsch',
      'it' => 'Italiano',
      'uk' => 'Українська',
      'ko' => '한국어',
      'zh' || 'zh-hk' || 'zh-ro' => '中文',
      'vi' => 'Tiếng Việt',
      'id' => 'Bahasa Indonesia',
      'tr' => 'Türkçe',
      'pl' => 'Polski',
      'th' => 'ไทย',
      'ar' => 'العربية',
      _ => code.toUpperCase(),
    };
  }

  static String flag(String code) {
    return switch (code.toLowerCase()) {
      'ru' => '🇷🇺',
      'en' => '🇬🇧',
      'ja' => '🇯🇵',
      'es' || 'es-la' => '🇪🇸',
      'pt' || 'pt-br' => '🇧🇷',
      'fr' => '🇫🇷',
      'de' => '🇩🇪',
      'it' => '🇮🇹',
      'uk' => '🇺🇦',
      'ko' => '🇰🇷',
      'zh' || 'zh-hk' || 'zh-ro' => '🇨🇳',
      'vi' => '🇻🇳',
      'id' => '🇮🇩',
      'tr' => '🇹🇷',
      'pl' => '🇵🇱',
      'th' => '🇹🇭',
      'ar' => '🇸🇦',
      _ => '🌐',
    };
  }
}

const Map<String, String> _kMangaDexTagIds = {
  'Oneshot': '0234a31e-a729-4e28-9d6a-3f87c4966b9e',
  'Thriller': '07251805-a27e-4d59-b488-f0bfbec15168',
  'Award Winning': '0a39b5a1-b235-4886-a747-1d05d216532d',
  'Reincarnation': '0bc90acb-ccc1-44ca-a34a-b9f3a73259d0',
  'Sci-Fi': '256c8bd9-4904-4360-bf4f-508a76d67183',
  'Time Travel': '292e862b-2d17-4062-90a2-0356caa4ae27',
  'Genderswap': '2bd2e8d0-f146-434a-9b51-fc9ff2c5fe6a',
  'Loli': '2d1f5d56-a1e5-4d0d-a961-2193588b08ec',
  'Traditional Games': '31932a7e-5b8e-49a6-9f12-2afa39dc544c',
  'Official Colored': '320831a8-4026-470b-94f6-8353740e6f04',
  'Historical': '33771934-028e-4cb3-8744-691e866a923e',
  'Monsters': '36fd93ea-e8b8-445e-b836-358f02b3d33d',
  'Action': '391b0423-d847-456f-aff0-8b0cfc03066b',
  'Demons': '39730448-9a5f-48a2-85b0-a70db87b1233',
  'Psychological': '3b60b75c-a2d7-4860-ab56-05f391bb889c',
  'Ghosts': '3bb26d85-09d5-4d2e-880c-c34b974339e9',
  'Animals': '3de8c75d-8ee3-48ff-98ee-e20a65c86451',
  'Long Strip': '3e2b8dae-350e-4ab8-a8ce-016e844b9f0d',
  'Romance': '423e2eae-a7a2-4a8b-ac03-a8351462d71d',
  'Ninja': '489dd859-9b61-4c37-af75-5b18e88daafc',
  'Comedy': '4d32cc48-9f00-4cca-9b5a-a839f0764984',
  'Mecha': '50880a9d-5440-4732-9afb-8f457127e836',
  'Anthology': '51d83883-4103-437c-b4b1-731cb73d786c',
  "Boys' Love": '5920b825-4181-4a17-beeb-9918b0ff7a30',
  'Incest': '5bd0e105-4481-44ca-b6e7-7544da56b1a3',
  'Crime': '5ca48985-9a9d-4bd8-be29-80dc0303db72',
  'Survival': '5fff9cde-849c-4d78-aab0-0d52b2ee1d25',
  'Zombies': '631ef465-9aba-4afb-b0fc-ea10efe274a8',
  'Reverse Harem': '65761a2a-415e-47f3-bef2-a9dababba7a6',
  'Sports': '69964a64-2f90-4d33-beeb-f3ed2875eb4c',
  'Superhero': '7064a261-a137-4d3a-8848-2d385de3a99c',
  'Martial Arts': '799c202e-7daa-44eb-9cf7-8a3c0441531e',
  'Fan Colored': '7b2ce280-79ef-4c09-9b58-12b7c23a9b78',
  'Samurai': '81183756-1453-4c81-aa9e-f6e1b63be016',
  'Magical Girls': '81c836c9-914a-4eca-981a-560dad663e73',
  'Mafia': '85daba54-a71c-4554-8a28-9901a8b0afad',
  'Adventure': '87cc87cd-a395-47af-b27a-93258283bbc6',
  'Self-Published': '891cf039-b895-47f0-9229-bef4c96eccd4',
  'Virtual Reality': '8c86611e-fab7-4986-9dec-d1a2f44acdd5',
  'Office Workers': '92d6d951-ca5e-429c-ac78-451071cbf064',
  'Video Games': '9438db5a-7e2a-4ac0-b39e-e0d95a34b8a8',
  'Post-Apocalyptic': '9467335a-1b83-4497-9231-765337a00b96',
  'Sexual Violence': '97893a4c-12af-4dac-b6be-0dffb353568e',
  'Crossdressing': '9ab53f92-3eed-4e9b-903a-917c86035ee3',
  'Magic': 'a1f53773-c69a-4ce5-8cab-fffcd90b1565',
  "Girls' Love": 'a3c67850-4684-404e-9b7f-c69850ee5da6',
  'Harem': 'aafb99c1-7f60-43fa-b75f-fc9502ce29c7',
  'Military': 'ac72833b-c4e9-4878-b9db-6c8a4a99444a',
  'Wuxia': 'acc803a4-c95a-4c22-86fc-eb6b582d82a2',
  'Isekai': 'ace04997-f6bd-436e-b261-779182193d3d',
  '4-Koma': 'b11fda93-8f1d-4bef-b2ed-8803d3733170',
  'Doujinshi': 'b13b2a48-c720-44a9-9c77-39c9979373fb',
  'Philosophical': 'b1e97889-25b4-4258-b28b-cd7f4d28ea9b',
  'Gore': 'b29d6a3d-1569-4e7a-8caf-7557bc92cd5d',
  'Drama': 'b9af3a63-f058-46de-a9a0-e0c13906197a',
  'Medical': 'c8cbe35b-1b2b-4a3f-9c37-db84c4514856',
  'School Life': 'caaa44eb-cd40-4177-b930-79d3ef2afe87',
  'Mahjong': 'cb562697-929f-4d28-9d66-6d3995bf2592',
  'Horror': 'cdad7e68-1419-41dd-bdce-27753074a640',
  'Fantasy': 'cdc58593-87dd-415e-bbc0-2ec27bf404cc',
  'Villainess': 'd14322ac-4d6f-4e9b-afd9-629d5f4d8a41',
  'Vampires': 'd7d1730f-6eb0-4ba6-9437-602cac38664c',
  'Delinquents': 'da2d50ca-3018-4cc0-ac7a-6b7d472a29ea',
  'Monster Girls': 'dd1f77c5-dea9-4e2b-97ae-224af09caf99',
  'Shota': 'ddefd648-5140-4e5f-ba18-4eca4071d19b',
  'Police': 'df33b754-73a3-4c54-80e6-1a74a8058539',
  'Web Comic': 'e197df38-d0e7-43b5-9b09-2842d0c326dd',
  'Slice of Life': 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9',
  'Aliens': 'e64f6742-c834-471d-8d72-dd51fc02b835',
  'Cooking': 'ea2bc92d-1c26-4930-9b7c-d5c0dc1b6869',
  'Supernatural': 'eabc5b4c-6aff-42f3-b657-3e90cbd00b75',
  'Mystery': 'ee968100-4191-4968-93d3-f82d72be7e46',
  'Adaptation': 'f4122d1c-3b44-44d0-9936-ff7502c39ad3',
  'Music': 'f42fbf9e-188a-447b-9fdc-f19dc1e4d685',
  'Full Color': 'f5ba408b-0e7a-484d-8d49-4e9125ac96de',
  'Tragedy': 'f8f62932-27da-4fe4-8ee1-6779a8c5edba',
  'Gyaru': 'fad12b5e-68ba-460e-b933-9ae8318f5b65',
};

const Map<String, String> _kMangaDexTagGroups = {
  'Oneshot': 'format',
  'Thriller': 'genre',
  'Award Winning': 'format',
  'Reincarnation': 'theme',
  'Sci-Fi': 'genre',
  'Time Travel': 'theme',
  'Genderswap': 'theme',
  'Loli': 'theme',
  'Traditional Games': 'theme',
  'Official Colored': 'format',
  'Historical': 'genre',
  'Monsters': 'theme',
  'Action': 'genre',
  'Demons': 'theme',
  'Psychological': 'genre',
  'Ghosts': 'theme',
  'Animals': 'theme',
  'Long Strip': 'format',
  'Romance': 'genre',
  'Ninja': 'theme',
  'Comedy': 'genre',
  'Mecha': 'genre',
  'Anthology': 'format',
  "Boys' Love": 'genre',
  'Incest': 'theme',
  'Crime': 'genre',
  'Survival': 'theme',
  'Zombies': 'theme',
  'Reverse Harem': 'theme',
  'Sports': 'genre',
  'Superhero': 'genre',
  'Martial Arts': 'theme',
  'Fan Colored': 'format',
  'Samurai': 'theme',
  'Magical Girls': 'genre',
  'Mafia': 'theme',
  'Adventure': 'genre',
  'Self-Published': 'format',
  'Virtual Reality': 'theme',
  'Office Workers': 'theme',
  'Video Games': 'theme',
  'Post-Apocalyptic': 'theme',
  'Sexual Violence': 'content',
  'Crossdressing': 'theme',
  'Magic': 'theme',
  "Girls' Love": 'genre',
  'Harem': 'theme',
  'Military': 'theme',
  'Wuxia': 'genre',
  'Isekai': 'genre',
  '4-Koma': 'format',
  'Doujinshi': 'format',
  'Philosophical': 'genre',
  'Gore': 'content',
  'Drama': 'genre',
  'Medical': 'genre',
  'School Life': 'theme',
  'Mahjong': 'theme',
  'Horror': 'genre',
  'Fantasy': 'genre',
  'Villainess': 'theme',
  'Vampires': 'theme',
  'Delinquents': 'theme',
  'Monster Girls': 'theme',
  'Shota': 'theme',
  'Police': 'theme',
  'Web Comic': 'format',
  'Slice of Life': 'genre',
  'Aliens': 'theme',
  'Cooking': 'theme',
  'Supernatural': 'theme',
  'Mystery': 'genre',
  'Adaptation': 'format',
  'Music': 'theme',
  'Full Color': 'format',
  'Tragedy': 'genre',
  'Gyaru': 'theme',
};

class MangaDexProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider {
  MangaDexProvider({
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
  final Map<String, String> _authorIdCache = {};

  Dio get dio => _dio;
  Map<String, String> get queryParameters => _queryParameters;

  @override
  String postPageUrl(Post post) {
    return 'https://mangadex.org/title/${post.id}';
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    return const {
      'User-Agent': 'Prisma/3.6.6 Flutter MangaDex Client',
      'Referer': 'https://mangadex.org/',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
  }

  Future<String?> _resolveAuthorId(String name) async {
    final clean = name.trim().toLowerCase();
    if (_authorIdCache.containsKey(clean)) {
      return _authorIdCache[clean];
    }
    try {
      final res = await _dio.get<dynamic>(
        '/author',
        queryParameters: {
          'name': name.trim(),
          'limit': 1,
        },
      );
      if (res.data is Map && res.data['data'] is List && (res.data['data'] as List).isNotEmpty) {
        final first = (res.data['data'] as List).first;
        if (first is Map && first['id'] != null) {
          final id = first['id'].toString();
          _authorIdCache[clean] = id;
          return id;
        }
      }
    } catch (_) {}
    return null;
  }

  String? _findTagId(String name) {
    final clean = name.trim().toLowerCase();
    for (final entry in _kMangaDexTagIds.entries) {
      if (entry.key.toLowerCase() == clean) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 25,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final offset = page * limit;

    final cleanedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !t.startsWith('rating:'))
        .toList();

    List<String> contentRatings = const ['safe', 'suggestive', 'erotica', 'pornographic'];
    if (rating != null && rating.isNotEmpty && rating.toLowerCase() != 'all') {
      final r = rating.toLowerCase();
      if (r == 'safe' || r == 'g') {
        contentRatings = const ['safe'];
      } else if (r == 'suggestive' || r == 's') {
        contentRatings = const ['suggestive'];
      } else if (r == 'erotica' || r == 'q') {
        contentRatings = const ['erotica'];
      } else if (r == 'pornographic' || r == 'e') {
        contentRatings = const ['pornographic'];
      }
    }

    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'includes[]': ['cover_art', 'author', 'artist'],
      'contentRating[]': contentRatings,
      ..._queryParameters,
    };

    if (topPeriod != TopPeriodFilter.none) {
      queryParams['order[followedCount]'] = 'desc';
      final now = DateTime.now().toUtc();
      DateTime? since;
      switch (topPeriod) {
        case TopPeriodFilter.day:
          since = now.subtract(const Duration(days: 1));
          break;
        case TopPeriodFilter.week:
          since = now.subtract(const Duration(days: 7));
          break;
        case TopPeriodFilter.month:
          since = now.subtract(const Duration(days: 30));
          break;
        case TopPeriodFilter.year:
          since = now.subtract(const Duration(days: 365));
          break;
        case TopPeriodFilter.allTime:
        case TopPeriodFilter.none:
          break;
      }
      if (since != null) {
        queryParams['createdAtSince'] = since.toIso8601String().split('.').first;
      }
    } else {
      queryParams['order[latestUploadedChapter]'] = 'desc';
    }

    if (cleanedTags.isNotEmpty) {
      final includedTagIds = <String>[];
      final authorIds = <String>[];
      String remaining = cleanedTags.join(' ');

      // Check author:... or artist:...
      final authorRegex = RegExp(r'(?:author|artist):(?:"([^"]+)"|(\S+))', caseSensitive: false);
      for (final match in authorRegex.allMatches(remaining)) {
        final name = match.group(1) ?? match.group(2);
        if (name != null && name.isNotEmpty) {
          final id = await _resolveAuthorId(name);
          if (id != null) authorIds.add(id);
        }
      }
      remaining = remaining.replaceAll(authorRegex, '').trim();

      // Check tag:...
      final tagPrefixRegex = RegExp(r'tag:(?:"([^"]+)"|(\S+))', caseSensitive: false);
      for (final match in tagPrefixRegex.allMatches(remaining)) {
        final tagName = match.group(1) ?? match.group(2);
        if (tagName != null && tagName.isNotEmpty) {
          final tagId = _findTagId(tagName);
          if (tagId != null) includedTagIds.add(tagId);
        }
      }
      remaining = remaining.replaceAll(tagPrefixRegex, '').trim();

      // Match known tag names (longest first to avoid substring partial matches)
      if (remaining.isNotEmpty) {
        final sortedEntries = _kMangaDexTagIds.entries.toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));
        for (final entry in sortedEntries) {
          final pattern = RegExp('(^|\\s)${RegExp.escape(entry.key)}(\$|\\s)', caseSensitive: false);
          if (pattern.hasMatch(remaining)) {
            includedTagIds.add(entry.value);
            remaining = remaining.replaceAll(pattern, ' ').trim();
          }
        }
      }

      if (remaining.isNotEmpty) {
        queryParams['title'] = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
      if (includedTagIds.isNotEmpty) {
        queryParams['includedTags[]'] = includedTagIds.toSet().toList();
      }
      if (authorIds.isNotEmpty) {
        queryParams['authors[]'] = authorIds.toSet().toList();
      }
    }

    try {
      final response = await _dio.get<dynamic>(
        '/manga',
        queryParameters: queryParams,
      );

      _checkResponse(response);
      return MangaDexMapper.postsFromSearchResponse(
        response.data,
        providerId: id,
        providerName: name,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response = await _dio.get<dynamic>(
        '/manga/$id',
        queryParameters: {
          'includes[]': ['cover_art', 'author', 'artist'],
          ..._queryParameters,
        },
      );
      _checkResponse(response);

      if (response.data is Map && response.data['data'] is Map) {
        return MangaDexMapper.postFromMangaJson(
          response.data['data'] as Map<dynamic, dynamic>,
          providerId: this.id,
          providerName: name,
        );
      }
      return null;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Fetches chapters for a manga. If [language] is provided, filters by that language.
  Future<List<MangaDexChapter>> fetchChapters(String mangaId, {String? language}) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': 500,
        'order[chapter]': 'asc',
        'contentRating[]': const ['safe', 'suggestive', 'erotica', 'pornographic'],
        ..._queryParameters,
      };
      if (language != null && language.isNotEmpty) {
        queryParams['translatedLanguage[]'] = [language];
      }

      final response = await _dio.get<dynamic>(
        '/manga/$mangaId/feed',
        queryParameters: queryParams,
      );
      _checkResponse(response);
      return _parseChapters(response.data);
    } catch (_) {
      return [];
    }
  }

  List<MangaDexChapter> _parseChapters(dynamic data) {
    if (data is! Map || data['data'] is! List) return [];
    final items = data['data'] as List;
    final result = <MangaDexChapter>[];

    for (final item in items) {
      if (item is Map) {
        final id = item['id']?.toString() ?? '';
        final attrs = item['attributes'] as Map<dynamic, dynamic>? ?? {};
        final chNum = attrs['chapter']?.toString() ?? '1';
        final title = attrs['title']?.toString() ?? '';
        final lang = attrs['translatedLanguage']?.toString() ?? '';
        final pages = int.tryParse(attrs['pages']?.toString() ?? '0') ?? 0;
        final externalUrl = attrs['externalUrl']?.toString();

        if (id.isNotEmpty) {
          result.add(MangaDexChapter(
            id: id,
            chapterNumber: chNum,
            title: title,
            language: lang,
            pageCount: pages,
            externalUrl: externalUrl,
          ));
        }
      }
    }

    result.sort((a, b) {
      final numA = double.tryParse(a.chapterNumber) ?? 0.0;
      final numB = double.tryParse(b.chapterNumber) ?? 0.0;
      final cmp = numA.compareTo(numB);
      if (cmp != 0) return cmp;
      return a.language.compareTo(b.language);
    });

    return result;
  }

  /// Fetches image URLs for a chapter using @home endpoint
  Future<List<String>> fetchChapterPages(String chapterId) async {
    try {
      final response = await _dio.get<dynamic>('/at-home/server/$chapterId');
      _checkResponse(response);

      final data = response.data;
      if (data is Map && data['chapter'] is Map) {
        final baseUrl = data['baseUrl']?.toString() ?? '';
        final chapter = data['chapter'] as Map;
        final hash = chapter['hash']?.toString() ?? '';
        final files = chapter['data'] as List<dynamic>? ?? [];

        if (baseUrl.isNotEmpty && hash.isNotEmpty) {
          return files.map((f) => '$baseUrl/data/$hash/$f').toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches directly related manga (prequel, sequel, spin-off, etc.)
  Future<List<Post>> fetchRelatedManga(String mangaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/manga/$mangaId',
        queryParameters: {
          'includes[]': ['manga'],
          ..._queryParameters,
        },
      );
      _checkResponse(response);
      final data = response.data;
      if (data is! Map || data['data'] is! Map) return [];
      final rels = data['data']['relationships'] as List<dynamic>? ?? [];
      final relatedIds = <String>[];
      for (final rel in rels) {
        if (rel is Map && rel['type'] == 'manga') {
          final id = rel['id']?.toString();
          if (id != null && id.isNotEmpty) {
            relatedIds.add(id);
          }
        }
      }
      if (relatedIds.isEmpty) return [];

      final searchRes = await _dio.get<dynamic>(
        '/manga',
        queryParameters: {
          'ids[]': relatedIds.take(10).toList(),
          'includes[]': ['cover_art', 'author', 'artist'],
          'contentRating[]': const ['safe', 'suggestive', 'erotica', 'pornographic'],
          ..._queryParameters,
        },
      );
      _checkResponse(searchRes);
      return MangaDexMapper.postsFromSearchResponse(
        searchRes.data,
        providerId: id,
        providerName: name,
      );
    } catch (_) {
      return [];
    }
  }

  /// Fetches recommended or similar manga based on tags or genres
  Future<List<Post>> fetchRecommendations(Post currentManga, {int limit = 12}) async {
    try {
      final tagIds = <String>[];
      for (final tag in currentManga.tags) {
        final id = _findTagId(tag);
        if (id != null) {
          tagIds.add(id);
          if (tagIds.length >= 3) break;
        }
      }

      final queryParams = <String, dynamic>{
        'limit': limit + 2,
        'order[followedCount]': 'desc',
        'contentRating[]': const ['safe', 'suggestive', 'erotica', 'pornographic'],
        'includes[]': ['cover_art', 'author', 'artist'],
        ..._queryParameters,
      };

      if (tagIds.isNotEmpty) {
        queryParams['includedTags[]'] = tagIds;
      }

      final searchRes = await _dio.get<dynamic>(
        '/manga',
        queryParameters: queryParams,
      );
      _checkResponse(searchRes);
      final posts = MangaDexMapper.postsFromSearchResponse(
        searchRes.data,
        providerId: id,
        providerName: name,
      );
      return posts.where((p) => p.id != currentManga.id).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query, {int limit = 20}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final suggestions = <TagSuggestion>[];

    // 1. Tags matching from official MangaDex tags
    for (final entry in _kMangaDexTagIds.entries) {
      if (entry.key.toLowerCase().contains(clean)) {
        final group = _kMangaDexTagGroups[entry.key];
        final cat = switch (group) {
          'genre' => TagCategory.general,
          'theme' => TagCategory.character,
          'format' => TagCategory.meta,
          'content' => TagCategory.species,
          _ => TagCategory.general,
        };
        suggestions.add(TagSuggestion(
          name: entry.key,
          category: cat,
          postCount: 0,
          providerId: id,
        ));
      }
      if (suggestions.length >= 8) break;
    }

    // 2. Query authors & artists from MangaDex
    try {
      final authorRes = await _dio.get<dynamic>(
        '/author',
        queryParameters: {
          'name': clean,
          'limit': 5,
        },
      );
      if (authorRes.data is Map && authorRes.data['data'] is List) {
        for (final item in authorRes.data['data']) {
          if (item is Map) {
            final name = item['attributes']?['name']?.toString();
            final authorId = item['id']?.toString();
            if (name != null && name.isNotEmpty) {
              if (authorId != null) {
                _authorIdCache[name.toLowerCase()] = authorId;
              }
              suggestions.add(TagSuggestion(
                name: 'author:$name',
                category: TagCategory.artist,
                postCount: 0,
                providerId: id,
              ));
            }
          }
        }
      }
    } catch (_) {}

    // 3. Query manga titles from MangaDex
    try {
      final mangaRes = await _dio.get<dynamic>(
        '/manga',
        queryParameters: {
          'title': clean,
          'limit': 5,
          'contentRating[]': const ['safe', 'suggestive', 'erotica', 'pornographic'],
        },
      );
      if (mangaRes.data is Map && mangaRes.data['data'] is List) {
        for (final item in mangaRes.data['data']) {
          if (item is Map) {
            final attrs = item['attributes'] as Map<dynamic, dynamic>? ?? {};
            final titleMap = attrs['title'] as Map<dynamic, dynamic>? ?? {};
            final altTitles = attrs['altTitles'] as List<dynamic>?;
            final title = MangaDexMapper.extractTitle(titleMap, altTitles);
            if (title.isNotEmpty &&
                title != 'Untitled' &&
                !suggestions.any((s) => s.name.toLowerCase() == title.toLowerCase())) {
              suggestions.add(TagSuggestion(
                name: title,
                category: TagCategory.copyright,
                postCount: 0,
                providerId: id,
              ));
            }
          }
        }
      }
    } catch (_) {}

    return suggestions.take(limit).toList();
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      final response = await _dio.get<dynamic>('/ping');
      final isOk = response.statusCode == 200;
      return ProviderHealth(
        providerId: id,
        status: isOk ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'mangadex-api-v5',
      );
    } catch (error) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'mangadex-api-v5',
      );
    }
  }

  void _checkResponse(Response<dynamic> response) {
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw BadResponseException(
        'MangaDex returned HTTP ${response.statusCode}',
        details: response.data,
      );
    }
    if (response.data is Map && response.data['result'] == 'error') {
      final errors = response.data['errors'];
      throw BadResponseException(
        errors?.toString() ?? 'MangaDex API error',
        details: response.data,
      );
    }
  }

  Never _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      throw RequestTimeoutException(
        'Request timeout to MangaDex',
        details: error.message,
      );
    }
    if (error.type == DioExceptionType.badResponse) {
      throw BadResponseException(
        'MangaDex returned HTTP ${error.response?.statusCode}',
        details: error.response?.data,
      );
    }
    throw NetworkException(
      'Network failure with MangaDex',
      details: error.message,
    );
  }
}
