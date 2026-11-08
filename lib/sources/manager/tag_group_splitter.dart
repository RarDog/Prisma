/// Splits search tag lists containing 'and' separators into independent branches
/// and distributes trailing modifier tags across all branches.
abstract final class TagGroupSplitter {
  static List<List<String>> split(List<String> rawTags) {
    final segments = <List<String>>[];
    List<String> current = [];

    for (final raw in rawTags) {
      var token = raw.trim();
      if (token.isEmpty) continue;

      // Only strip parentheses if they are grouping delimiters (unbalanced in the token, e.g. '(cat' or 'dog)')
      // but preserve tags that have internal paired parentheses like 'tyson_(password)'.
      if (token.startsWith('(') && !token.contains(')')) {
        token = token.substring(1).trim();
      }
      if (token.endsWith(')') && !token.contains('(')) {
        token = token.substring(0, token.length - 1).trim();
      }
      if (token.isEmpty) continue;

      if (token.toLowerCase() == 'and') {
        if (current.isNotEmpty) {
          segments.add(current);
          current = [];
        }
      } else {
        current.add(token);
      }
    }

    if (current.isNotEmpty) {
      segments.add(current);
    }

    if (segments.isEmpty) {
      return [const []];
    }

    if (segments.length == 1) {
      return segments;
    }

    // Multiple segments separated by 'and'
    // If the last segment has trailing tags after the branch tag (e.g. 'cat and dog anthro'):
    // The trailing tags apply as common modifier tags to ALL branches!
    final lastSegment = segments.last;
    final prevSegment = segments[segments.length - 2];
    final branchLen = prevSegment.length.clamp(1, lastSegment.length);

    if (lastSegment.length > branchLen) {
      final commonTail = lastSegment.sublist(branchLen);
      final adjustedSegments = <List<String>>[];

      for (int i = 0; i < segments.length; i++) {
        final seg = i == segments.length - 1
            ? lastSegment
            : [...segments[i], ...commonTail];

        final seen = <String>{};
        final deduped = <String>[];
        for (final t in seg) {
          if (seen.add(t.toLowerCase())) {
            deduped.add(t);
          }
        }
        adjustedSegments.add(deduped);
      }
      return adjustedSegments;
    }

    return segments;
  }
}
