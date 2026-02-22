import 'package:grammar_engine/src/models/language.dart';

/// Text statistics for a document.
class TextStats {
  /// Total word count.
  final int wordCount;

  /// Total character count (including spaces).
  final int characterCount;

  /// Character count without spaces.
  final int characterCountNoSpaces;

  /// Number of sentences.
  final int sentenceCount;

  /// Number of paragraphs.
  final int paragraphCount;

  /// Average words per sentence.
  final double avgWordsPerSentence;

  /// Average word length in characters.
  final double avgWordLength;

  /// Estimated reading time in minutes.
  final double readingTimeMinutes;

  /// Estimated speaking time in minutes.
  final double speakingTimeMinutes;

  /// Vocabulary richness (type-token ratio: unique words / total words).
  final double vocabularyRichness;

  const TextStats({
    required this.wordCount,
    required this.characterCount,
    required this.characterCountNoSpaces,
    required this.sentenceCount,
    required this.paragraphCount,
    required this.avgWordsPerSentence,
    required this.avgWordLength,
    required this.readingTimeMinutes,
    required this.speakingTimeMinutes,
    required this.vocabularyRichness,
  });
}

/// Calculates text statistics.
class TextStatisticsCalculator {
  /// Average reading speed in words per minute.
  static const _readingWpm = 200;

  /// Average speaking speed in words per minute.
  static const _speakingWpm = 130;

  const TextStatisticsCalculator();

  /// Calculate text statistics.
  TextStats calculate(String text, SupportedLanguage language) {
    if (text.trim().isEmpty) {
      return const TextStats(
        wordCount: 0,
        characterCount: 0,
        characterCountNoSpaces: 0,
        sentenceCount: 0,
        paragraphCount: 0,
        avgWordsPerSentence: 0,
        avgWordLength: 0,
        readingTimeMinutes: 0,
        speakingTimeMinutes: 0,
        vocabularyRichness: 0,
      );
    }

    final words = _splitWords(text);
    final wordCount = words.length;
    final characterCount = text.length;
    final characterCountNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    final sentenceCount = _countSentences(text);
    final paragraphCount = _countParagraphs(text);

    final avgWordsPerSentence =
        sentenceCount > 0 ? wordCount / sentenceCount : wordCount.toDouble();

    final totalWordChars = words.fold(0, (sum, w) => sum + w.length);
    final avgWordLength = wordCount > 0 ? totalWordChars / wordCount : 0.0;

    final readingTimeMinutes = wordCount / _readingWpm;
    final speakingTimeMinutes = wordCount / _speakingWpm;

    final uniqueWords = words.map((w) => w.toLowerCase()).toSet();
    final vocabularyRichness =
        wordCount > 0 ? uniqueWords.length / wordCount : 0.0;

    return TextStats(
      wordCount: wordCount,
      characterCount: characterCount,
      characterCountNoSpaces: characterCountNoSpaces,
      sentenceCount: sentenceCount,
      paragraphCount: paragraphCount,
      avgWordsPerSentence: avgWordsPerSentence,
      avgWordLength: avgWordLength,
      readingTimeMinutes: readingTimeMinutes,
      speakingTimeMinutes: speakingTimeMinutes,
      vocabularyRichness: vocabularyRichness,
    );
  }

  List<String> _splitWords(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  int _countSentences(String text) {
    final sentenceEnders = RegExp('[.!?]+');
    return sentenceEnders.allMatches(text).length.clamp(1, text.length);
  }

  int _countParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty)
        .length
        .clamp(1, text.length);
  }
}
