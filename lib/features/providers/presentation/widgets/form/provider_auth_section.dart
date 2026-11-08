import 'package:flutter/material.dart';

import 'provider_form_controls.dart';

/// Form section for provider API keys, credentials, and cookies.
class ProviderAuthSection extends StatelessWidget {
  const ProviderAuthSection({
    required this.apiKeyController,
    required this.userIdController,
    required this.loginController,
    required this.phpsessidController,
    required this.apiType,
    required this.obscureApiKey,
    required this.onToggleObscureApiKey,
    required this.obscurePhpsessid,
    required this.onToggleObscurePhpsessid,
    super.key,
  });

  final TextEditingController apiKeyController;
  final TextEditingController userIdController;
  final TextEditingController loginController;
  final TextEditingController phpsessidController;
  final String apiType;
  final bool obscureApiKey;
  final VoidCallback onToggleObscureApiKey;
  final bool obscurePhpsessid;
  final VoidCallback onToggleObscurePhpsessid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return FormLiquidCard(
      icon: Icons.vpn_key_rounded,
      accentColor: const Color(0xFFF59E0B),
      title: isRu ? 'Ключи доступа и аккаунт' : 'API Keys & Authentication',
      subtitle: isRu
          ? 'Необходимы для снятия ограничений на поиск и теги'
          : 'Required for unrestricted queries and higher limits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Notice
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B)
                  .withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B)
                    .withValues(alpha: isDark ? 0.35 : 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRu
                        ? 'Для Gelbooru и Rule34: User ID и API Key можно найти в настройках профиля (Account -> Options).'
                        : 'For Gelbooru & Rule34: Find your User ID and API Key in Account -> Options.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          GlassTextField(
            controller: apiKeyController,
            label: 'API Key',
            hint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
            icon: Icons.key_rounded,
            obscureText: obscureApiKey,
            suffixIcon: IconButton(
              icon: Icon(
                obscureApiKey
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
              ),
              onPressed: onToggleObscureApiKey,
            ),
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: userIdController,
            label: 'User ID',
            hint: '123456',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          GlassTextField(
            controller: loginController,
            label: isRu ? 'Логин (Login)' : 'Login Username',
            hint: 'username',
            icon: Icons.account_circle_outlined,
          ),
          // PHPSESSID — only for Pixiv
          if (apiType == 'pixiv') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0096FA)
                    .withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF0096FA)
                      .withValues(alpha: isDark ? 0.35 : 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.cookie_outlined,
                    size: 18,
                    color: Color(0xFF0096FA),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRu
                          ? 'Для Pixiv: откройте DevTools в браузере → Application → Cookies → pixiv.net и скопируйте значение PHPSESSID. Даёт доступ к ленте подписок.'
                          : 'For Pixiv: open DevTools → Application → Cookies → pixiv.net and copy the PHPSESSID value. Enables following feed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GlassTextField(
              controller: phpsessidController,
              label: 'PHPSESSID (Pixiv Cookie)',
              hint: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              icon: Icons.vpn_lock_rounded,
              obscureText: obscurePhpsessid,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePhpsessid
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: onToggleObscurePhpsessid,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
