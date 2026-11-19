class RemoteBroadcastMessage {
  const RemoteBroadcastMessage({
    required this.id,
    required this.active,
    required this.titleRu,
    required this.messageRu,
    required this.titleEn,
    required this.messageEn,
  });

  factory RemoteBroadcastMessage.fromJson(Map<String, dynamic> json) {
    return RemoteBroadcastMessage(
      id: json['id'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      titleRu: json['title_ru'] as String? ?? '',
      messageRu: json['message_ru'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      messageEn: json['message_en'] as String? ?? '',
    );
  }

  final String id;
  final bool active;
  final String titleRu;
  final String messageRu;
  final String titleEn;
  final String messageEn;

  String title(bool isRu) => isRu ? titleRu : titleEn;
  String message(bool isRu) => isRu ? messageRu : messageEn;
}

class RemoteProviderMirror {
  const RemoteProviderMirror({
    required this.baseUrl,
    this.customHeaders,
  });

  factory RemoteProviderMirror.fromJson(Map<String, dynamic> json) {
    final headers = json['customHeaders'];
    return RemoteProviderMirror(
      baseUrl: json['baseUrl'] as String? ?? '',
      customHeaders: headers is Map
          ? headers.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
    );
  }

  final String baseUrl;
  final Map<String, String>? customHeaders;
}

class RemoteMirrorsConfig {
  const RemoteMirrorsConfig({
    required this.version,
    this.updatedAt,
    this.broadcast,
    required this.mirrors,
  });

  factory RemoteMirrorsConfig.fromJson(Map<String, dynamic> json) {
    final rawMirrors = json['mirrors'];
    final mirrors = <String, RemoteProviderMirror>{};
    if (rawMirrors is Map) {
      for (final entry in rawMirrors.entries) {
        if (entry.value is Map) {
          mirrors[entry.key.toString()] = RemoteProviderMirror.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }

    final broadcastJson =
        json['broadcast'] ?? json['broadcast_message'];
    return RemoteMirrorsConfig(
      version: json['version'] as int? ?? 1,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      broadcast: broadcastJson is Map
          ? RemoteBroadcastMessage.fromJson(
              Map<String, dynamic>.from(broadcastJson),
            )
          : null,
      mirrors: mirrors,
    );
  }

  final int version;
  final DateTime? updatedAt;
  final RemoteBroadcastMessage? broadcast;
  final Map<String, RemoteProviderMirror> mirrors;
}

class RemoteMirrorsSyncResult {
  const RemoteMirrorsSyncResult({
    required this.updatedCount,
    this.broadcast,
  });

  final int updatedCount;
  final RemoteBroadcastMessage? broadcast;
}
