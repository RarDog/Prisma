import 'package:gel_rule_app/core/models/top_period_filter.dart';

class ContentProviderConfig {
  const ContentProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiType,
    required this.enabled,
    required this.priority,
    required this.timeoutSeconds,
    required this.customHeaders,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String apiType;
  final bool enabled;
  final int priority;
  final int timeoutSeconds;
  final Map<String, String> customHeaders;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiType,
    bool? enabled,
    int? priority,
    int? timeoutSeconds,
    Map<String, String>? customHeaders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContentProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiType: apiType ?? this.apiType,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      customHeaders: customHeaders ?? this.customHeaders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiType': apiType,
        'enabled': enabled,
        'priority': priority,
        'timeoutSeconds': timeoutSeconds,
        'customHeaders': customHeaders,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ContentProviderConfig.fromJson(Map<String, dynamic> json) {
    return ContentProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiType: json['apiType'] as String,
      enabled: (json['enabled'] as bool?) ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 20,
      customHeaders: Map<String, String>.from(
        (json['customHeaders'] as Map?) ?? const {},
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

extension ContentProviderConfigTopPeriod on ContentProviderConfig {
  Set<TopPeriodFilter> get supportedTopPeriods {
    return switch (apiType.toLowerCase()) {
      'danbooru' || 'e621' || 'mangadex' => const {
          TopPeriodFilter.none,
          TopPeriodFilter.day,
          TopPeriodFilter.week,
          TopPeriodFilter.month,
          TopPeriodFilter.year,
          TopPeriodFilter.allTime,
        },
      'pixiv' => const {
          TopPeriodFilter.none,
          TopPeriodFilter.day,
          TopPeriodFilter.week,
          TopPeriodFilter.month,
        },
      'paheal' || 'rule34_paheal' || 'pawchive' => const {
          TopPeriodFilter.none,
        },
      _ => const {
          TopPeriodFilter.none,
          TopPeriodFilter.allTime,
        },
    };
  }
}

Set<TopPeriodFilter> resolveSupportedTopPeriods(
    Iterable<ContentProviderConfig> activeConfigs) {
  final list = activeConfigs.toList();
  if (list.isEmpty) {
    return const {TopPeriodFilter.none, TopPeriodFilter.allTime};
  }
  if (list.length == 1) {
    return list.first.supportedTopPeriods;
  }
  var common = list.first.supportedTopPeriods.toSet();
  for (final p in list.skip(1)) {
    common = common.intersection(p.supportedTopPeriods);
  }
  if (list.any((p) => p.supportedTopPeriods.contains(TopPeriodFilter.allTime))) {
    common.add(TopPeriodFilter.allTime);
  }
  common.add(TopPeriodFilter.none);
  return common;
}

