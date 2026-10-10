import 'package:flutter/widgets.dart';

class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class SeekVideoIntent extends Intent {
  const SeekVideoIntent(this.seconds);
  final int seconds;
}

class VolumeVideoIntent extends Intent {
  const VolumeVideoIntent(this.deltaY);
  final double deltaY;
}

class MuteVideoIntent extends Intent {
  const MuteVideoIntent();
}

class FullscreenVideoIntent extends Intent {
  const FullscreenVideoIntent();
}

class LoopVideoIntent extends Intent {
  const LoopVideoIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ResetZoomIntent extends Intent {
  const ResetZoomIntent();
}

class PrevImageIntent extends Intent {
  const PrevImageIntent();
}

class NextImageIntent extends Intent {
  const NextImageIntent();
}

class FullscreenImageIntent extends Intent {
  const FullscreenImageIntent();
}

class CloseFullscreenIntent extends Intent {
  const CloseFullscreenIntent();
}

class ToggleControlsIntent extends Intent {
  const ToggleControlsIntent();
}

class PrevFullscreenImageIntent extends Intent {
  const PrevFullscreenImageIntent();
}

class NextFullscreenImageIntent extends Intent {
  const NextFullscreenImageIntent();
}
