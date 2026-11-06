import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:gel_rule_app/app/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.title,
    required this.body,
    this.titleWidget,
    this.actions = const [],
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = false,
    this.leading,
    super.key,
  });

  final String title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final Widget? leading;

  Widget _buildGlassNotchBar(BuildContext context, {required bool mobile}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
            theme.colorScheme.surface == const Color(0xFF000000));
    final scheme = theme.colorScheme;
    final blurSigma = isAmoled ? 28.0 : 22.0;
    final topPadding = MediaQuery.paddingOf(context).top;
    final barHeight = mobile ? 54.0 : 58.0;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isAmoled ? 0.60 : (isDark ? 0.40 : 0.10),
              ),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            if (isDark)
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: isAmoled ? 0.10 : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isAmoled
                      ? [
                          const Color(0xFF141416).withValues(alpha: 0.85),
                          const Color(0xFF000000).withValues(alpha: 0.65),
                        ]
                      : isDark
                          ? [
                              scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.72),
                              scheme.surface.withValues(alpha: 0.52),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.60),
                            ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isAmoled
                        ? Colors.white.withValues(alpha: 0.18)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.75),
                    width: 1.0,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // Specular Highlight — тонкий световой блик по нижнему скруглению
                  Positioned(
                    bottom: 0,
                    left: 32,
                    right: 32,
                    height: 1.2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(
                                alpha: isDark ? 0.35 : 0.80,
                              ),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Ambient underglow — мягкое свечение цвета акцента темы
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: topPadding + barHeight,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.4,
                            colors: [
                              scheme.primary.withValues(
                                alpha: isAmoled ? 0.12 : 0.08,
                              ),
                              scheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content of the app bar (Title + Actions)
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: SizedBox(
                      height: barHeight,
                      child: NavigationToolbar(
                        leading: leading,
                        middle: DefaultTextStyle(
                          style: (theme.textTheme.titleLarge ?? const TextStyle())
                              .copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          child: titleWidget ?? Text(title),
                        ),
                        trailing: actions.isEmpty
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions,
                              ),
                        centerMiddle: false,
                        middleSpacing: 8.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final barHeight = mobile ? 54.0 : 58.0;
    final totalBarHeight = topPadding + barHeight;

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Scrolling content that goes freely under the glass notch
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Padding(
              padding: EdgeInsets.only(top: totalBarHeight),
              child: mobile
                  ? SafeArea(top: false, bottom: false, child: body)
                  : body,
            ),
          ),

          // Floating Glass Notch Header pinned to the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassNotchBar(context, mobile: mobile),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
