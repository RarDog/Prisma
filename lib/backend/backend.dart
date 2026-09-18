export 'di/backend_providers.dart';

// Core Models & Utils
export 'package:gel_rule_app/core/models/post.dart';
export 'package:gel_rule_app/core/models/post_comment.dart';
export 'package:gel_rule_app/core/models/post_note.dart';
export 'package:gel_rule_app/core/models/tag_suggestion.dart';
export 'package:gel_rule_app/core/models/top_period_filter.dart';
export 'package:gel_rule_app/core/models/provider_health.dart';
export 'package:gel_rule_app/core/models/provider_diagnostics.dart';
export 'package:gel_rule_app/core/utils/smart_blacklist.dart';
export 'package:gel_rule_app/core/utils/media_quality.dart';

// Sources (Booru Engine)
export 'package:gel_rule_app/sources/interfaces/content_provider.dart';
export 'package:gel_rule_app/sources/provider_factory.dart';
export 'package:gel_rule_app/sources/provider_manager.dart';

// Feature: Favorites
export 'package:gel_rule_app/features/favorites/models/favorite.dart';
export 'package:gel_rule_app/features/favorites/models/favorite_artist_item.dart';
export 'package:gel_rule_app/features/favorites/data/favorite_repository.dart';
export 'package:gel_rule_app/features/favorites/domain/favorite_service.dart';

// Feature: Collections
export 'package:gel_rule_app/features/collections/models/collection.dart';
export 'package:gel_rule_app/features/collections/data/collection_repository.dart';
export 'package:gel_rule_app/features/collections/domain/collection_service.dart';

// Feature: Search
export 'package:gel_rule_app/features/search/models/search_history.dart';
export 'package:gel_rule_app/features/search/data/search_repository.dart';
export 'package:gel_rule_app/features/search/domain/search_service.dart';
export 'package:gel_rule_app/features/search/domain/tag_cache_service.dart';

// Feature: Feed
export 'package:gel_rule_app/features/feed/data/post_repository.dart';
export 'package:gel_rule_app/features/feed/domain/feed_service.dart';

// Feature: Viewed
export 'package:gel_rule_app/features/viewed/models/viewed_post.dart';
export 'package:gel_rule_app/features/viewed/data/viewed_post_repository.dart';
export 'package:gel_rule_app/features/viewed/domain/viewed_history_service.dart';

// Feature: Downloads
export 'package:gel_rule_app/features/downloads/models/download_task.dart';
export 'package:gel_rule_app/features/downloads/models/downloaded_media.dart';
export 'package:gel_rule_app/features/downloads/models/cloud_media_link.dart';
export 'package:gel_rule_app/features/downloads/data/downloaded_media_repository.dart';
export 'package:gel_rule_app/features/downloads/domain/download_service.dart';
export 'package:gel_rule_app/features/downloads/domain/download_manager_service.dart';
export 'package:gel_rule_app/features/downloads/domain/downloaded_media_service.dart';
export 'package:gel_rule_app/features/downloads/domain/cloud_link_extractor.dart';

// Feature: Settings & Backup
export 'package:gel_rule_app/features/settings/models/app_update_info.dart';
export 'package:gel_rule_app/features/settings/domain/settings_service.dart';
export 'package:gel_rule_app/features/settings/domain/backup_service.dart';
export 'package:gel_rule_app/features/settings/domain/update_service.dart';

// Feature: Artists
export 'package:gel_rule_app/features/artists/models/artist_profile.dart';
export 'package:gel_rule_app/features/artists/models/artist_work_query.dart';
export 'package:gel_rule_app/features/artists/models/artist_tag.dart';
export 'package:gel_rule_app/features/artists/models/artist_link.dart';
export 'package:gel_rule_app/features/artists/models/artist_announcement.dart';
export 'package:gel_rule_app/features/artists/models/creator_link.dart';
export 'package:gel_rule_app/features/artists/models/pawchive_account.dart';
export 'package:gel_rule_app/features/artists/models/e621_pool.dart';
export 'package:gel_rule_app/features/artists/domain/pawchive_sync_service.dart';

// Feature: Providers Config
export 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
export 'package:gel_rule_app/features/providers/data/provider_repository.dart';
export 'package:gel_rule_app/features/providers/domain/provider_check_service.dart';

// Feature: Onboarding
export 'package:gel_rule_app/features/onboarding/domain/onboarding_service.dart';
