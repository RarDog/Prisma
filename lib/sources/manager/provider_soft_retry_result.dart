import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';

class ProviderSoftRetryResult {
  const ProviderSoftRetryResult({
    required this.providerId,
    required this.tags,
    required this.page,
    required this.limit,
    required this.topPeriod,
    required this.posts,
    this.rating,
  });

  final String providerId;
  final List<String> tags;
  final int page;
  final int limit;
  final TopPeriodFilter topPeriod;
  final String? rating;
  final List<Post> posts;
}
