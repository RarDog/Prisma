enum ProviderStatus { unknown, online, offline }

class ProviderHealth {
  const ProviderHealth({
    required this.providerId,
    required this.status,
    required this.pingMs,
    required this.lastCheckedAt,
    this.errorMessage,
    this.apiVersion,
  });

  final String providerId;
  final ProviderStatus status;
  final int pingMs;
  final DateTime lastCheckedAt;
  final String? errorMessage;
  final String? apiVersion;

  bool get isOnline => status == ProviderStatus.online;
}
