import 'dart:io';

/// Enforces TLS certificate validation rules across the application.
///
/// Prevents MITM attacks against critical endpoints (GitHub updates, e621 login,
/// Pixiv OAuth, API registries) while allowing selective compatibility for
/// known third-party booru mirrors with expired/self-signed media certificates.
class TlsSecurityPolicy {
  const TlsSecurityPolicy._();

  /// Domains that MUST have valid, system-trusted TLS/SSL certificates.
  /// Any certificate error on these domains is strictly rejected.
  static const _strictlyVerifiedDomains = {
    'github.com',
    'api.github.com',
    'raw.githubusercontent.com',
    'objects.githubusercontent.com',
    'e621.net',
    'e926.net',
    'danbooru.donmai.us',
    'pixiv.net',
    'accounts.pixiv.net',
    'app-api.pixiv.net',
    'oauth.secure.pixiv.net',
    'gelbooru.com',
  };

  /// Known third-party booru mirrors/CDNs with recurring self-signed or expired certs.
  static const _knownSelfSignedHosts = {
    'fckthots.xyz',
    'www.fckthots.xyz',
  };

  /// Evaluates whether an untrusted certificate should be accepted.
  static bool shouldAllowBadCertificate(
    X509Certificate cert,
    String host,
    int port,
  ) {
    final lowerHost = host.toLowerCase().trim();

    // 1. Strictly reject invalid certificates for critical infrastructure and auth
    for (final domain in _strictlyVerifiedDomains) {
      if (lowerHost == domain || lowerHost.endsWith('.$domain')) {
        return false;
      }
    }

    // 2. Allow known third-party booru mirrors with self-signed / expired certs
    for (final allowed in _knownSelfSignedHosts) {
      if (lowerHost == allowed || lowerHost.endsWith('.$allowed')) {
        return true;
      }
    }

    // 3. Reject by default for security
    return false;
  }
}
