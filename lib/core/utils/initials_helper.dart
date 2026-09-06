// ─────────────────────────────────────────────────────────────────────────────
// InitialsHelper
// ─────────────────────────────────────────────────────────────────────────────

/// Helper utility for extracting clean, uppercase initials from user names.
///
/// Rules enforced:
/// - Multiple words: Uses the first letter of the first word and first letter
///   of the last word (e.g. "Hrushikesh Bhoir" → "HB", "Priya Sharma" → "PS",
///   "A B" → "AB", "Dr. Priya K. Sharma" → "DS").
/// - One-word names: Uses the first letter of the word (e.g. "Rahul" → "R").
/// - Whitespace & empty segments: Safely trims leading/trailing whitespace and
///   ignores consecutive internal spaces (e.g. "  Hrushikesh   Bhoir  " → "HB").
/// - Fallback: If the name is null, empty, or whitespace-only, returns "U".
class InitialsHelper {
  const InitialsHelper._();

  /// Generates initials for [name] following the Nari Suraksha initial rules.
  static String getInitials(String? name) {
    if (name == null) return 'U';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'U';

    if (words.length == 1) {
      final single = words.first;
      return single.isNotEmpty ? single[0].toUpperCase() : 'U';
    }

    final firstChar = words.first[0].toUpperCase();
    final lastChar = words.last[0].toUpperCase();
    return '$firstChar$lastChar';
  }
}
