import 'package:flutter/material.dart';

class NavigateIntent extends Intent {
  const NavigateIntent(this.location);
  final String location;
}

class BackIntent extends Intent {
  const BackIntent();
}

class CycleTabIntent extends Intent {
  const CycleTabIntent({required this.forward});
  final bool forward;
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}

