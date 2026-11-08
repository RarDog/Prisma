import 'video_surface.dart';

/// Remembers playback state per post across screens. LRU-capped: without a
/// bound it grew one entry per video watched for the whole session.
final Map<String, VideoPlaybackSnapshot> playbackMemory =
    <String, VideoPlaybackSnapshot>{};

const _playbackMemoryCap = 50;

/// Stores [snapshot] for [cacheKey], evicting oldest entries when capacity exceeds 50.
void rememberPlayback(String cacheKey, VideoPlaybackSnapshot snapshot) {
  playbackMemory.remove(cacheKey);
  playbackMemory[cacheKey] = snapshot;
  while (playbackMemory.length > _playbackMemoryCap) {
    playbackMemory.remove(playbackMemory.keys.first);
  }
}

/// Retrieves saved video playback position for [cacheKey], or [Duration.zero].
Duration getPostVideoPlaybackPosition(String cacheKey) {
  return playbackMemory[cacheKey]?.position ?? Duration.zero;
}
