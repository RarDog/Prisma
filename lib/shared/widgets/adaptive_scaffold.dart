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

  Widget _buildGlassAppBar(BuildContext context, {required bool mobile}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      leading: leading,
      title: titleWidget ?? Text(title),
      actions: actions,
      toolbarHeight: mobile ? 52 : 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.scaffoldBackgroundColor.withValues(alpha: 0.78)
                  : theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
            ),
          ),
        ),
      ),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(mobile ? 52 : 56),
        child: _buildGlassAppBar(context, mobile: mobile),
      ),
      body: mobile ? SafeArea(top: false, bottom: false, child: body) : body,
      floatingActionButton: floatingActionButton,
    );
  }
}
