/// Helper utilities for reader chapter navigation and progress calculations.
class ReaderNavigationHelper {
  const ReaderNavigationHelper._();

  /// Returns true if there is a previous chapter available.
  static bool hasPrevious({required int currentIndex, required int totalCount}) {
    return currentIndex > 0 && totalCount > 0;
  }

  /// Returns true if there is a next chapter available.
  static bool hasNext({required int currentIndex, required int totalCount}) {
    return currentIndex >= 0 && currentIndex < totalCount - 1;
  }

  /// Calculates the previous chapter index if available.
  static int? previousIndex({required int currentIndex, required int totalCount}) {
    if (!hasPrevious(currentIndex: currentIndex, totalCount: totalCount)) return null;
    return currentIndex - 1;
  }

  /// Calculates the next chapter index if available.
  static int? nextIndex({required int currentIndex, required int totalCount}) {
    if (!hasNext(currentIndex: currentIndex, totalCount: totalCount)) return null;
    return currentIndex + 1;
  }

  /// Formats the chapter progress label (e.g. "1 / 24").
  static String formatChapterProgress({required int currentIndex, required int totalCount}) {
    if (totalCount <= 0) return '0 / 0';
    return '${currentIndex + 1} / $totalCount';
  }
}
