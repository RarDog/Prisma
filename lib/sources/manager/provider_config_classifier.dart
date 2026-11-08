import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';

/// Classifies [ContentProviderConfig] instances into their appropriate
/// application silos (Feed, Artist, Manga) and filters out obsolete endpoints.
abstract final class ProviderConfigClassifier {
  /// apiType values that expose the `ArtistProvider` capability and therefore
  /// feed the Artists tab instead of the post feed.
  static const _artistApiTypes = <String>{'pawchive', 'fapello'};

  static bool isArtistConfig(ContentProviderConfig config) {
    return _artistApiTypes.contains(config.apiType.toLowerCase());
  }

  static bool isMangaConfig(ContentProviderConfig config) {
    final type = config.apiType.toLowerCase();
    return type == 'mangadex' || type == 'mangalib' || type == 'ranobelib';
  }

  static bool isFeedConfig(ContentProviderConfig config) {
    return !isArtistConfig(config) && !isMangaConfig(config);
  }

  static bool isLegacyRemovedConfig(ContentProviderConfig config) {
    final id = config.id.toLowerCase();
    final type = config.apiType.toLowerCase();
    return id == 'cosbooru' ||
        type == 'kemono' ||
        type == 'coomer' ||
        id == 'kemono' ||
        id == 'coomer';
  }
}
