/// Splits text into sentences for batch processing.
///
/// Handles common edge cases: abbreviations (Mr., Dr., U.S.A.),
/// URLs, decimal numbers, ellipses, and quoted speech.
class SentenceSplitter {
  const SentenceSplitter._();

  /// Common abbreviations that should NOT be treated as sentence endings.
  static const _abbreviations = {
    'mr', 'mrs', 'ms', 'dr', 'prof', 'sr', 'jr', 'st',
    'vs', 'etc', 'approx', 'dept', 'est', 'vol',
    'inc', 'ltd', 'corp', 'co',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug',
    'sep', 'oct', 'nov', 'dec',
    'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
    // German
    'bzw', 'usw', 'evtl', 'ggf',
    // French
    'av',
    // Spanish/Portuguese
    'sra', 'ud', 'uds',
  };

  /// Split text into individual sentences.
  ///
  /// Returns a list of [SentenceSpan] objects with text content
  /// and character offsets in the original text.
  static List<SentenceSpan> split(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <SentenceSpan>[];
    final buffer = StringBuffer();
    var sentenceStart = 0;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      if (_isSentenceTerminator(char)) {
        // Check if this is actually a sentence end
        if (_isActualSentenceEnd(text, i)) {
          // Consume trailing whitespace
          var end = i + 1;
          while (end < text.length && text[end] == ' ') {
            end++;
          }

          final sentenceText = buffer.toString().trim();
          if (sentenceText.isNotEmpty) {
            sentences.add(
              SentenceSpan(
                text: sentenceText,
                startOffset: sentenceStart,
                endOffset: i + 1,
              ),
            );
          }

          buffer.clear();
          sentenceStart = end;
          i = end - 1; // -1 because loop will increment
        }
      }
    }

    // Add remaining text as final sentence
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(
        SentenceSpan(
          text: remaining,
          startOffset: sentenceStart,
          endOffset: text.length,
        ),
      );
    }

    return sentences;
  }

  /// Check if the character is a potential sentence terminator.
  static bool _isSentenceTerminator(String char) {
    return char == '.' ||
        char == '!' ||
        char == '?' ||
        char == '\n'; // Line breaks also split sentences
  }

  /// Determine if the period/punctuation at [index] is an actual sentence end.
  static bool _isActualSentenceEnd(String text, int index) {
    final char = text[index];

    // Newlines are always sentence boundaries
    if (char == '\n') return true;

    // ! and ? are always sentence endings
    if (char == '!' || char == '?') return true;

    // Period-specific checks
    if (char == '.') {
      // Check for ellipsis (...)
      if (index + 2 < text.length &&
          text[index + 1] == '.' &&
          text[index + 2] == '.') {
        return false;
      }

      // Check if this is part of a decimal number (3.14)
      if (index > 0 &&
          index + 1 < text.length &&
          _isDigit(text[index - 1]) &&
          _isDigit(text[index + 1])) {
        return false;
      }

      // Check for abbreviation
      final wordBefore = _getWordBefore(text, index);
      if (_abbreviations.contains(wordBefore.toLowerCase())) {
        return false;
      }

      // Check for URL patterns
      if (_isInUrl(text, index)) return false;

      // If next non-space char is lowercase, probably not sentence end
      final nextChar = _getNextNonSpaceChar(text, index + 1);
      if (nextChar != null &&
          nextChar == nextChar.toLowerCase() &&
          nextChar != nextChar.toUpperCase()) {
        // Next word starts with lowercase — likely abbreviation or decimal
        // But only if the word before is very short (abbreviation-like)
        if (wordBefore.length <= 3) return false;
      }

      return true;
    }

    return false;
  }

  static String _getWordBefore(String text, int index) {
    final end = index;
    var start = end - 1;
    while (start >= 0 && text[start] != ' ' && text[start] != '\n') {
      start--;
    }
    return text.substring(start + 1, end);
  }

  static String? _getNextNonSpaceChar(String text, int from) {
    for (var i = from; i < text.length; i++) {
      if (text[i] != ' ' && text[i] != '\n' && text[i] != '\t') {
        return text[i];
      }
    }
    return null;
  }

  static bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  }

  static bool _isInUrl(String text, int index) {
    // Simple heuristic: look backwards for "://" or "www."
    final start = (index - 50).clamp(0, index);
    final segment = text.substring(start, index);
    return segment.contains('://') || segment.contains('www.');
  }
}

/// A sentence with its position in the original text.
class SentenceSpan {
  /// The sentence text.
  final String text;

  /// Start character offset in the original text.
  final int startOffset;

  /// End character offset in the original text.
  final int endOffset;

  const SentenceSpan({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  @override
  String toString() => 'SentenceSpan("$text", $startOffset-$endOffset)';
}
