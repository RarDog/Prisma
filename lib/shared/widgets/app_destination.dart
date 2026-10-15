import 'package:flutter/material.dart';

class AppDestination {
  const AppDestination(
    this.id,
    this.label,
    this.icon,
    this.location, {
    this.selectedIcon,
    String? mobileLabel,
  }) : mobileLabel = mobileLabel ?? label;

  final String id;
  final String label;
  final String mobileLabel;
  final IconData icon;
  final IconData? selectedIcon;
  final String location;

  IconData get effectiveSelectedIcon => selectedIcon ?? icon;

  String labelFor(bool ru) {
    if (!ru) return label;
    return switch (id) {
      'feed' => '\u041b\u0435\u043d\u0442\u0430',
      'search' => '\u0418\u0441\u0442\u043e\u0440\u0438\u044f',
      'favorites' => '\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435',
      'viewed' => '\u0418\u0441\u0442\u043e\u0440\u0438\u044f',
      'collections' => '\u041a\u043e\u043b\u043b\u0435\u043a\u0446\u0438\u0438',
      'artists' => '\u0410\u0440\u0442\u0438\u0441\u0442\u044b',
      'manga' => '\u041c\u0430\u043d\u0433\u0430',
      'providers' =>
        '\u041f\u0440\u043e\u0432\u0430\u0439\u0434\u0435\u0440\u044b',
      'settings' => '\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438',
      _ => label,
    };
  }

  String mobileLabelFor(bool ru) {
    if (!ru) return mobileLabel;
    return switch (id) {
      'collections' => '\u0414\u043e\u0441\u043a\u0438',
      'favorites' => '\u041b\u044e\u0431\u0438\u043c\u043e\u0435',
      _ => labelFor(true),
    };
  }
}
