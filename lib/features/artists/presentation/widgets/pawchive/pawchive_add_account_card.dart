import 'package:flutter/material.dart';

/// "Add account" section: credentials / session-cookie tab forms with an
/// inline error banner. Login handlers live in the sheet orchestrator.
class PawchiveAddAccountCard extends StatelessWidget {
  const PawchiveAddAccountCard({
    super.key,
    required this.tabController,
    required this.usernameController,
    required this.passwordController,
    required this.cookieController,
    required this.obscurePassword,
    required this.onToggleObscurePassword,
    required this.isAdding,
    required this.errorMessage,
    required this.isFirstAccount,
    required this.isRu,
    required this.onLoginCredentials,
    required this.onLoginCookie,
  });

  final TabController tabController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController cookieController;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final bool isAdding;
  final String? errorMessage;
  final bool isFirstAccount;
  final bool isRu;
  final VoidCallback onLoginCredentials;
  final VoidCallback onLoginCookie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            isFirstAccount
                ? (isRu ? 'ДОБАВИТЬ АККАУНТ' : 'ADD ACCOUNT')
                : (isRu ? 'ДОБАВИТЬ ЕЩЁ АККАУНТ' : 'ADD ANOTHER ACCOUNT'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  controller: tabController,
                  tabs: [
                    Tab(
                        text: isRu
                            ? 'Логин и пароль'
                            : 'Login & password'),
                    const Tab(text: 'Session Cookie'),
                  ],
                ),
                const SizedBox(height: 16),
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: scheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 190,
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      // Tab 1: Username & Password
                      Column(
                        children: [
                          TextField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText:
                                  isRu ? 'Имя пользователя' : 'Username',
                              prefixIcon:
                                  const Icon(Icons.person_outline_rounded),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: isRu ? 'Пароль' : 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: onToggleObscurePassword,
                              ),
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: isAdding ? null : onLoginCredentials,
                            icon: isAdding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              isRu
                                  ? 'Войти и синхронизировать'
                                  : 'Sign in & sync',
                            ),
                          ),
                        ],
                      ),
                      // Tab 2: Session Cookie
                      Column(
                        children: [
                          TextField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: isRu
                                  ? 'Никнейм (необязательно)'
                                  : 'Nickname (optional)',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: cookieController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: isRu
                                  ? 'Сессионная кука'
                                  : 'Session cookie',
                              hintText: isRu
                                  ? 'session=ey... или значение куки'
                                  : 'session=ey... or cookie value',
                              prefixIcon: const Icon(Icons.cookie_outlined),
                              isDense: true,
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: isAdding ? null : onLoginCookie,
                            icon: isAdding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded),
                            label: Text(
                              isRu ? 'Сохранить куку' : 'Save cookie',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
